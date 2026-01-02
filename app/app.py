#!/usr/bin/env python

import threading
from urlextract import URLExtract
import os
import re
import json
import jicson
import requests
from dateutil.parser import parse
from datetime import datetime, timezone

from inky.auto import auto
from PIL import Image, ImageDraw, ImageFont

import time
import gpiod
import gpiodevice
from gpiod.line import Bias, Direction, Value

c = threading.Condition()
all_done = False

connect_timeout = 30
img_file = "bg/vango.jpg"
ics_file = "basic.ics"
ics_url = "https://calendar.google.com/calendar/ical/millipods99%40gmail.com/public/basic.ics"
base64_authtoken = None
now = datetime.now(tz=timezone.utc)

os.chdir(os.path.dirname(__file__))
print(f"working directory: {os.path.dirname(__file__)}")

def draw_textr(image, angle, xy, text, fill, *args, **kwargs):
    """ Draw text at an angle into an image, takes the same arguments
        as Image.text() except for:

    :param image: Image to write text into
    :param angle: Angle to write text at
    """
    # get the size of our image
    width, height = image.size
    max_dim = max(width, height)

    # build a transparency mask large enough to hold the text
    mask_size = (max_dim * 2, max_dim * 2)
    mask = Image.new('L', mask_size, 0)

    # add text to mask
    draw = ImageDraw.Draw(mask)
    draw.text((max_dim, max_dim), text, 255, *args, **kwargs)

    if angle % 90 == 0:
        # rotate by multiple of 90 deg is easier
        rotated_mask = mask.rotate(angle)
    else:
        # rotate an an enlarged mask to minimize jaggies
        bigger_mask = mask.resize((max_dim*8, max_dim*8),
                                  resample=Image.BICUBIC)
        rotated_mask = bigger_mask.rotate(angle).resize(
            mask_size, resample=Image.LANCZOS)

    # crop the mask to match image
    mask_xy = (max_dim - xy[0], max_dim - xy[1])
    b_box = mask_xy + (mask_xy[0] + width, mask_xy[1] + height)
    mask = rotated_mask.crop(b_box)

    # paste the appropriate color, with the text transparency mask
    color_image = Image.new('RGBA', image.size, fill)
    image.paste(color_image, mask)

def extractTokenText(key, s, dt=None):
    ret = dt

    try:
        key = f'{key.lower()}:(.*?)\n'
        s = s.lower().rstrip('\n')+'\n'
        ret = re.search(key, s).group(1)
    except:
        pass

    return ret

def extractUrlDetails(key, s, dt=None):
    url=dt
    try:
        s = extractTokenText(key, s)
        extractor = URLExtract()
        urls = extractor.find_urls(s)
        url = urls[0]
    except:
        pass

    return url

def flashLights():
    flash_duration = 0.25
    global all_done
    LED_PIN = 13
    chip = gpiodevice.find_chip_by_platform()
    led = chip.line_offset_from_id(LED_PIN)
    gpio = chip.request_lines(consumer="inky", config={led: gpiod.LineSettings(direction=Direction.OUTPUT, bias=Bias.DISABLED)})

    while True:
        gpio.set_value(led, Value.ACTIVE)
        time.sleep(flash_duration)
        gpio.set_value(led, Value.INACTIVE)
        c.acquire()
        if all_done:
            c.release()
            return

        c.release()
        time.sleep(flash_duration)


