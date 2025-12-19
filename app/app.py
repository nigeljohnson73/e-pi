#!/usr/bin/env python

import threading
from urlextract import URLExtract
import re
import json
import jicson
import requests
import datetime
from dateutil.parser import parse

from inky.auto import auto
from PIL import Image, ImageDraw

import time
import gpiod
import gpiodevice
from gpiod.line import Bias, Direction, Value

c = threading.Condition()
all_done = False

img_file = "bg/vango.jpg"
ics_file = "basic.ics"
ics_url = "https://calendar.google.com/calendar/ical/millipods99%40gmail.com/public/basic.ics"
base64_authtoken = None
now = datetime.datetime.now(tz=datetime.timezone.utc)

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
    global all_done
    LED_PIN = 13
    chip = gpiodevice.find_chip_by_platform()
    led = chip.line_offset_from_id(LED_PIN)
    gpio = chip.request_lines(consumer="inky", config={led: gpiod.LineSettings(direction=Direction.OUTPUT, bias=Bias.DISABLED)})

    while True:
        gpio.set_value(led, Value.ACTIVE)
        time.sleep(0.5)
        gpio.set_value(led, Value.INACTIVE)
        c.acquire()
        if all_done:
            c.release()
            return

        c.release()
        time.sleep(0.5)


def loadEvents():
    global all_done
    # Get the data from the server
    if False:
        response = requests.get(ics_url)
        data = response.text
    
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

