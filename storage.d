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

module storage;

import tango.io.FileScan;
import tango.core.Array;
import Txt = tango.text.Util;
import Integer = tango.text.convert.Integer;

import dwt.DWT;
import dwt.widgets.DateTime;

import config;
import util;
import auth;
import crypt;

import tango.io.Stdout;

private class Day
{
    private char[] name;
    private char[] text;

    // [0] - start of category
    // [1] - length of category
    // [2] - 0 for normal text, 1 for bold - indicating category title
    private int[][] categoryRanges;

    static private Day[] days;

    this(char[] name, char[] text)
    {
	this.name = name;
	this.text = text;
    }

    /*
      Decrypt user days.
     */
    static private void loadDays()
    {
	// gather all day files for this user
	foreach(file; (new FileScan)(Auth.userDirPath, USER_DAY_FILE_EXTENSION).files)
	{
	    // decrypt text and store it
	    char *textp;
	    char[] textOut;
	    char[] text = k_decrypt_to_string(file.path ~ file.file, textp, Auth.cipherKey);
	    foreach(char c; text) textOut ~= c;

	    days ~= new Day(file.name, textOut);
	}
    }

    static private bool dayExists(char[] dayName)
    {
	foreach(Day d; days)
	    if(d.name == dayName) return true;

	return false;
    }

    static private void daySetText(char[] dayName, char[] text)
    {
	if(dayExists(dayName))
	{
	    foreach(Day d; days)
		if(d.name == dayName)
		{
		    d.text = text;
		    break;
		}
	}
	else
	    days ~= new Day(dayName, text);
    }

    static private char[] dayGetText(char[] dayName)
    {
	foreach(Day d; days)
	    if(d.name == dayName) return d.text;

	return "";
    }

    static private void setCategoryRanges(char[] dayName, int[][] ranges)
    {
	foreach(day; days)
	    if(dayName == day.name)
	    {
		day.categoryRanges = ranges;
		break;
	    }
    }

    static private int[][] getCategoryRanges(char[] dayName)
    {
	foreach(day; days)
	    if(dayName == day.name) return day.categoryRanges;

	return null;
    }
}


private class Category
{
    private int id;
    private char[] name;
    private static Category[] categories;
    // category retrieval counter
    private static int catRetrCount = 0;

    this(int id, char[] name)
    {
	this.id = id;
	this.name = name;
    }

    /*
      Shorten and trim category name to first 20 characters.
    */
    static private char[] sanitizeCategoryName(char[] name)
    {
	char[] catName = name;
	if(MAX_CATEGORY_NAME_LENGTH < name.length)
	    catName = name[0..MAX_CATEGORY_NAME_LENGTH];
	catName = Txt.trim(catName);
	return catName;
    }

    static private int[] getIds()
    {
	int[] ids;
	foreach(c; categories) ids ~= c.id;
	return ids;
    }

    /*
      Add new category with name to categories array.
      Return id of added category.
    */
    static private int addCategory(char[] name)
    {
	int id = getFreeSlot(getIds);
	categories ~= new Category(id, sanitizeCategoryName(name));
	return id;
    }

    /*
      Removes category of given id from categories array.
    */
    static private void removeCategory(int id)
    {
	Category new_categories[];
	foreach(Category category; categories)
	{
	    if(category.id == id) continue;

	    new_categories ~= category;
	}
	categories = new_categories;
    }

    static private void renameCategory(int id, char[] name)
    {
	foreach(Category c; categories)
	{
	    if(c.id == id)
	    {
		c.name = sanitizeCategoryName(name);
		break;
	    }
	}
    }

