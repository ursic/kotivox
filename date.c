/*****************************************************************************
 *
 *   Kotivox
 * 
 *   Copyright 2009 Mitja Ursic
 *   mitja_ursic@yahoo.com
 * 
 *   Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *   You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *   See the License for the specific language governing permissions and
 *   limitations under the License.
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
