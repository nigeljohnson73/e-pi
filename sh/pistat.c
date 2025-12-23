// cc pistat.c -lm -o pistat

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#define TMPFILE "/tmp/throt.tmp"

void getth(int i)
{
    if (i & 1 << 0)
        printf("           Under-voltage detected\n");
    if (i & 1 << 1)
        printf("           Arm frequency capped\n");
    if (i & 1 << 2)
        printf("           Currently throttled\n");
    if (i & 1 << 3)
        printf("           Soft temperature limit active\n");
    if (i & 1 << 16)
        printf("           Under-voltage has occurred\n");
    if (i & 1 << 17)
        printf("           Arm frequency capping has occurred\n");
    if (i & 1 << 18)
        printf("           Throttling has occurred\n");
    if (i & 1 << 19)
        printf("           Soft temperature limit has occurred\n");
}

int main(int argc, char **argv)
{
    double d;
    int r;
    int th;
    FILE *f;
    char buf[256];
    char str[256];

    sprintf(buf, "free -m -t | grep Total | awk '{print $2}' > %s", TMPFILE);
    r = system(buf);
    if ((f = fopen(TMPFILE, "r")) != NULL)
    {
        fscanf(f, "%lf", &d);
        // d = round(d / 1024.);
        d = d / 1024.;
        printf("RAM size : %0.3lf GB\n", d);
        fclose(f);
        remove(TMPFILE);
    }

    sprintf(buf, "vcgencmd measure_clock arm > %s", TMPFILE);
    r = system(buf);
    if ((f = fopen(TMPFILE, "r")) != NULL)
    {
        fscanf(f, "frequency(48)=%lf", &d);
        d = floor(d / 1000000.) / 1000;
        printf("CPU freq : %0.3lf GHz\n", d);
        fclose(f);
        remove(TMPFILE);
    }

    sprintf(buf, "vcgencmd measure_temp > %s", TMPFILE);
    r = system(buf);
    if ((f = fopen(TMPFILE, "r")) != NULL)
    {
        fscanf(f, "temp=%s", &str);
        printf("CPU temp : %s\n", &str);
        fclose(f);
        remove(TMPFILE);
    }

    sprintf(buf, "vcgencmd get_throttled > %s", TMPFILE);
    r = system(buf);
    if ((f = fopen(TMPFILE, "r")) != NULL)
    {
        fscanf(f, "throttled=%x", &th);
        printf("Throttle : 0x%x\n", th);
        getth(th);
        fclose(f);
        remove(TMPFILE);
    }
}
