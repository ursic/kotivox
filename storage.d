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
import Unicode = tango.text.Unicode;
import Integer = tango.text.convert.Integer;

import dwt.DWT;
import dwt.widgets.DateTime;

import config;
import util;
import auth;
import crypt;


private class Day
{
    private char[] name;
    private char[] text;

    // [0] - start of category
    // [1] - length of category
    // [2] - 0 for normal text, 1 for bold - indicating category title
    private int[][] categoryRanges;

    private static Day[] days;

    this(char[] name, char[] text)
    {
	this.name = name;
	this.text = text;
    }

    /*
      Decrypt user days.
     */
    private static void loadDays()
    {
	// Gather all day files for this user.
	foreach(file; (new FileScan)(Auth.userDirPath, USER_DAY_FILE_EXTENSION).files)
	{
	    // Decrypt text and store it.
	    char[] textOut = k_decrypt_to_string(file.path ~ file.file, Auth.cipherKey);
	    days ~= new Day(file.name, textOut);
	}
    }

    private static bool dayExists(char[] dayName)
    {
	foreach(Day d; days)
	    if(d.name == dayName) return true;

	return false;
    }

    private static void daySetText(char[] dayName, char[] text)
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

    private static char[] dayGetText(char[] dayName)
    {
	foreach(Day d; days)
	    if(d.name == dayName) return d.text;

	return "";
    }

    private static void setCategoryRanges(char[] dayName, int[][] ranges)
    {
	foreach(day; days)
	    if(dayName == day.name)
	    {
		day.categoryRanges = ranges;
		break;
	    }
    }

    private static int[][] getCategoryRanges(char[] dayName)
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
    // Category retrieval counter.
    private static int catRetrCount = 0;
    private static char[] origDigest;

    this(int id, char[] name)
    {
	this.id = id;
	this.name = name;
    }

    private static int[] getIds()
    {
	int[] ids;
	foreach(c; categories) ids ~= c.id;
	return ids;
    }

    /*
      Add new category with name to categories array.
      Return id of added category.
    */
    private static int addCategory(char[] name)
    {
	int id = getFreeSlot(getIds);
	categories ~= new Category(id, sanitizeStr(name));
	return id;
    }

    /*
      Removes category of given id from categories array.
    */
    private static void removeCategory(int id)
    {
	Category new_categories[];
	foreach(Category category; categories)
	{
	    if(category.id == id) continue;
	    new_categories ~= category;
	}
	categories = new_categories;
    }

    private static void renameCategory(int id, char[] name)
    {
	foreach(Category c; categories)
	{
	    if(c.id == id)
	    {
		c.name = sanitizeStr(name);
		break;
	    }
	}
    }

    /*
      Encrypt categories into file.
     */
    private static void saveCategories()
    {
	char[] content;
	foreach(Category c; categories)
	{
	    // Skip categories with empty names.
	    if(Txt.trim(c.name).length <= 0) continue;

	    content ~= Integer.toString(c.id) ~ " " ~ c.name ~ "\n";
	}

	char[] catFileName = Auth.userDirPath ~ USER_CATEGORIES_FILE;

	// No categories, remove file if exists.
	if(content.length <= 0)
	{
	    FilePath catFile = new FilePath(catFileName);
	    if(catFile.exists) catFile.remove;

	    return;
	}

	// Unchanged.
	if(digest(content) == Category.origDigest) return;

	// Encrypt categories into file.
	k_encrypt_from_string(content,
			      catFileName,
			      Auth.cipherKey);
	Category.origDigest = digest(content);
    }

    /*
      Decrypt user categories.
     */
    private static void loadCategories()
    {
	// Does categories file exist?
	char[] filename = Auth.userDirPath ~ USER_CATEGORIES_FILE;
	if(!(new FilePath(filename)).exists) return;
	
	// Decrypt categories file and store categories.
	char[] content = k_decrypt_to_string(filename, Auth.cipherKey);

	Category.origDigest = digest(content);

	foreach(char[] id, char[] name; parseLines(content))
	    categories ~= new Category(Integer.toInt(id), name);

	catRetrCount = categories.length;
    }

    /*
      Return name of category with id.
     */
    private static char[] getCategoryName(int id)
    {
	foreach(Category c; categories)
	    if(c.id == id) return c.name;

	return "";
    }

