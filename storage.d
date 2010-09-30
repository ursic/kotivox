/*****************************************************************************
 *
 *   Kotivox
 * 
 *   Copyright 2009 Mitja Ursic
 *   odtihmal@gmail.com
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
    private char[] origDigest;

    // [0] - start of category
    // [1] - length of category
    // [2] - 0 for normal text, 1 for bold - indicating category title
    private int[][] categoryRanges;

    private static Day[] days;

    this(char[] name, char[] text)
    {
	this.name = name;
	this.text = text;
	this.digest;
    }

    /*
      Digest text and category ranges for comparison later.
     */
    private void digest()
    {
        this.origDigest = util.digest(this.text ~ serialize(this.categoryRanges));
    }

    /*
      Decrypt user days.
     */
    private static void load()
    {
	// Gather all day files for this user.
        days = null;
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
	    foreach(d; days)
		if(d.name == dayName)
		{
		    d.text = text;
		    break;
		}
	}
        else
        {
            // Invalidate digest so that it gets saved.
            Day day = new Day(dayName, text);
            day.origDigest = "";
            days ~= day;
        }
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


    /*
      Store encrypted category ranges into file.
    */
    private bool saveCategoryRanges()
    {
        int[][] catRanges = this.categoryRanges;
        char[] catRangesFileName = Auth.userDirPath ~ this.name ~ USER_CATEGORY_RANGES_FILE_EXTENSION;

        // No category ranges, remove file.
        if(catRanges.length <= 0)
        {
            FilePath catRangesFile = new FilePath(catRangesFileName);
            if(catRangesFile.exists) catRangesFile.remove;

            return false;
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

        k_encrypt_from_string(rangesTxt,
                              catRangesFileName,
                              Auth.cipherKey);

        return true;
    }


    private static void save()
    {
        char[] textFilePath;
        char[] text;
        int next;

        foreach(day; days)
        {
            next = 0;

            textFilePath = Auth.userDirPath ~ day.name ~ USER_DAY_FILE_EXTENSION;

            // Remove existing text file if no more text.
            text = Day.dayGetText(day.name);
            if(0 == text.length)
            {
                FilePath textFile = new FilePath(textFilePath);
                if(textFile.exists) textFile.remove;

                next++;
            }

            if(!day.saveCategoryRanges) next++;

            if(2 == next) continue;

            // Unchanged.
            char[] digest = day.origDigest;
            day.digest;
            if(digest == day.origDigest) continue;

            // Store encrypted text into file.
            k_encrypt_from_string(text,
                                  textFilePath,
                                  Auth.cipherKey);
        }
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
    private static int add()
    {
	int id = getFreeSlot(getIds);
	categories ~= new Category(id, CATEGORY_TEXT ~ " " ~ Integer.toString(id + 1));
	return id;
    }

    /*
      Removes category of given id from categories array.
    */
    private static void remove(int id)
    {
	Category new_categories[];
	foreach(Category category; categories)
	{
	    if(category.id == id) continue;
	    new_categories ~= category;
	}
	categories = new_categories;
        catRetrCount = categories.length;
    }

    private static void categoryName(int id, char[] name)
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
    private static void save()
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
    private static void load()
    {
	// Does categories file exist?
	char[] filename = Auth.userDirPath ~ USER_CATEGORIES_FILE;
	if(!(new FilePath(filename)).exists) return;
	
	// Decrypt categories file and store categories.
	char[] content = k_decrypt_to_string(filename, Auth.cipherKey);

	Category.origDigest = digest(content);

        categories = null;
	foreach(char[] id, char[] name; parseLines(content))
	    categories ~= new Category(Integer.toInt(id), name);

	catRetrCount = categories.length;
    }

    /*
      Return name of category with ID.
     */
    private static char[] categoryName(int id)
    {
	foreach(Category c; categories)
	    if(c.id == id) return c.name;

	return "";
    }

    /*
      Return ID of category with name.
     */
    private static int getID(char[] name)
    {
	foreach(Category c; categories)
	    if(Unicode.toLower(c.name) == Unicode.toLower(Txt.trim(name))) return c.id;

	return -1;
    }

    /*
      Return associative array with category id as key
      and category name as value.
     */
    private static char[][] get()
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
	foreach(range; day.categoryRanges)
	{
	    int bold = range[2];
	    // At category title.
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
	    // At category body.
	    // And end only if start is valid.
	    else if((0 == bold) && (-1 < start))
	    {
		int tempEnd = start + title.length + range[1];
		if(start < tempEnd) end = tempEnd;
	    }

	    if((-1 < start) && (0 < end))
	    {
		// Split category names and add them among
		// day categories.
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
                        
                        int start = find(head, " ") + 1;
                        if(start < head.length) head = head[start..$];
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
		    else content ~= result;

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
    private static void save()
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
    private static void load()
    {
        notes = null;
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
    private static void save()
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
            chain.changed = false;
	}

	// Remove obsolete chain files.
	foreach(file; (new FileScan)(Auth.userDirPath, CHAIN_FILE_EXTENSION).files)
	    if(!contains(chainFiles, file.path ~ file.file))
		file.remove;
    }

    /*
      Decrypt chains from files.
     */
    private static void load()
    {
        chains = null;
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
    public static void saveText(char[] dayName, in char[] text)
    {
	Day.daySetText(dayName, text);
    }

    /*
      Encrypt today's text to file.
     */
    public static void saveFinal()
    {
        Day.save;
	Category.save;
	Note.save;
	Chain.save;
    }

    /*
      Get decrypted text for date.
      Return today's text if date is null.
    */
    public static char[] getText(DateTime date = null)
    {
	char[] text = "";
	char[] dayName = dateStr(date);
	if(0 < Day.dayGetText(dayName).length)
	    text = Day.dayGetText(dayName);

	return text;
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

    public static char[][] getCategory()
    {
	return Category.get;
    }

    public static int addCategory(char[] name)
    {
	return Category.add;
    }

    public static void renameCategory(int id, char[] name)
    {
	Category.categoryName(id, name);
    }

    public static void removeCategory(int id)
    {
	Category.remove(id);
    }

    public static char[] getCategoryName(int id)
    {
	return Category.categoryName(id);
    }

    public static int getCategoryID(char[] name)
    {
	return Category.getID(name);
    }

    /*
      Set category ranges for date.
     */
    public static void setCategoryRanges(char[] dayName, int[][] ranges)
    {
	Day.setCategoryRanges(dayName, ranges);
    }

    /*
      Return array of category ranges for given date.
     */
    public static int[][] getCategoryRanges(DateTime date = null)
    {
	return Day.getCategoryRanges(dateStr(date));
    }

    public static void loadUserData()
    {
	if(!Auth.isUserLoggedIn) return;

	Day.load;
	Category.load;
	loadCategoryRanges;
	Note.load;
	Chain.load;
    }

    public static char[] search(char[] keywords, int[] categories)
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
    public static char[] getSearchResultPage(int pageNum = 0)
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
    public static int[] getDayNumbers(DateTime date)
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

    public static int addNote()
    {
	return Note.add;
    }

    public static void removeNote(int id)
    {
	Note.remove(id);
    }

    public static char[] noteName(int id)
    {
	return Note.noteName(id);
    }

    public static void noteName(int id, char[] name)
    {
	Note.noteName(id, name);
    }


    public static void noteContent(int id, char[] content)
    {
	Note.noteContent(id, content);
    }

    public static char[] noteContent(int id)
    {
	return Note.noteContent(id);
    }

    public static char[][int] getNotes()
    {
	return Note.getNotes;
    }

    public static int addChain()
    {
	return Chain.add;
    }

    public static void removeChain(int id)
    {
	Chain.remove(id);
    }

    public static char[][int] getChains()
    {
	return Chain.getChains;
    }

    public static char[] chainName(int id)
    {
	return Chain.chainName(id);
    }

    public static void chainName(int id, char[] name)
    {
	Chain.chainName(id, name);
    }

    public static char[] chainDesc(int id)
    {
	return Chain.chainDesc(id);
    }

    public static void chainDesc(int id, char[] desc)
    {
	Chain.chainDesc(id, desc);
    }

    public static void addChainDate(int chainID, int date)
    {
	Chain.addDate(chainID, date);
    }

    public static void removeChainDate(int chainID, int date)
    {
	Chain.removeDate(chainID, date);
    }

    public static Date getChainStartDate(int chainID)
    {
	return Chain.getStartDate(chainID);
    }

    public static int[] getChainDates(int chainID, int year)
    {
	return Chain.getDates(chainID, year);
    }

    public static void lockChain(int chainID)
    {
	Chain.lock(chainID);
    }

    public static void unlockChain(int chainID)
    {
	Chain.unlock(chainID);
    }

    public static bool isChainLocked(int chainID)
    {
	return Chain.isLocked(chainID);
    }
}