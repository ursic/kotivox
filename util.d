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
import Clock = tango.time.Clock;
import tango.stdc.stringz;
import Unicode = tango.text.Unicode;
import tango.core.Array;
import tango.math.random.Kiss;

import dwt.widgets.DateTime;

extern (C) char* day_name(char* date, int year, int month, int day);


/*
  Return formatted date string
 */
char[] dayName(int year, int month, int day)
{
    char* date;
    return fromStringz(day_name(date, year, month, day));
}


char[] getTodayFileName()
{
  auto now = Clock.Clock().toDate;
  char[] fileName = dateToFileName(now.date.year,
				   now.date.month,
				   now.date.day);
  return fileName;
}


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
  Shift locations of strings by one to the left
  Return resulting array of strings
 */
char[][] shiftLeft(char[][] words)
{
    // shift locations by one
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
  Shift locations of strings by one to the right
  Return resulting array of strings
 */
char[][] shiftRight(char[][] words)
{
    // shift locations by one
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

    result = Unicode.toString32(string, result);
    foreach(dchar ch; result)
    {
	char[] dst;
	dst = Unicode.encode(dst, ch);
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