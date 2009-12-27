/*****************************************************************************
 *
 *   Adapted for Kotivox
 * 
 *   Copyright 2009 R Samuel Klatchko
 *   
 *   On Stack Overflow:
 *   http://stackoverflow.com/users/29809/r-samuel-klatchko
 *   http://stackoverflow.com/questions/1727549/linux-datetime-locale-library-in-c
 *   
 *   Licensed under Attribution-Share Alike 3.0 Unported
 *   http://creativecommons.org/licenses/by-sa/3.0/
 *
 *****************************************************************************/

#include <time.h>
#include <string.h>

char* day_name(char* date, int year, int month, int day)
{
    char daybuf[36];
    struct tm time_str;

    time_str.tm_year = year - 1900;
    time_str.tm_mon = month - 1;
    time_str.tm_mday = day;
    time_str.tm_hour = 0;
    time_str.tm_min = 0;
    time_str.tm_sec = 1;
    time_str.tm_isdst = -1;
    if (mktime(&time_str) != -1)
	strftime(daybuf, sizeof(daybuf), "%A, %e. %B, %Y", &time_str);

    date = strdup(daybuf);
    return date;
}
