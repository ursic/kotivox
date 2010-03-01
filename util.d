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

module util;

import Integer = tango.text.convert.Integer;
import Txt = tango.text.Util;
import tango.stdc.stringz;
import tango.stdc.time;
import Utf = tango.text.convert.Utf;
import tango.core.Array;
import tango.math.random.Kiss;
import tango.io.digest.Sha512;

import dwt.widgets.DateTime;


private struct Date
{
    int day = -1;
    int month;
    int year;
}
private const static Date date;


/*
  Return formatted date string.
 */
char[] dateFormat(char[] formatStr = "%A, %e. %B, %Y", Date date = date)
{
    if(-1 == date.day) date = today;

    char[36] dayStr;
    char* daybuf = toStringz(dayStr);
    char* format = toStringz(formatStr);
    static tm time_str;

    time_str.tm_year = date.year - 1900;
    time_str.tm_mon = date.month - 1;
    time_str.tm_mday = date.day;
    time_str.tm_isdst = -1;
    if(-1 != mktime(&time_str))
      strftime(daybuf, 36, format, &time_str);

    return fromStringz(daybuf);
}


/*
  Return day names.
 */
char[][] dayNames()
{
    char[11] dayStr;
    char* dayBuf = toStringz(dayStr);
    char* format = toStringz("%A");
    char[][] names;
    static tm time_str;

    for(int i = 0; i < 7; i++)
    {
	time_str.tm_wday = i;
	strftime(dayBuf,
		 dayStr.length,
		 format,
		 &time_str);
	names ~= fromStringz(dayBuf);
	dayBuf = toStringz(dayStr);
    }
    return names;
}


/*
  Return time stamp.
 */
char[] timestamp()
{
    char[6] timeStr;
    char* timestamp = toStringz(timeStr);
    char* format = "%H:%M";
    static time_t rawtime;
    static tm* timeinfo;
    time(&rawtime);
    timeinfo = localtime(&rawtime);
    strftime(timestamp,
	     timeStr.length,
	     format,
	     timeinfo);

    return fromStringz(timestamp);
}


/*
  Return string formatted for file name containing
  today's date.
 */
char[] getTodayFileName()
{
  char[] fileName = dateToFileName(today.year,
				   today.month,
				   today.day);
  return fileName;
}


/*
  Convert date to string and return it.
*/
char[] dateToFileName(int _year, int _month, int _day)
{
    char[] year = Integer.toString(_year);
    char[] month;
    char[] day;

    if(_month < 10)
	month = "0" ~ Integer.toString(_month);
    else
	month = Integer.toString(_month);

    if(_day < 10)
	day = "0" ~ Integer.toString(_day);
    else
	day = Integer.toString(_day);
	
    return year ~ month ~ day;
}


/*
  Convert DateTime to string and return it.
  Return today's string if no date provided.
 */
char[] dateStr(DateTime date = null)
{
    if(date is null) return getTodayFileName;
    
    return dateToFileName(date.getYear,
			  date.getMonth + 1,
			  date.getDay);
}


/*
  Convert Date to string and return it.
  Return today's string if no date provided.
 */
char[] dateStr(Date date = date)
{
    if(-1 == date.day) return getTodayFileName;
    
    return dateToFileName(date.year,
			  date.month,
			  date.day);
}


/*
  Parse lines in str into associative array
  First value in line separated from the rest
  of the line by space is key in array
 */
char[][char[]] parseLines(in char[] str)
{
    char[][char[]] result;

    foreach(line; Txt.splitLines(str))
    {
	auto setting = Txt.split(line, " ");

	// join space-separated values into one
	char[] value;
	for(int i = 1; i < setting.length; i++)
	    value ~= " " ~ setting[i];

	if(0 < setting[0].length)
	    result[setting[0]] = Txt.trim(value);
    }

    return result;
}


/*
  Rotate locations of strings by one to the left.
  Return resulting array of strings.
 */
char[][] rotateLeft(char[][] words)
{
    char[][] newWords;
    for(int i = 0; i < words.length; i++)
    {
	if((words.length - 1) < (i + 1))
	    newWords ~= words[0];
	else
	    newWords ~= words[i + 1];
    }
    return newWords;
}


/*
  Rotate locations of strings by one to the right.
  Return resulting array of strings.
 */