    /*
      Encrypt categories into file.
     */
    static private void saveCategories()
    {
	char[] content;
	foreach(Category c; categories)
	{
	    // skip categories with empty names
	    if(Txt.trim(c.name).length <= 0) continue;

	    content ~= Integer.toString(c.id) ~ " " ~ c.name ~ "\n";
	}

	char[] catFileName = Auth.userDirPath ~ USER_CATEGORIES_FILE;

	// no categories, remove file if exists
	if(content.length <= 0)
	{
	    FilePath catFile = new FilePath(catFileName);
	    if(catFile.exists) catFile.remove;

	    return;
	}

	// encrypt categories into file
	k_encrypt_from_string(content,
			      catFileName,
			      Auth.cipherKey);
    }

    /*
      Decrypt user categories.
     */
    static private void loadCategories()
    {
	// Does categories file exist?
	char[] filename = Auth.userDirPath ~ USER_CATEGORIES_FILE;
	if(!(new FilePath(filename)).exists) return;
	
	// Decrypt categories file and store categories.
	char *textp;
	char[] content;
	char[] text = k_decrypt_to_string(filename, textp, Auth.cipherKey);
	foreach(char c; text) content ~= c;

	foreach(char[] id, char[] name; parseLines(content))
	    categories ~= new Category(Integer.toInt(id), name);

	catRetrCount = categories.length;
    }

    /*
      Return name of category with id.
     */
    static private char[] getCategoryName(int id)
    {
	foreach(Category c; categories)
	    if(c.id == id) return c.name;

	return "";
    }

    /*
      Return ID of category with name.
     */
    static private int getCategoryID(char[] name)
    {
	foreach(Category c; categories)
	    if(Unicode.toLower(c.name) == Unicode.toLower(Txt.trim(name))) return c.id;

	return -1;
    }

    /*
      Return associative array with category id as key
      and category name as value.
     */
    static private char[][] getCategory()
    {
	if(0 == catRetrCount)
	{
	    // reset category count
	    catRetrCount = categories.length;
	    return null;
	}

	char[][] cat;
	cat = new char[][2];

	int idx = categories.length - catRetrCount;
	cat[0] = Integer.toString(categories[idx].id);
	cat[1] = categories[idx].name;

	catRetrCount--;
	return cat;
    }

    /*
      Return complement category IDs.
     */
    static private int[] invCategoryIDs(int[] selCategories)
    {
	int[] invCategories;
	foreach(c; categories)
	{
	    if(!contains(selCategories, c.id))
		invCategories ~= c.id;
	}
	return invCategories;
    }
}


private class SearchResultPage
{
    private int index;
    private char[] content;

    static char[] txtKeywords;
    static SearchResultPage[] resultPages;

    this(int index, char[] content)
    {
	this.index = index;
	this.content = Txt.substitute(content, "&", "&&");
    }

    // save keywords for display later, replace & with &&
    static void keywords(char[] keywords)
    {
	this.txtKeywords = Txt.substitute(keywords, "&", "&&");
    }

    static char[] keywords()
    {
	return this.txtKeywords;
    }

    static int getNextIndex()
    {
	if(0 == resultPages.length)
	    return 0;

	return resultPages[resultPages.length - 1].index + 1;
    }

    /*
      Return true when location is inside category of given id
    */
    static bool isInCategory(int location, int id, Day day)
    {
	char[][int] catNames;
	foreach(c; Category.categories)
	    catNames[c.id] ~= c.name;

	struct Category
	{
	    int id;
	    int start;
	    int end;
	}

	Category[] dayCategories;

	// for each day, get location at each category
	// start at title and end at the end of the body
	// also get id of each category
	// save id, start and end in Category struct array
	// if the same paragraph is categorized by two or
	// more categories, store same category boundaries for each id
	int start = -1;
	int end = -1;
	char[] title;
	foreach(range; Day.getCategoryRanges(day.name))
	{
	    int bold = range[2];
	    // at category title
	    if(1 == bold)
	    {
		title = day.text[range[0]..range[0] + range[1]];

		int begin = 0;
		foreach(id, name; catNames)
		{
		    int location;
		    begin = location;
		    if(Txt.locatePattern(Unicode.toLower(title),
					 Unicode.toLower(name),
					 begin) < title.length)
			  start = range[0];
		}
	    }
	    // at category body
	    // and end only if start is valid
	    else if((0 == bold) && (-1 < start))
	    {
		int tempEnd = start + title.length + range[1];
		if(start < tempEnd) end = tempEnd;
	    }

	    if((-1 < start) && (0 < end))
	    {
		// split category names and add them among
		// day categories
		foreach(name; Txt.split(title, ","))
		{
		    int catID = Storage.getCategoryID(name);
		    Category c = {catID, start, end};
		    dayCategories ~= c;
		}
		start = -1;
		end = -1;
	    }
	}

	foreach(dc; dayCategories)
	{
	    if((dc.id == id) && (dc.start <= location) && (location <= dc.end))
		return true;
	}
	
	return false;
    }