    /*
      Return ID of category with name.
     */
    private static int getCategoryID(char[] name)
    {
	foreach(Category c; categories)
	    if(Unicode.toLower(c.name) == Unicode.toLower(Txt.trim(name))) return c.id;

	return -1;
    }

    /*
      Return associative array with category id as key
      and category name as value.
     */
    private static char[][] getCategory()
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
    private static int[] invCategoryIDs(int[] selCategories)
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
	if(0 == resultPages.length) return 0;

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
    private static bool compileSearchResults(char[] keywordStr, int[] categories)
    {
	// Clear previous search.
	resultPages = null;

	char[] content;
	int appendLength = SEARCH_RESULT_LENGTH / 2;
	uint numResults;
	foreach(day; Day.days.dup.reverse)
	{
	    int end = day.text.length;
	    int location = 0;
	    char[] result;

	    // Skip emtpy days.
	    if(end <= 0) continue;

	    entry: do
	    {
		location = Txt.locatePattern(Unicode.toLower(day.text),
					     Unicode.toLower(keywordStr),
					     location);
		// Match found.
		// Prepend and append some text around keywordStr.
		// Prepend link above the result.
		if((0 == location) || (location < end))
		{
		    // Is the start of found match inside given categories?
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
		    // Start head after first whitespace so we don't
		    // cut any variable-width characters.
		    if(0 <= (location - appendLength))
		    {
			head = day.text[location - appendLength..location];
			head = head[find(head, " ") + 1..$];
		    }

		    core = day.text[location..location + keywordStr.length];

		    // End tail after last whitespace so we don't
		    // cut any variable-width characters.
		    if((location + keywordStr.length + appendLength) <= day.text.length)
		    {
			tail = day.text[location + keywordStr.length..location + keywordStr.length + appendLength];
			tail = tail[0..rfind(tail, " ")];
		    }

		    char[] dateStr = dateFormat("%A, %e. %B, %Y", dateStrToDate(day.name));
		    result ~= "<a href=\"JUMP" ~ day.name ~ Integer.toString(location) ~ "-" ~ this.keywords  ~ "\">" ~ dateStr ~ "</a>\n";
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

	// Save what's left of search results.
	if(0 < content.length)
	    resultPages ~= new SearchResultPage(getNextIndex, content);

 	if(!numResults) return false;

	return true;
    }

    private static char[] getPager(int currentPage)
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
    private char[] origName;
    private char[] filename;
    private char[] content;
    private char[] origDigest;

    private static Note[] notes;

    this(char[] name, char[] filename = "", char[] content = "")
    {
	this.id = getFreeSlot(getIds);
	this.name = sanitizeStr(name);
	this.origName = this.name;
	if(filename.length <= 0) filename = randStr ~ NOTE_FILE_EXTENSION;
	this.filename = filename;
	this.content = content;
	this.origDigest = digest(this.content);
    }

    private static int add()
    {
	int id = getFreeSlot(getIds);
	notes ~= new Note(NOTES_TEXT ~ " " ~ Integer.toString(id + 1));
	return id;
    }

    /*
      Removes note of given id from notes array.
    */
    private static void remove(int id)
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
    private static char[] noteName(int id)
    {
	foreach(note; notes)
	    if(note.id == id) return note.name;

	return "I CANNOT FIND NOTE " ~ Integer.toString(id) ~ ".";
    }

    // Set note name.
    private static void noteName(int id, char[] name)
    {
	foreach(note; notes)
	{
	    if(note.id == id)
	    {
		note.name = sanitizeStr(name);
		break;
	    }
	}
    }

    private static void noteContent(int id, char[] content)
    {
	foreach(n; notes)
	{
	    if(n.id == id)
	    {
		n.content = content;
		break;
	    }
	}
    }

    private static char[] noteContent(int id)
    {
	foreach(n; notes)
	    if(n.id == id) return n.content;
	return "";
    }

    private static int[] getIds()
    {
	int[] ids;
	foreach(n; notes) ids ~= n.id;
	return ids;
    }

    /*
      Encrypt notes into files.
     */
    private static void saveNotes()
    {
	char[] noteFiles;
	foreach(note; notes)
	{
	    char[] noteFilePath = Auth.userDirPath ~ note.filename;
	    
	    // Skip note with empty name.
	    if(note.name.length <= 0)
	    {
		// Delete note file if exists.
		FilePath noteFile = new FilePath(noteFilePath);
		if(noteFile.exists) noteFile.remove;		

		continue;
	    }

	    noteFiles ~= noteFilePath;

	    // Skip note with unchanged content.
	    if((note.origName == note.name) &&
	       (digest(note.content) == note.origDigest))
		continue;

	    // Write name of the note in first line.
	    char[] content = note.name ~ "\n" ~ note.content;
	    k_encrypt_from_string(content,
				  noteFilePath,
				  Auth.cipherKey);
	    note.origName = note.name;
	    note.origDigest = digest(note.content);
	}

	// Remove obsolete note files.
	foreach(file; (new FileScan)(Auth.userDirPath, NOTE_FILE_EXTENSION).files)
	    if(!contains(noteFiles, file.path ~ file.file))
		file.remove;
    }

    /*
      Decrypt notes from files.
     */
    private static void loadNotes()
    {
	foreach(file; (new FileScan)(Auth.userDirPath, NOTE_FILE_EXTENSION).files)
	{
	    // Decrypt text and store it.
	    char[] textOut = k_decrypt_to_string(file.path ~ file.file, Auth.cipherKey);
	    char[][] lines = Txt.splitLines(textOut);

	    // First line contains note's name.
	    char[] name = lines[0];

	    // The rest of the lines is content.
	    char[] content = "";
	    for(int i = 1; i < lines.length; i++)
		content ~= lines[i] ~ "\n";

	    notes ~= new Note(name,
			      file.file,
			      content);
	}
    }
    
    private static char[][int] getNotes()
    {
	char[][int] noteList;
	foreach(note; notes) noteList[note.id] = note.name;
	return noteList;
    }
}


/**********************************************************************************************************
 *   Jerry Seinfeld's task chain
 *
 *   Get a big wall calendar that has a whole year on one page
 *   and hang it on a prominent wall.
 *   Get a big red magic marker.
 *
 *   Each day that you do your task, put a big red X over that day.
 *   "After a few days you'll have a chain. Just keep at it
 *   and the chain will grow longer every day. You'll like seeing that chain,
 *   especially when you get a few weeks under your belt.
 *   Your only job next is to not break the chain."
 *
 *   "Don't break the chain."
 *
 *   http://lifehacker.com/software/motivation/jerry-seinfelds-productivity-secret-281626.php
 *   http://www.thesimpledollar.com/2007/07/26/applying-jerry-seinfelds-chain-concept-to-personal-finance/
 *********************************************************************************************************/
private class Chain
{
    private int id;
    private char[] name;
    private char[] desc;
    private char[] filename;
    private Date startDate;
    private bool locked = false;
    private int[] dates;
    private bool changed = false;
    private static Chain[] chains;

    this(char[] name,
	 Date startDate = today,
	 char[] desc = "",
	 bool locked = false,
	 char[] filename = randStr ~ CHAIN_FILE_EXTENSION,
	 int[] dates = null)
    {
	this.id = getFreeSlot(getIds);
	this.name = sanitizeStr(name);
	this.startDate = startDate;
	this.desc = desc;
	this.locked = locked;
	this.filename = filename;
	this.dates = dates;
    }

    private static int[] getIds()
    {
	int[] ids;
	foreach(n; chains) ids ~= n.id;
	return ids;
    }

    private static int add()
    {
	int id = getFreeSlot(getIds);
	chains ~= new Chain(CHAIN_TEXT ~ " " ~ Integer.toString(id + 1));
	chains[$ - 1].changed = true;
	return id;
    }

    private static void remove(int id)
    {
	Chain new_chains[];
	foreach(chain; chains)
	{
	    if(chain.id == id) continue;
	    new_chains ~= chain;
	}
	chains = new_chains;
    }

    private static char[][int] getChains()
    {
	char[][int] chainlist;
	foreach(chain; chains) chainlist[chain.id] ~= chain.name;
	return chainlist;
    }

    private static char[] chainName(int id)
    {
	foreach(chain; chains)
	    if(chain.id == id) return chain.name;

	return "I CANNOT FIND CHAIN " ~ Integer.toString(id) ~ ".";
    }

    private static void chainName(int id, char[] name)
    {
	foreach(chain; chains)
	{
	    if(chain.id == id)
	    {
		chain.name = sanitizeStr(name);
		chain.changed = true;
		break;
	    }
	}
    }

    private static char[] chainDesc(int id)
    {
	foreach(chain; chains)
	    if(chain.id == id) return chain.desc;

	return "I CANNOT FIND CHAIN " ~ Integer.toString(id) ~ ".";
    }

    private static void chainDesc(int id, char[] desc)
    {
	foreach(chain; chains)
	{
	    if(chain.id == id)
	    {
		chain.desc = sanitizeStr(desc, CHAIN_DESCRIPTION_LENGTH, false);
		chain.changed = true;
		break;
	    }
	}
    }

    /*
      Add date to chain of given id.
     */
    private static void addDate(int id, int date)
    {
	foreach(chain; chains)
	    if(chain.id == id)
	    {
		if(!contains(chain.dates, date))
		{
		    chain.dates ~= date;
		    chain.changed = true;
		    break;
		}
	    }
    }

    /*
      Remove date from chain of given id.
     */
    private static void removeDate(int id, int date)
    {
	int[] dates;
	foreach(chain; chains)
	    if(chain.id == id)
	    {
		foreach(cdate; chain.dates)
		{
		    if(cdate == date) continue;
		    dates ~= cdate;
		}
		chain.dates = dates;
		chain.changed = true;
		break;
	    }
    }

    /*
      Return start date.
     */
    private static Date getStartDate(int id)
    {
	foreach(chain; chains)
	    if(chain.id == id) return chain.startDate;

	static Date date = {day: -1};
	return date;
    }

    /*
      Return marked days.
     */
    private static int[] getDates(int id, int year)
    {
	int[] dates;
	foreach(chain; chains)
	{
	    if(chain.id == id)
	    {
		foreach(date; chain.dates)
		{
		    if(year == dateStrToDate(date).year)
			dates ~= date;
		}
		return dates;
	    }
	}
	return dates;
    }

    /*
      Lock chain from editing.
     */
    private static void lock(int id)
    {
	foreach(chain; chains)
	    if(chain.id == id)
	    {
		chain.locked = true;
		chain.changed = true;
		break;
	    }
    }

    /*
      Unlock chain for editing.
     */
    private static void unlock(int id)
    {
	foreach(chain; chains)
	    if(chain.id == id)
	    {
		chain.locked = false;
		chain.changed = true;
		break;
	    }
    }

    /*
      Remove date from chain of given id.
     */
    private static bool isLocked(int id)
    {
	foreach(chain; chains)
	    if((chain.id == id) && chain.locked)
		return true;

	return false;
    }

    /*
      Encrypt chains into files.
     */
    private static void saveChains()
    {
	char[] chainFiles;
	foreach(chain; chains)
	{
	    char[] chainFilePath = Auth.userDirPath ~ chain.filename;

	    // Skip chain with empty name.
	    if(chain.name.length <= 0)
	    {
		// Delete chain file if exists.
		FilePath chainFile = new FilePath(chainFilePath);
		if(chainFile.exists) chainFile.remove;
		continue;
	    }

	    chainFiles ~= chainFilePath;

	    // Skip chain with unchanged content.
	    if(!chain.changed) continue;

	    // Write description length in first line.
	    // Write name in second line.
	    // Following is description on the next line.
	    // After description follow dates, each in its line.
	    char[] content = Integer.toString(chain.desc.length);
	    content ~= "\n" ~ chain.name;
	    content ~= "\n" ~ dateStr(chain.startDate);
	    int locked = chain.locked ? 1 : 0;
	    content ~= "\n" ~ Integer.toString(locked);
	    content ~= "\n" ~ chain.desc;
	    char[] dates;
	    foreach(date; chain.dates) dates ~= Integer.toString(date) ~ "\n";
	    content ~= dates;
	    k_encrypt_from_string(content,
				  chainFilePath,
				  Auth.cipherKey);
	}

	// Remove obsolete chain files.
	foreach(file; (new FileScan)(Auth.userDirPath, CHAIN_FILE_EXTENSION).files)
	    if(!contains(chainFiles, file.path ~ file.file))
		file.remove;
    }

    /*
      Decrypt chains from files.
     */
    private static void loadChains()
    {
	foreach(file; (new FileScan)(Auth.userDirPath, CHAIN_FILE_EXTENSION).files)
	{
	    // Decrypt text and store it.
	    char[] textOut = k_decrypt_to_string(file.path ~ file.file, Auth.cipherKey);
	    char[][] lines = Txt.splitLines(textOut);
 	    int descLen = Integer.toInt(lines[0]);
	    // Extract dates which are touching description.
	    char[] tail;
	    for(int i = 4; i < lines.length; i++)
		tail ~= "\n" ~ lines[i];

	    tail = Txt.stripl(tail, '\n');
	    char[] description = tail[0..descLen];

	    tail = tail[descLen..$];
	    // The rest of data are dates.
 	    int[] dates;
	    if(8 <= tail.length)
	    {
		char[][] dateLines = Txt.splitLines(tail);
		foreach(line; dateLines)
		{
		    if(8 == line.length) dates ~= Integer.toInt(line);
		    else break;
		}
	    }
	    chains ~= new Chain(lines[1],
				dateStrToDate(lines[2]),
				description,
				(1 == Integer.toInt(lines[3])) ? true : false,
				file.file,
				dates);
	}
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
	Chain.saveChains;

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
	char[] dayName = dateStr(date);
	if(0 < Day.dayGetText(dayName).length)
	    text = Day.dayGetText(dayName);

	return text;
    }

    /*
      Encrypt category ranges into file.
     */
    private static void saveCategoryRanges()
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
    private static void loadCategoryRanges()
    {
	// Gather all available category ranges.
	foreach(file; (new FileScan)(Auth.userDirPath, USER_CATEGORY_RANGES_FILE_EXTENSION).files)
	{
	    // Decrypt category ranges into array.
	    char[] ranges = k_decrypt_to_string(file.path ~ file.file, Auth.cipherKey);

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
	Day.setCategoryRanges(dateStr(date), ranges);
    }

    /*
      Return array of category ranges for given date.
     */
    static public int[][] getCategoryRanges(DateTime date = null)
    {
	return Day.getCategoryRanges(dateStr(date));
    }

    static public void loadUserData()
    {
	if(!Auth.isUserLoggedIn) return;

	Day.loadDays;
	Category.loadCategories;
	loadCategoryRanges;
	Note.loadNotes;
	Chain.loadChains;
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
	    char[] dateStr = dateStr(date);

	    // Given day is in Day array and has content.
	    if((day.name[0..6] == dateStr[0..6]) && (0 < day.text.length))
		days ~= Integer.toInt(day.name[6..8]);
	}

	return days;
    }

    static public int addNote()
    {
	return Note.add;
    }

    static public void removeNote(int id)
    {
	Note.remove(id);
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

    static public int addChain()
    {
	return Chain.add;
    }

    static public void removeChain(int id)
    {
	Chain.remove(id);
    }

    static public char[][int] getChains()
    {
	return Chain.getChains;
    }

    static public char[] chainName(int id)
    {
	return Chain.chainName(id);
    }

    static public void chainName(int id, char[] name)
    {
	Chain.chainName(id, name);
    }

    static public char[] chainDesc(int id)
    {
	return Chain.chainDesc(id);
    }

    static public void chainDesc(int id, char[] desc)
    {
	Chain.chainDesc(id, desc);
    }

    static public void addChainDate(int chainID, int date)
    {
	Chain.addDate(chainID, date);
    }

    static public void removeChainDate(int chainID, int date)
    {
	Chain.removeDate(chainID, date);
    }

    static public Date getChainStartDate(int chainID)
    {
	return Chain.getStartDate(chainID);
    }

    static public int[] getChainDates(int chainID, int year)
    {
	return Chain.getDates(chainID, year);
    }

    static public void lockChain(int chainID)
    {
	Chain.lock(chainID);
    }

    static public void unlockChain(int chainID)
    {
	Chain.unlock(chainID);
    }

    static public bool isChainLocked(int chainID)
    {
	return Chain.isLocked(chainID);
    }

//     static public void saveChains()
//     {
// 	Chain.saveChains;
//     }
}