char[][] rotateRight(char[][] words)
{
    // Rotate locations by one.
    char[][] newWords;
    for(int i = 0; i < words.length; i++)
    {
	if((i - 1) < 0)
	    newWords ~= words[words.length - 1];
	else
	    newWords ~= words[i - 1];
    }
    return newWords;
}


/*
  Encode UTF-32 characters to UTF-8
 */
char[] toUtf8(char[] string)
{
    dchar[] result;
    char[] str;

    result = Utf.toString32(string, result);
    foreach(dchar ch; result)
    {
	char[] dst;
	dst = Utf.encode(dst, ch);
	str ~= dst;
    }
    return str;
}


/*
  Returns first free index in given array.
*/
int getFreeSlot(int[] indices)
{
    int i = 0;
    for(i = 0; i < indices.length + 1; i++)
	if(!contains(indices, i)) return i;

    return i;
}


/*
  Returns string composed of pseudo-random alphanumeric characters
  of requested length.
 */
char[] randStr(int strLen = 8)
{
    char[] numbers;
    char[] lcase;
    char[] ucase;

    char[][] alphabet;
    Kiss kiss;
    char[] randStr;

    for(int i = cast(int)'0'; i <= cast(int)'9'; i++)
	    numbers ~= cast(char)i;
    for(int i = cast(int)'a'; i <= cast(int)'z'; i++)
	    lcase ~= cast(char)i;
    for(int i = cast(int)'A'; i <= cast(int)'Z'; i++)
	    ucase ~= cast(char)i;

    alphabet = [numbers, lcase, ucase];

    // Get random alphanumeric character for each position.
    for(int i = 0; i < strLen; i++)
    {
	// Choose either from numbers, lower-case letters or
	// upper-case letters.
	kiss.seed;
	int from = kiss.toInt(0, 3);
	kiss.seed;
	int pos = kiss.toInt(0, alphabet[from].length);
	
	randStr ~= cast(char)alphabet[from][pos];
    }

    return randStr;
}


/*
  Returns digest of str.
 */
char[] digest(char[] str)
{
    Sha512 digest = new Sha512;
    digest.update(cast(ubyte[])str);
    return digest.hexDigest();
}


/*
  Shorten and trim given string.
*/
char[] sanitizeStr(char[] instr, int strlen = 30, bool singleLine = true)
{
    char[] str = instr;
    if(strlen < instr.length) str = Txt.trim(instr[0..strlen]);
    if(singleLine) str = Txt.substitute(str, "\n", "");
    return str;
}


/*
  Remove all matching integers from given array.
*/
void removeInts(ref int[] array, int element)
{
    int[] elements;
    foreach(el; array)
    {
	if(el == element) continue;
	elements ~= el;
    }
    array = elements;
}


/*
  Concatenate array of integers and return resulting string.
*/
char[] serialize(int[] array)
{
    char[] str;
    foreach(el; array) str ~= Integer.toString(el);
    return str;
}


/*
  Return today's date structure.
 */
Date today()
{
    if(-1 != date.day) return date;

    static time_t rawtime;
    static tm* timeinfo;

    char[11] dateBuff;

    char* dateStrp = toStringz(dateBuff);
    char* format = "%d.%m.%Y";
    time(&rawtime);
    timeinfo = localtime(&rawtime);
    if(-1 != mktime(timeinfo))
      strftime(dateStrp, 11, format, timeinfo);

    char[][] nums = Txt.split(fromStringz(dateStrp), ".");

    date.day = Integer.toInt(nums[0]);
    date.month = Integer.toInt(nums[1]);
    date.year = Integer.toInt(nums[2]);

    return date;
}


/*
  Convert date integer to Date structure and return it.
 */
Date dateStrToDate(int dateInt)
{
    char[] dateStr = Integer.toString(dateInt);
    static Date date;
    date.year = Integer.toInt(dateStr[0..4]);
    date.month = Integer.toInt(dateStr[4..6]);
    date.day = Integer.toInt(dateStr[6..$]);
    return date;
}


/*
  Convert date string to Date structure and return it.
 */
Date dateStrToDate(char[] dateStr)
{
    static Date date;
    date.year = Integer.toInt(dateStr[0..4]);
    date.month = Integer.toInt(dateStr[4..6]);
    date.day = Integer.toInt(dateStr[6..$]);
    return date;
}