    /*
      Match texts of all days against keywords.
      Exclude categorized texts by default.
      Match against categorized text whose categories are provided in categories array.
      Store search results in array, each element representing one result page.
      Return true if any results found, false otherwise.

      Always return matches inside non-categorized text.
     */
    static private bool compileSearchResults(char[] keywordStr, int[] categories)
    {
	// clear previous search
	resultPages = null;

	char[] content;
	int appendLength = SEARCH_RESULT_LENGTH / 2;
	uint numResults;
	foreach(day; Day.days.dup.reverse)
	{
	    int end = day.text.length;
	    int location = 0;
	    char[] result;
	    entry: do
	    {
		location = Txt.locatePattern(Unicode.toLower(day.text),
					     Unicode.toLower(keywordStr),
					     location);
		// match found
		// prepend and append some text around keywordStr
		// prepend link above the result
		if((0 == location) || (location < end))
		{
		    // is the start of found match inside given categories?
		    int[] invCategories = Category.invCategoryIDs(categories);
		    foreach(id; invCategories)
		    {
			if(isInCategory(location, id, day))
			{
			    location += keywordStr.length;
			    continue entry;
			}
		    }

		    char[] head;
		    char[] core;
		    char[] tail;
		    if(0 <= (location - appendLength))
			head = day.text[location - appendLength..location];

		    core = day.text[location..location + keywordStr.length];

		    if((location + keywordStr.length + appendLength) <= day.text.length)
			tail = day.text[location + keywordStr.length..location + keywordStr.length + appendLength];

		    int year = Integer.toInt(day.name[0..4]);
		    int month = Integer.toInt(day.name[4..6]);
		    int mday = Integer.toInt(day.name[6..8]);

		    char[] date = dayName(year, month, mday);
		    result ~= "<a href=\"JUMP" ~ day.name ~ Integer.toString(location) ~ "-" ~ this.keywords  ~ "\">" ~ date ~ "</a>\n";
		    result ~= head ~ Unicode.toUpper(core) ~ tail;
		    result ~= "\n\n";
		    numResults++;

		    if(SEARCH_RESULT_PAGE_LENGTH < (content.length + result.length))
		    {
			char[] matches = 0 < content.length ? content : result;
			resultPages ~= new SearchResultPage(getNextIndex, matches);
			content = result;
		    }
		    else
			content ~= result;

		    result = "";
		}
		location += keywordStr.length;
	    }while(location < end);
	}

	// save what's left of search results
	if(0 < content.length)
	    resultPages ~= new SearchResultPage(getNextIndex, content);

 	if(!numResults) return false;

	return true;
    }

    static private char[] getPager(int currentPage)
    {
	if(resultPages.length < 2) return "";

	char[] pageLinks;
	foreach(page; resultPages)
	{
	    if(page.index == currentPage)
		pageLinks ~= "   " ~ Integer.toString(page.index + 1);
	    else
	    {
		pageLinks ~= "   <a href=\"PAGE" ~ Integer.toString(page.index) ~ "\">";
		pageLinks ~= Integer.toString(page.index + 1) ~ "</a>";
	    }
	}
	return Txt.trim(pageLinks);
    }
}