def loadEvents():
    global all_done, now
    max_screen_events = 10
    # Get the data from the server
    if True:
        retry = True
        started = datetime.now(timezone.utc)
        print (f"starting event list gathering")
        while retry:
            try:
                response = requests.get(ics_url)
                data = response.text
                retry = False
                print (f"Updating remote event list")
            except:
                now = datetime.now(timezone.utc)
                duration = now - started
                if duration.total_seconds() > connect_timeout:
                    printf("Connection timeout for event list")
                    return
    
        with open(ics_file, "w") as f:
            f.write(data)
    
    result = jicson.fromFile(ics_file)
    #print(json.dumps(result, indent=4))
    #print(result)
    
    events=result['VCALENDAR'][0]['VEVENT']
    print (f"Number of events: {len(events)}")
    events.sort(key=lambda x: x['DTSTART'], reverse=False)
    
    inky = auto(ask_user=False, verbose=True)
    im = Image.open(img_file)
    width, height = im.size
    if width < height:
        print(f"Imaging being rotated")
        im=im.rotate(90)
        width, height = im.size
    
    im = im.convert("RGBA")
    
    print(f"Imaging size [{width}, {height}]")
    
    TINT_COLOR = (0xff, 0xff, 0xff)
    TRANSPARENCY = .5 # of the new panel
    BORDER = 100
    OPACITY = int(255 * TRANSPARENCY)
    
    overlay = Image.new('RGBA', im.size, TINT_COLOR+(0,))
    draw = ImageDraw.Draw(overlay)
    draw.rectangle(((BORDER, BORDER), (width-BORDER, height-BORDER)), fill=TINT_COLOR+(OPACITY,))
    
    im = Image.alpha_composite(im, overlay)
    im = im.convert("RGB")
    draw = ImageDraw.Draw(im)
    dfont_size = 40
    tfont_size = 40
    lfont_size = 32

    tfont = ImageFont.truetype('fonts/title.ttf', tfont_size)
    dfont = ImageFont.truetype('fonts/date.ttf', dfont_size)
    lfont = ImageFont.truetype('fonts/location.ttf', lfont_size)

    dfont_colour = (0xff, 0x00, 0x00)
    tfont_colour = (0x00, 0x00, 0x00)
    lfont_colour = (0x00, 0xcc, 0x00)
    
    yy=BORDER
    screen_events = 0
    for e in events:
        start = parse(e.get('DTSTART'))
        if start > now:
            when = start.strftime('%A, %d %B %Y')
            what = e.get('SUMMARY')
            where = e.get('LOCATION', "Location TBD").replace("\\","")
            desc = e.get('DESCRIPTION', "")
            print(f"{when}: {what}")
            #print(f"    {what}")
            print(f"    Location: {where}")
            #print(f"    {desc}")
            info = extractTokenText("Info", desc)
            if info:
                print(f"    Info: {info}")
            url = extractUrlDetails("Tickets", desc)
            if url:
                print(f"    Tickets: {url}")
            url = extractUrlDetails("Facebook", desc)
            if url:
                print(f"    Facebook: {url}")
            url = extractUrlDetails("Instagram", desc)
            if url:
                print(f"    Instagram: {url}")
            url = extractUrlDetails("Website", desc)
            if url:
                print(f"    Website: {url}")

            if screen_events < max_screen_events:
                screen_events += 1
                print(f"    Display: yes")
                #draw.text((BORDER+5, yy), f"{when}: {what}", font=titleFont, fill =(255, 0, 0))
                draw_textr(im, 90, (yy, height-(BORDER+5)), f"{when}", font=dfont, fill =dfont_colour)
                yy += dfont_size+5;
                draw_textr(im, 90, (yy, height-(BORDER+5)), f"{what}", font=tfont, fill =tfont_colour)
                yy += tfont_size+5;
                draw_textr(im, 90, (yy, height-(BORDER+5)), f"{where}", font=lfont, fill =lfont_colour)
                yy += lfont_size+5;

                yy += 10
            else:
                print(f"    Display: no");

            print("")
    
    try:
        print(f"Loading image to display")
        inky.set_image(im, saturation=1.0)
    except TypeError:
        print(f"Loading failed, loading resize image to display")
        resizedimage = im.resize(inky.resolution)
        inky.set_image(resizedimage)
    
    print(f"Rendering display")
    inky.show()
    print(f"Process complete")

    # Signal we are all done
    c.acquire()
    all_done = True
    c.notify_all()
    c.release()
    print(f"Thread done")


t1 = threading.Thread(target=loadEvents, args=())
t2 = threading.Thread(target=flashLights, args=())
#t1 = threading.Thread(target=flashLights, args=())

t1.start()
t2.start()


t1.join()
t2.join()

print("Good night cruel world!")