private class Note
{
    private int id;
    private char[] name;
    private char[] filename;
    private char[] content;

    static private Note[] notes;

    this(int id, char[] name, char[] content = "")
    {
	this.id = id;
	this.name = sanitizeNoteName(name);
	this.filename = randStr ~ NOTE_FILE_EXTENSION;
	this.content = content;
    }

    static private int addNote(char[] name = "")
    {
	int id = getFreeSlot(getIds);
	if(name.length <= 0) name = NOTES_TEXT ~ " " ~ Integer.toString(id);
	notes ~= new Note(id, name);
	return id;
    }

    /*
      Removes note of given id from notes array.
    */
    static private void removeNote(int id)
    {
	Note new_notes[];
	foreach(note; notes)
	{
	    if(note.id == id) continue;

	    new_notes ~= note;
	}
	notes = new_notes;
    }

    // Return note name.
    static private char[] noteName(int id)
    {
	foreach(note; notes)
	    if(note.id == id) return note.name;

	return "CANNOT FIND NOTE " ~ Integer.toString(id);
    }

    // Set note name.
    static private void noteName(int id, char[] name)
    {
	foreach(note; notes)
	{
	    if(note.id == id)
	    {
		note.name = sanitizeNoteName(name);
		break;
	    }

	}
    }

    static private void noteContent(int id, char[] content)
    {
	foreach(n; notes)
	{
	    if(n.id == id)
	    {
		n.content = content;
		break;
	    }
	}
// 	foreach(note; notes)
// 	  Stdout(note.content).newline;
    }

    static private char[] noteContent(int id)
    {
	foreach(n; notes)
	    if(n.id == id) return n.content;
	return "";
    }

    static private int[] getIds()
    {
	int[] ids;
	foreach(n; notes) ids ~= n.id;
	return ids;
    }

    /*
      Shorten and trim note title to first 20 characters.
    */
    static private char[] sanitizeNoteName(char[] name)
    {
	char[] noteName = name;
	if(MAX_CATEGORY_NAME_LENGTH < name.length)
	    noteName = name[0..MAX_CATEGORY_NAME_LENGTH];
	noteName = Txt.trim(noteName);
	return noteName;
    }

    /*
      Encrypt notes into files.
     */
    static private void saveNotes()
    {
	char[] noteFiles;
	foreach(note; notes)
	{
	    char[] noteFilePath = Auth.userDirPath ~ note.filename;
	    char[] name = Txt.trim(note.name);
	    
	    // skip note with empty name
	    if(name.length <= 0)
	    {
		// delete note file if exists
		FilePath noteFile = new FilePath(noteFilePath);
		if(noteFile.exists) noteFile.remove;		

		continue;
	    }

	    // Write name of the note and its index
	    // number on the top line of its content. -- a very primitive header
	    char[] content = note.name ~ " " ~ Integer.toString(note.id) ~ "\n" ~ note.content;
	    k_encrypt_from_string(content,
				  noteFilePath,
				  Auth.cipherKey);
	    noteFiles ~= noteFilePath;
	}

	// Remove obsolete note files.
	foreach(file; (new FileScan)(Auth.userDirPath, NOTE_FILE_EXTENSION).files)
	    if(!contains(noteFiles, file.path ~ file.file))
		file.remove;
    }

    /*
      Decrypt notes from files.
     */
    static private void loadNotes()
    {
	foreach(file; (new FileScan)(Auth.userDirPath, NOTE_FILE_EXTENSION).files)
	{
	    // decrypt text and store it
	    char *textp;
	    char[] textOut;
	    char[] text = k_decrypt_to_string(file.path ~ file.file, textp, Auth.cipherKey);
	    foreach(char c; text) textOut ~= c;

	    char[][] lines = Txt.splitLines(textOut);

	    // First line is primitive header containing note's name and index.
	    auto settings = Txt.split(lines[0], " ");

	    // in case name contains spaces
	    char[] name;
	    for(int i = 0; i < settings.length - 1; i++) name ~= " " ~ settings[i];

	    // The rest of the lines is content.
	    char[] content = "";
	    for(int i = 1; i < lines.length; i++)
		content ~= lines[i] ~ "\n";

	    notes ~= new Note(Integer.toInt(settings[settings.length - 1]),
			      name,
			      content);
	}
    }
    
    static private char[][int] getNotes()
    {
	char[][int] noteList;
	foreach(note; notes) noteList[note.id] = note.name;
	return noteList;
    }
}


public class Storage
{
    /*
      Save today's plaintext.
     */
    static public void saveText(in char[] text)
    {
	Day.daySetText(getTodayFileName, text);
    }

    /*
      Encrypt today's text to file.
     */
    static public void saveFinal()
    {
	Category.saveCategories;
	saveCategoryRanges;
	Note.saveNotes;

	char[] textFilePath = Auth.userDirPath ~ getTodayFileName ~ USER_DAY_FILE_EXTENSION;

	// Remove existing text file if no more new text.
	char[] text = Day.dayGetText(getTodayFileName);
	if(0 == text.length)
	{
	    FilePath textFile = new FilePath(textFilePath);
	    if(textFile.exists)	textFile.remove;

	    return;
	}

	saveText(text);

	// Store encrypted text in file.
	k_encrypt_from_string(Day.dayGetText(getTodayFileName),
			      textFilePath,
			      Auth.cipherKey);
    }

    /*
      Get decrypted text for date.
      Return today's text if date is null.
    */
    static public char[] getText(DateTime date = null)
    {
	char[] text = "";

	char[] dayName;
	if(date is null)
	    dayName = getTodayFileName;
	else
	    dayName = dateToFileName(date.getYear,
				     date.getMonth + 1,
				     date.getDay);

	if(0 < Day.dayGetText(dayName).length)
	    text = Day.dayGetText(dayName);

	return text;
    }

    /*
      Encrypt category ranges into file.
     */
    static private void saveCategoryRanges()
    {
	int[][] catRanges = Day.getCategoryRanges(getTodayFileName);
	char[] catRangesFileName = Auth.userDirPath ~ getTodayFileName ~ USER_CATEGORY_RANGES_FILE_EXTENSION;

	// No category ranges for today, remove file.
	if(catRanges.length <= 0)
	{
	    FilePath catRangesFile = new FilePath(catRangesFileName);
	    if(catRangesFile.exists) catRangesFile.remove;

	    return;
	}

	char[] rangesTxt;
	int i = 0;
	foreach(c; catRanges)
	{
	    rangesTxt ~= Integer.toString(i++) ~ " ";
	    rangesTxt ~= Integer.toString(c[0]) ~ " ";
	    rangesTxt ~= Integer.toString(c[1]) ~ " ";
	    rangesTxt ~= Integer.toString(c[2]) ~ "\n";
	}

	// encrypt category ranges into file
	k_encrypt_from_string(rangesTxt,
			      catRangesFileName,
			      Auth.cipherKey);
    }

    /*
      Decrypt user category ranges.
     */
    static private void loadCategoryRanges()
    {
	// gather all available category ranges
	foreach(file; (new FileScan)(Auth.userDirPath, USER_CATEGORY_RANGES_FILE_EXTENSION).files)
	{
	    // decrypt category ranges into array
	    char *textp;
	    char[] ranges;
	    char[] text = k_decrypt_to_string(file.path ~ file.file, textp, Auth.cipherKey);
	    foreach(char c; text)
		ranges ~= c;

	    int[][] catRanges;
	    foreach(char[] range; parseLines(ranges))
	    {
		char[][] rangeVals = Txt.split(range, " ");
		
		int start = Integer.toInt(rangeVals[0]);
		int length = Integer.toInt(rangeVals[1]);
		int fontStyle = Integer.toInt(rangeVals[2]);

		catRanges ~= [start, length, fontStyle];
	    }
	    Day.setCategoryRanges(file.name, catRanges);
	}
    }

    static public char[][] getCategory()
    {
	return Category.getCategory;
    }

    static public int addCategory(char[] name)
    {
	return Category.addCategory(name);
    }

    static public void renameCategory(int id, char[] name)
    {
	Category.renameCategory(id, name);
    }

    static public void removeCategory(int id)
    {
	Category.removeCategory(id);
    }

    static public char[] getCategoryName(int id)
    {
	return Category.getCategoryName(id);
    }

    static public int getCategoryID(char[] name)
    {
	return Category.getCategoryID(name);
    }

    /*
      Set category ranges for date.
     */
    static public void setCategoryRanges(DateTime date, int[][] ranges)
    {
	char[] dayName;
	if(date is null)
	    dayName = getTodayFileName;
	else
	    dayName = dateToFileName(date.getYear,
				     date.getMonth + 1,
				     date.getDay);

	Day.setCategoryRanges(dayName, ranges);
    }

    /*
      Return array of category ranges for given date.
     */
    static public int[][] getCategoryRanges(DateTime date = null)
    {
	char[] dayName;
	if(date is null)
	    dayName = getTodayFileName;
	else
	    dayName = dateToFileName(date.getYear,
				     date.getMonth + 1,
				     date.getDay);

	return Day.getCategoryRanges(dayName);
    }

    static public void loadUserData()
    {
	if(!Auth.isUserLoggedIn) return;

	Day.loadDays;
	Category.loadCategories;
	loadCategoryRanges;
	Note.loadNotes;
    }

    static public char[] search(char[] keywords, int[] categories)
    {
	SearchResultPage.keywords(keywords);
 	if(keywords.length < SEARCH_KEYWORDS_MIN_LENGTH)
 	    return "Search term \"" ~ SearchResultPage.keywords ~ "\" is too short. Make it at least 3 characters long.";
	if(!SearchResultPage.compileSearchResults(keywords, categories))
	    return "Nothing found for \"" ~ SearchResultPage.keywords ~ "\".";

	return "";
    }

    /*
      Return requested result page
     */
    static public char[] getSearchResultPage(int pageNum = 0)
    {
	foreach(page; SearchResultPage.resultPages)
	{
	    if(page.index == pageNum)
	    {
		char[] content = page.content;
		char[] pager = SearchResultPage.getPager(pageNum);
		if(0 < pager.length)
		    content = pager ~ "\n\n" ~ page.content ~ "\n" ~ pager;

		if(0 == pageNum)
		    content = "Search results for \"" ~ SearchResultPage.keywords ~ "\":\n\n" ~ content;
		    
		return content;
	    }
	}

	return "Search result page " ~ Integer.toString(pageNum) ~ " not found.";
    }

    /*
      Return array of day numbers of the month given calendar is set to
     */
    static public int[] getDayNumbers(DateTime date)
    {
	int[] days;
	foreach(day; Day.days)
	{
	    char[] dateStr = dateToFileName(date.getYear,
					    date.getMonth + 1,
					    date.getDay);
	    // given day is in Day array and has content
	    if((day.name[0..6] == dateStr[0..6]) && (0 < day.text.length))
		days ~= Integer.toInt(day.name[6..8]);
	}

	return days;
    }

    static public int addNote(char[] name = "")
    {
	return Note.addNote(name);
    }

    static public void removeNote(int id)
    {
	Note.removeNote(id);
    }

    static public char[] noteName(int id)
    {
	return Note.noteName(id);
    }

    static public void noteName(int id, char[] name)
    {
	Note.noteName(id, name);
    }


    static public void noteContent(int id, char[] content)
    {
	Note.noteContent(id, content);
    }

    static public char[] noteContent(int id)
    {
	return Note.noteContent(id);
    }

    static public char[][int] getNotes()
    {
	return Note.getNotes;
    }
}