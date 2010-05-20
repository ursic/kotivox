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

module gui.gui;

import tango.core.Exception;
import tango.core.Array;
import tango.time.chrono.Gregorian;
import tango.io.Stdout;

import dwt.widgets.Caret;

import gui.chain;
import util;
import io;
import auth;
import storage;


/*
  Menu option.
*/
private struct MenuOption
{
    char[] id;
    int index = -1;
    char[] text;
    int style = DWT.NONE;
    bool show = true;
}


public class GUI
{
    private Shell shell;
    private Display display;
    private int gridDataMarginHeight;
    private int gridDataMarginWidth;
    private int gridDataWidthHint;

    private char errorMsg[];

    private static char[][char[]] authValues;

    private const char[] SEPARATOR1_ID = "-1";
    private const char[] SEPARATOR2_ID = "-2";
    private const char[] TIMESTAMP_ID = "-3";
    private const char[] CLEAR_ID = "-4";

    private static StyledText tp;
    private static MenuOption[] menuOptions;


    public this()
    {
	this.display = new Display;
	this.shell = new Shell(display);

	this.shell.setText = APP_NAME;
	this.shell.setMaximized = true;
	
	this.gridDataWidthHint = LOGIN_CONTROL_WIDTH;
	this.gridDataMarginHeight = LOGIN_WINDOW_MARGIN_TOP;
	this.gridDataMarginWidth = LOGIN_WINDOW_MARGIN_LEFT;
    }


    private void setWindowSizeSettings(Shell shell)
    {
 	Point size = shell.getSize;
	setConfig("windowHeight", Integer.toString(size.y));
	setConfig("windowWidth", Integer.toString(size.x));
    }


    /*
      Convert array of category ranges to style ranges and return them.
     */
    private StyleRange[] categoryRangesToStyleRanges(int[][] categoryRanges)
    {
	StyleRange[] styles;
	foreach(category; categoryRanges)
	{
	    int start = category[0];
	    int length = category[1];
	    int fontStyle = category[2];

	    styles ~= new StyleRange(start,
				     length,
				     null,
				     getColor(getConfig(USER_CATEGORY_BACKGROUND_COLOR_SETTING_NAME)),
				     fontStyle);
	}
	return styles;
    }


    /*
      Convert array of style ranges to category ranges and return them.
     */
    private int[][] styleRangesToCategoryRanges(StyleRange[] styles)
    {
	int[][] categoryRanges;
	foreach(StyleRange style; styles)
	    categoryRanges ~= [style.start, style.length, style.fontStyle];

	return categoryRanges;
    }


    /*
      Remove style from text hugging the current line
     */
    private int clearStyle(StyledText text,
			   int currLineUp = 0,
			   int currOffsetDown = 0,
			   bool aboveClear = false,
			   bool belowClear = false,
			   int lastUp = -1)
    {
 	if(aboveClear && belowClear) return lastUp;
	if((currLineUp < 0) && (text.getCharCount <= currOffsetDown)) return lastUp;

	// remove style by line increments on current line and above
	if(!aboveClear && (0 <= currLineUp))
	{
	    int start = text.getOffsetAtLine(currLineUp);
	    if(text.getStyleRangeAtOffset(start))
	    {
		// remove style for "\n" character where new line
		int inc = 0;
		if((start + text.getLine(currLineUp).length + 1) < text.getCharCount)
		    inc = 1;

		text.setStyleRanges(start, text.getLine(currLineUp).length + inc, null, null);
		lastUp = currLineUp;
	    }
	    else
		aboveClear = true;
	}

	// remove style by character increments below current line
	if(!belowClear && (currOffsetDown < text.getCharCount))
	{
	    if(text.getStyleRangeAtOffset(currOffsetDown))
 		text.setStyleRanges(currOffsetDown, 1, null, null);
 	    else
 		belowClear = true;
	}

	return lastUp = clearStyle(text, --currLineUp, ++currOffsetDown, aboveClear, belowClear, lastUp);
    }


    /*
      Walk text widget recursively from current line upwards 
      and return start and end of the first line with bold style in line
     */
    private void getBoldLine(StyledText text, int currLine = 0, out Point line = null)
    {
	if(currLine < 0) return;

	StyleRange style = text.getStyleRangeAtOffset(text.getOffsetAtLine(currLine));
	if(!style) return;
	// found category title style
	else if(style.fontStyle & DWT.BOLD)
	{
	    line = new Point(style.start, text.getLine(currLine).length);
	    return;
	}
	// this line has category body style, no bold
	else
	    getBoldLine(text, --currLine, line);
    }


    /*
      Add category name catName to line.
     */
    private void addCategoryName(StyledText text, Point line, char[] catName)
    {
	int start = line.x;
	int length = line.y;
	int end = line.x + line.y;

	char[] title = text.getText(start, end);
	char[][] names = Txt.split(title, ",");

	// remove spaces
	char[][] cNames;
	foreach(name; names)
	{
	    name = Txt.trim(name);
	    if(0 == name.length) continue;

	    // is given category name already in title?
	    if(name == catName)	return;

	    cNames ~= name;
	}

	char[] newTitle = "";
	foreach(cName; cNames)
	    newTitle ~= cName ~ ", ";

	newTitle ~= catName;
	text.replaceTextRange(start, length, newTitle);
	// background for category title(s)
	StyleRange styleTitle = new StyleRange(start,
					       newTitle.length,
					       null,
					       getColor(USER_CATEGORY_BACKGROUND_COLOR),
					       DWT.BOLD);
	text.setStyleRange(styleTitle);
    }


    /*
      Return array of IDs of selected categories
     */
    private int[] getSelectedCategories(Composite parent)
    {
	int[] categories;
	foreach(child; parent.getChildren)
	{
	    if(child.getStyle & DWT.CHECK)
	    {
		Button catCheck = cast(Button)child;
		if(catCheck.getSelection)
		    categories ~= Integer.toInt((cast(Data)catCheck.getData).get("id"));
	    }
	}
	return categories;
    }

    
    /*
      Embolden calendar days containing text.
      Unmark all the rest.
     */
    private void markCalendarDays(DateTime calendar)
    {
	int maxDays = (new Gregorian).getDaysInMonth(calendar.getYear,
						     calendar.getMonth + 1,
						     Gregorian.AD_ERA);
	int[] days = Storage.getDayNumbers(calendar);
	for(int i = 1; i <= maxDays; i++)
	{
	    if(contains(days, i))
		calendar.markDay(i);
	    else
		calendar.unmarkDay(i);
	}
    }


    /*
      Store text in text pad according to note ID.
      -1 indicates text, values 0 or larger indicate note.
     */
    private void saveText()
    {
	StyledText txtPad = getTextPad;
	int id = Integer.toInt((cast(Data)txtPad.getData).get("noteid"));
	// Invalid note ID indicates day text, so we save to today's day.
	if(-1 == id)
	{
	    if(!txtPad.getEditable) return;
	    Storage.saveText(txtPad.getText);
	    Storage.setCategoryRanges(null, styleRangesToCategoryRanges(txtPad.getStyleRanges));
	}
	else if(0 <= id)
	    Storage.noteContent(id, txtPad.getText);
    }

    
    private void hideSearchChildren(Composite parent)
    {
	foreach(child; parent.getChildren)
	    if(("ScrolledComposite" == child.getName) || "Text" == child.getName)
		child.dispose;

	parent.layout;
    }


    private void addMenuOption(MenuOption option)
    {
	removeMenuOption(option);
	menuOptions ~= option;
	updateMenu;
    }


    private void removeMenuOption(MenuOption option)
    {
	MenuOption[] options;
	foreach(opt; menuOptions)
	{
	    if(opt.id == option.id) continue;
	    options ~= opt;
	}

	menuOptions = options;
	updateMenu;
    }


    /*
      Populate text pad menu with stored options.
     */
    private void updateMenu()
    {
        StyledText txtPad = getTextPad;
	Menu menu = getTextPad.getMenu;
        if(menu is null) menu = new Menu(getTextPad);
	foreach(item; menu.getItems) item.dispose;
	MenuItem item;
	foreach(option; menuOptions)
	{
	    if(!option.show) continue;

	    if(-1 == option.index)
		item = new MenuItem(menu, option.style);
	    else
		item = new MenuItem(menu, option.style, option.index);
	    item.setData(new Data("id", option.id));
	    if(0 < option.text.length) item.setText(option.text);
	    addMenuItemListener(item);
	}
    }


    private void categoryOptions(bool show = true)
    {
	MenuOption[] mo;
	foreach(option; menuOptions)
	{
	    if(option.id != TIMESTAMP_ID)
            {
		if(show) option.show = true;
		else option.show = false;
            }
	    mo ~= option;
	}
	menuOptions = mo;
    }


    private void addTimestampMenu()
    {
	static MenuOption timestamp = {id:TIMESTAMP_ID};
	timestamp.text = "(" ~ util.timestamp ~ ")";
	getTextPad.setMenu(new Menu(getTextPad));
	categoryOptions(false);
	addMenuOption(timestamp);
    }


    private void login(Shell shell, Label msgLabel)
    {
	if(contains(this.authValues.keys, "usernameL") &&
	   contains(this.authValues.keys, "passwordL"))
	{
	    char[][] userData = [this.authValues["usernameL"],
				 this.authValues["passwordL"]];
	    char[] errorMsg;
	    if(Auth.login(userData, errorMsg)) drawMainWindow(shell);
	    else msgLabel.setText(errorMsg);
	}
    }


    private void register(Shell shell, Label msgLabel)
    {
	if(contains(this.authValues.keys, "usernameR") &&
	   contains(this.authValues.keys, "passwordR") &&
	   contains(this.authValues.keys, "passwordRR"))
	{
	    char[][] userData = [this.authValues["usernameR"],
				 this.authValues["passwordR"],
				 this.authValues["passwordRR"]];
	    char[] errorMsg;
	    if(Auth.register(userData, errorMsg)) drawMainWindow(shell);
	    else msgLabel.setText(errorMsg);
	}
	else msgLabel.setText(CANNOT_REGISTER);
    }


    private void redrawParent(Composite c, bool expand = false)
    {
        ScrolledComposite sc = cast(ScrolledComposite)c.getParent;
        sc.setContent(c);
        sc.setMinSize(c.computeSize(DWT.DEFAULT, DWT.DEFAULT));

        if(expand)
        {
            sc.setExpandHorizontal(true);
            sc.setExpandVertical(true);
        }
    }


    private void addShellListener(Shell shell)
    {
	shell.addShellListener(new class(shell) ShellAdapter
	{
	    Shell shell;
	    this(Shell shell)
	    {
		this.shell = shell;
	    }

	    public void shellClosed(ShellEvent event)
	    {
		setWindowSizeSettings(shell);
		saveConfig(Auth.userConfig);
	    }
	});
    }


    private void addTextListener(Text textInput)
    {
	textInput.addModifyListener(new class(textInput) ModifyListener
        {
	    Text text;
	    this(Text text)
            {
		this.text = textInput;
	    }

	    public void modifyText(ModifyEvent event)
            {
		this.outer.authValues[(cast(Data)this.text.getData).get("name")] = this.text.getText;
	    }
	});
    }


    /*
      Login or register user when ENTER is pressed
      in either password field
     */
    private void addFormListener(Text textInput, Label labelInput)
    {
	textInput.addKeyListener(new class(labelInput) KeyListener
	{
	    Label msgLabel;
	    Shell newShell;
	    this(Label msgLabel)
	    {
		this.msgLabel = labelInput;
		this.newShell = shell;
	    }
	    public void keyPressed(KeyEvent event)
            {
		if((event.keyCode == KEY_ENTER) || (event.keyCode == KEY_KP_ENTER))
		{
		    switch((cast(Data)event.widget.getData).get("name"))
		    {
		    case "passwordL":
			login(this.newShell, this.msgLabel);
			break;

                    case "passwordRR":
			register(this.newShell, this.msgLabel);
			break;

                    default:
			Stdout("Unknown button").newline;
		    }
		}
	    }
	    public void keyReleased(KeyEvent event){}
	});
    }


    private void addButtonListener(Button buttonInput, Label labelInput)
    {
	buttonInput.addListener(DWT.Selection, new class(labelInput) Listener
	{
	    Label msgLabel;
	    Shell newShell;
	    this(Label msgLabel)
	    {
		this.msgLabel = labelInput;
		this.newShell = shell;
	    }
	    public void handleEvent(Event event)
            {
		switch(event.widget.getNameText)
		{
		    case "Login":
			login(this.newShell, this.msgLabel);
		    break;

                    case "Register":
			register(this.newShell, this.msgLabel);
		    break;

                    default:
			Stdout("Unknown button").newline();
		}
	    }
	});
    }


    public void prepareRegisterWindow()
    {
	Composite formGroup = new Composite(this.shell, DWT.NONE);
	GridLayout gridLayout = new GridLayout(3, true);
        this.shell.setLayout(gridLayout);
        formGroup.setLayout(gridLayout);
        gridLayout.marginHeight = this.gridDataMarginHeight;
        gridLayout.marginWidth = this.gridDataMarginWidth;

	GridData gdMsg = new GridData(GridData.FILL_HORIZONTAL);
	gdMsg.horizontalSpan = 3;
	gdMsg.heightHint = LOGIN_TEXT_INPUT_HEIGHT * 3;
	Label lMsg = new Label(formGroup, DWT.LEFT | DWT.WRAP);
	Color color = new Color(Display.getCurrent, 0, 0, 150);
	setFont(lMsg, FONT_SIZE_4, DWT.BOLD);
	lMsg.setForeground(color);
        lMsg.setLayoutData(gdMsg);

	GridData gd1 = new GridData(GridData.FILL_HORIZONTAL);
	Label lUsernameL = new Label(formGroup, DWT.LEFT);
	lUsernameL.setText(USERNAME_TEXT);
        lUsernameL.setLayoutData(gd1);

	Label lBlank1 = new Label(formGroup, DWT.NONE);
        lBlank1.setLayoutData (gd1);

	Label lUsernameR = new Label(formGroup, DWT.LEFT);
	lUsernameR.setText(USERNAME_TEXT);
        lUsernameR.setLayoutData(gd1);

	GridData gd2 = new GridData(GridData.FILL_BOTH);
	Text tUsernameL = new Text(formGroup, DWT.BORDER);
	gd2.widthHint = this.gridDataWidthHint;
        tUsernameL.setLayoutData(gd2);
	// Prevent default menu.
	tUsernameL.setMenu(new Menu(tUsernameL));
	tUsernameL.setData(new Data("name", "usernameL"));

	Label lBlank2 = new Label(formGroup, DWT.NONE);
        lBlank2.setLayoutData (gd2);

	Text tUsernameR = new Text(formGroup, DWT.BORDER);
	gd2.widthHint = this.gridDataWidthHint;
        tUsernameR.setLayoutData(gd2);
	// Prevent default menu.
	tUsernameR.setMenu(new Menu(tUsernameL));
	tUsernameR.setData(new Data("name", "usernameR"));

	GridData gd3 = new GridData(GridData.FILL_BOTH);
	Label lPasswordL = new Label(formGroup, DWT.LEFT);
	lPasswordL.setText(PASSWORD_TEXT);
        lPasswordL.setLayoutData(gd3);

	Label lBlank3 = new Label(formGroup, DWT.CENTER);
        lBlank3.setLayoutData(gd3);
	lBlank3.setText(OR_TEXT);

	Label lPasswordR = new Label(formGroup, DWT.LEFT);
	lPasswordR.setText(PASSWORD_TEXT);
        lPasswordR.setLayoutData(gd3);

	GridData gd4 = new GridData(GridData.FILL_BOTH);
	Text tPasswordL = new Text(formGroup, DWT.BORDER | DWT.PASSWORD);
	gd4.widthHint = this.gridDataWidthHint;
        tPasswordL.setLayoutData(gd4);
	// Prevent default menu.
	tPasswordL.setMenu(new Menu(tPasswordL));
	tPasswordL.setData(new Data("name", "passwordL"));

	Label lBlank4 = new Label(formGroup, DWT.NONE);
        lBlank4.setLayoutData(gd4);

	Text tPasswordR = new Text(formGroup, DWT.BORDER | DWT.PASSWORD);
	gd4.widthHint = this.gridDataWidthHint;
        tPasswordR.setLayoutData(gd4);
	// Prevent default menu.
	tPasswordR.setMenu(new Menu(tPasswordR));
	tPasswordR.setData(new Data("name", "passwordR"));

	GridData gd5 = new GridData(GridData.FILL_BOTH);
	Label lBlank6 = new Label(formGroup, DWT.NONE);
        lBlank6.setLayoutData(gd5);
	Label lBlank7 = new Label(formGroup, DWT.NONE);
        lBlank7.setLayoutData(gd5);

	Label lPasswordRR = new Label(formGroup, DWT.LEFT);
	lPasswordRR.setText(PASSWORD_AGAIN_TEXT);
        lPasswordRR.setLayoutData(gd5);

	GridData gd6 = new GridData(GridData.FILL_BOTH);
	Label lBlank8 = new Label(formGroup, DWT.NONE);
        lBlank8.setLayoutData(gd6);
	Label lBlank9 = new Label(formGroup, DWT.NONE);
        lBlank9.setLayoutData(gd6);

	Text tPasswordRR = new Text(formGroup, DWT.BORDER | DWT.PASSWORD);
	gd6.heightHint = LOGIN_TEXT_INPUT_HEIGHT;
        tPasswordRR.setLayoutData(gd6);
	// Prevent default menu.
	tPasswordRR.setMenu(new Menu(tPasswordRR));
	tPasswordRR.setData(new Data("name", "passwordRR"));

	GridData gd8 = new GridData(GridData.FILL_BOTH);
	Button bLogin = new Button(formGroup, DWT.BORDER);
	bLogin.setText(LOGIN_TEXT);
	gd8.widthHint = this.gridDataWidthHint;
        bLogin.setLayoutData(gd8);

	Label lBlank13 = new Label(formGroup, DWT.NONE);
        lBlank13.setLayoutData(gd8);

	Button bRegister = new Button(formGroup, DWT.BORDER);
	bRegister.setText(REGISTER_TEXT);
        bRegister.setLayoutData(gd8);

	// Set font for all form children.
	foreach(control; formGroup.getChildren)
	    setFont(control, FONT_SIZE_2, DWT.NONE);

	addTextListener(tUsernameL);
	addTextListener(tPasswordL);
	addTextListener(tUsernameR);
	addTextListener(tPasswordR);
	addTextListener(tPasswordRR);

	addFormListener(tPasswordL, lMsg);
	addFormListener(tPasswordRR, lMsg);

	addButtonListener(bLogin, lMsg);
	addButtonListener(bRegister, lMsg);

	// Set tab-order for login form.
	// First element cast hints type for the rest.
	formGroup.setTabList([cast(Control)tUsernameL,
			      tPasswordL,
			      bLogin,
			      tUsernameR,
			      tPasswordR,
			      tPasswordRR,
			      bRegister]);
    }


    private void setShellSize(in Shell shell)
    {
	int height = Integer.convert(getConfig("windowHeight"));
	int width = Integer.convert(getConfig("windowWidth"));

	if(0 == height)
	{
	    height = WINDOW_HEIGHT;
	    width = WINDOW_WIDTH;
	}

	Point windowSize = new Point(width, height);
	shell.setSize(windowSize);
    }


    private void addCalendarListener(DateTime calendar)
    {
	calendar.addSelectionListener(new class(calendar) SelectionAdapter
        {
	    StyledText txtPad;
	    DateTime cal;
	    Menu textMenu;
	    this(DateTime cal)
	    {
		this.txtPad = getTextPad;
		this.cal = calendar;
		this.textMenu = this.txtPad.getMenu;
	    }
	    public void widgetSelected(SelectionEvent event)
	    {
		if(this.txtPad.isDisposed) this.txtPad = getTextPad;

		markCalendarDays(this.cal);

		char[] date = Integer.toString(this.cal.getDay) ~ "-";
		date ~= Integer.toString(this.cal.getMonth + 1) ~ "-";
		date ~= Integer.toString(this.cal.getYear);

		char[] todayStr = Integer.toString(today.day) ~ "-";
		todayStr ~= Integer.toString(today.month) ~ "-";
		todayStr ~= Integer.toString(today.year);

		saveText;

		// Allow editing of today's entry only.
		if(todayStr == date)
		{
		    this.txtPad.setEditable(true);
		    this.txtPad.setMenu(getTextPad.getMenu);
		}
		else
		{
		    this.txtPad.setEditable(false);
		    this.txtPad.setMenu(null);
		}

		hideSearchChildren(this.txtPad.getParent);
		this.txtPad.setText(Storage.getText(this.cal));
		this.txtPad.setData(new Data("noteid", "-1"));
		this.txtPad.setStyleRanges(categoryRangesToStyleRanges(Storage.getCategoryRanges(this.cal)));
		this.txtPad.setFocus;
	    }
	});
    }


    private void addCalendarMenuDetectListener(DateTime calendar)
    {
	calendar.addMenuDetectListener(new class(calendar) MenuDetectListener
        {
            StyledText txtPad;
            DateTime cal;
	    this(DateTime dt)
	    {
	        this.txtPad = getTextPad;
	        this.cal = calendar;
	    }
	    public void menuDetected(MenuDetectEvent event)
	    {
		if(this.txtPad.isDisposed) this.txtPad = getTextPad;

		this.cal.setDay(1);
		this.cal.setYear(today.year);
		this.cal.setMonth(today.month - 1);
		this.cal.setDay(today.day);
		markCalendarDays(this.cal);
		hideSearchChildren(this.txtPad.getParent);
		saveText;
		this.txtPad.setText(Storage.getText);
		this.txtPad.setData(new Data("noteid", "-1"));
		this.txtPad.setEditable(true);
		this.txtPad.setStyleRanges(categoryRangesToStyleRanges(Storage.getCategoryRanges));
		this.txtPad.setFocus;
            }
        });
    }


    /*
      Let new text take on colors of immediately preceding
      or succeeding text.
    */
    private void addTextPadExtendedModifyListener(StyledText text)
    {
	text.addExtendedModifyListener(new class(text) ExtendedModifyListener
        {
	    StyledText txtPad;
	    this(StyledText t)
            {
		this.txtPad = text;
	    }

	    public void modifyText(ExtendedModifyEvent event)
            {
		StyleRange newStyle;

		// pick up style left from new text
 		if((0 < event.start) && this.txtPad.getStyleRangeAtOffset(event.start - 1))
		{
		    newStyle = this.txtPad.getStyleRangeAtOffset(event.start - 1);
		    newStyle.length += event.length;
		}

		// pick up style right from new text
 		else if((0 <= event.start) &&
			event.length < this.txtPad.getCharCount && 
			event.start + event.length < this.txtPad.getCharCount && 
			this.txtPad.getStyleRangeAtOffset(event.start + event.length))
		{
 		    newStyle = this.txtPad.getStyleRangeAtOffset(event.start + event.length);
		    newStyle.start = event.start;
		    newStyle.length += event.length;
		}
 		else
 		    return;

		this.txtPad.replaceStyleRanges(newStyle.start, newStyle.length, [newStyle]);
		Storage.setCategoryRanges(null, styleRangesToCategoryRanges(this.txtPad.getStyleRanges));
	    }
	});
    }


    /*
      Emerge small text input beneath text pad for
      incremental search in currently displayed text.
    */
    private void drawIncrementalFindInput(StyledText textPad)
    {
	Composite parent = textPad.getParent;

	// Remove previous search results.
	hideSearchChildren(parent);

	// Draw text input one line high.
	GridData gdFind = new GridData(DWT.FILL, DWT.FILL, true, true);
	Text find = new Text(parent, DWT.BORDER);
	find.setLayoutData(gdFind);
	find.setMenu(new Menu(find));
	setFont(find, FONT_SIZE_3, DWT.NONE);
	find.setFocus;
	(cast(GridData)textPad.getLayoutData).heightHint = parent.getSize.y - INCREMENTAL_SEARCH_BOX_HEIGHT;
	parent.layout;

	// Mark first match in the above text when
	// three or more characters are entered.
	find.addModifyListener(new class(find, textPad) ModifyListener
        {
	    Text fnd;
	    StyledText txtPad;
	    this(Text t, StyledText st)
	    {
		this.fnd = find;
		this.txtPad = textPad;
	    }
	    public void modifyText(ModifyEvent event)
	    {
		this.txtPad.clearSelection(false);
		if(this.fnd.getText.length < 3) return;

		char[] text = this.txtPad.getText;
		char[] keywords = this.fnd.getText;
		int location = 0;
		int[] locations;
		char[] strLocations;
		do
		{
		    location = Txt.locatePattern(Unicode.toLower(text),
						 Unicode.toLower(keywords),
						 location);
		    // Match found, temporarily store it.
		    if((0 == location) || (location < text.length))
		    {
			locations ~= location;
			strLocations ~= Integer.toString(location) ~ " ";
		    }

		    location += keywords.length;
		}while(location < text.length);

		this.fnd.setData(new Data("find", Integer.toString(keywords.length) ~ " " ~ Txt.trim(strLocations)));
		// Mark first find.
		if(0 < locations.length)
		    this.txtPad.setSelection(locations[0], locations[0] + keywords.length);
	    }
	});
	
	// Jump to next match, or previous one if SHIFT is held
	// along with ENTER key.
	find.addKeyListener(new class(find, textPad) KeyListener
        {
	    Text fnd;
	    StyledText txtPad;
	    char[] keywords;
	    this(Text t, StyledText st)
	    {
		this.fnd = find;
		this.txtPad = textPad;
	    }
	    public void keyPressed(KeyEvent event)
	    {
		// Mark next match.
		if((event.keyCode == KEY_ENTER) || (event.keyCode == KEY_KP_ENTER))
		{
		    char[] find = (cast(Data)this.fnd.getData).get("find");
		    char[][] finds = Txt.split(find, " ");

		    if(finds.length <= 2) return;
		    
		    int length = Integer.toInt(finds[0]);
		    finds = finds[1..$];

		    char[][] newFinds = rotateLeft(finds);

		    // Mark previous match.
		    if((event.stateMask == DWT.SHIFT) &&
		       (event.keyCode == KEY_ENTER || event.keyCode == KEY_KP_ENTER))
			newFinds = rotateRight(finds);

		    int start = Integer.toInt(newFinds[0]);

		    char[] strFinds;
		    foreach(f; newFinds)
			strFinds ~= f ~ " ";

		    this.fnd.setData(new Data("find", Integer.toString(length) ~ " " ~ Txt.trim(strFinds)));
		    this.txtPad.setSelection(start, start + length);
		}

		if(event.keyCode == KEY_ESC)
		{
		    auto parent = this.fnd.getParent;
		    this.fnd.dispose;
		    parent.layout;
		    this.txtPad.setFocus;
		    this.txtPad.clearSelection(false);
		}
	    }
	    public void keyReleased(KeyEvent event){}
	});
    }


    private void addTextPadKeyListener(StyledText text, DateTime cal)
    {
	text.addKeyListener(new class(text, cal) KeyListener
	{
	    StyledText txtPad;
	    DateTime calendar;
	    this(StyledText t, DateTime d)
	    {
		this.txtPad = getTextPad;
		this.calendar = cal;
	    }
	    public void keyPressed(KeyEvent event)
	    {
		// Save encrypted text to file when "CTRL + S" pressed
		if(this.txtPad.getEditable &&
		   ((event.stateMask == DWT.CTRL) && (event.keyCode == KEY_S)))
		{
		    saveText;
		    Storage.saveFinal;
		}

		// Emerge small text input beneath text pad for
		// incremental find in currently displayed text
		if((event.stateMask == DWT.CTRL) && (event.keyCode == KEY_F))
		    drawIncrementalFindInput(this.txtPad);

		// Refresh text pad content - DEBUG
		if(this.txtPad.getEditable &&
		   ((event.stateMask == DWT.CTRL) && (event.keyCode == KEY_R)))
		{
 		    this.txtPad.setText(Storage.getText);
		    this.txtPad.setData(new Data("noteid", "-1"));
 		    this.txtPad.setStyleRanges(categoryRangesToStyleRanges(Storage.getCategoryRanges));
		}
	    }
	    public void keyReleased(KeyEvent event){}
	});
    }


    /*
      Enable or disable text pad pop-up menu depending on current selection
      and style at caret offset
     */
    private void addTextPadMenuDetectListener(StyledText text)
    {
	text.addMenuDetectListener(new class(text) MenuDetectListener
	{
	    StyledText txtPad;
	    Menu txtPadMenu;
	    this(StyledText t)
	    {
		this.txtPad = text;
		this.txtPadMenu = this.txtPad.getMenu;
	    }

	    public void menuDetected(MenuDetectEvent event)
	    {
		// No tagging in notes, because there's no global search.
		if(0 <= Integer.toInt((cast(Data)txtPad.getData).get("noteid")))
		{
		    this.txtPad.setMenu(null);
		    return;
		}

		// Only today's text is editable.
		if(!this.txtPad.getEditable)
		{
		    this.txtPad.setMenu(null);
		    return;
		}

		// Caret is too far, nothing underneath anymore.
		if(this.txtPad.getCharCount <= this.txtPad.getCaretOffset)
		{
		    // Move caret one character back.
		    if(0 < this.txtPad.getCaretOffset)
		    {
			// Preserve selection.
			Point selection = this.txtPad.getSelection;
			this.txtPad.setCaretOffset(this.txtPad.getCaretOffset - 1);
			this.txtPad.setSelection(selection);
		    }
		    else
		    {
			addTimestampMenu;
			return;
		    }
		}
		
		Point selection = this.txtPad.getSelection;
		int start = selection.x;
		int length = selection.y - selection.x;

		// Selection is past character count.
		if(this.txtPad.getCharCount <= start)
		{
		    addTimestampMenu;
		    return;
		}

		// No selection and no style underneath cursor - hide menu.
		if((length <= 0) && !this.txtPad.getStyleRangeAtOffset(start))
		{
		    addTimestampMenu;
		    return;
		}

		categoryOptions;

		// No selection, but style underneath cursor - show menu.
		if((length <= 0) && this.txtPad.getStyleRangeAtOffset(start))
		{
		    this.txtPad.setMenu(this.txtPadMenu);
		    return;
		}

		// Selection overlaps with existing styles - hide menu.
 		if(0 < this.txtPad.getRanges(start, length).length)
		{
		    this.txtPad.setMenu(null);
		    return;
		}

		// Selected text is not associated with any category - show menu.
		if((0 < length) && !this.txtPad.getStyleRangeAtOffset(start))
		{
		    this.txtPad.setMenu(this.txtPadMenu);
		    return;
		}
	    }
	});
    }


    /*
      Remove category.
     */
    private void addCatNameMenuItemListener(MenuItem menuItem, Text catText)
    {
	menuItem.addSelectionListener(new class(catText) SelectionAdapter
        {
            Text catTxt;
            Composite _catEditList;
	    this(Text t)
	    {
                this.catTxt = catText;
		this._catEditList = this.catTxt.getParent;
	    }

            // Remove category and belonging checkbox.
	    public void widgetSelected(SelectionEvent event)
	    {
                int idSelected = Integer.toInt((cast(Data)this.catTxt.getData).get("id"));
                int id;
		Button b;
		foreach(Control c; this._catEditList.getChildren)
		{
		    if("Button" == c.getName)
			b = cast(Button)c;

		    if("Text" == c.getName)
		    {
                        id = Integer.toInt((cast(Data)c.getData).get("id"));
                        if(idSelected == id)
			{
			    Storage.removeCategory(idSelected);
			    b.dispose;
 			    c.dispose;

			    // Remove category from textPad's context menu.
			    static MenuOption option;
			    option.id = Integer.toString(idSelected);
			    removeMenuOption(option);
                            break;
			}
		    }
		}

                // Refresh category list.
                redrawParent(this._catEditList);
            }
        });
    }


    /*
      Show right-click / context menu for each category.
    */
    private void addCategoryNameMenuListener(Text textInput)
    {
	textInput.addMenuDetectListener(new class(textInput) MenuDetectListener
        {
	    Text catTxt;
	    this(Text t)
            {
		this.catTxt = textInput;
	    }

	    public void menuDetected(MenuDetectEvent event)
            {
                Menu menu = new Menu(this.catTxt);
                MenuItem item = new MenuItem(menu, DWT.NONE);
                item.setText(REMOVE_TEXT ~ " " ~ this.catTxt.getText);
                this.catTxt.setMenu(menu);
                addCatNameMenuItemListener(item, this.catTxt);
            }
        });
    }


    /*
      Store new category name and change it in textPad's context menu.
    */
    private void addCategoryNameModifyListener(Text textInput)
    {
	textInput.addModifyListener(new class(textInput) ModifyListener
        {
	    Text catText;
	    Menu txtPadMenu;
	    this(Text t)
            {
		this.catText = textInput;
		this.txtPadMenu = getTextPad.getMenu;
	    }

	    public void modifyText(ModifyEvent event)
            {
 		char[] id = (cast(Data)this.catText.getData).get("id");
		MenuOption[] mo;
		foreach(option; menuOptions)
		{
		    if(option.id == id)
			option.text = this.catText.getText;
		    mo ~= option;
		}
		menuOptions = mo;
		
 		Storage.renameCategory(Integer.toInt(id), this.catText.getText);
	    }
	});
    }


    private void addTextMenuListener()
    {
	Menu menu = getTextPad.getMenu;
	menu.addMenuListener(new class() MenuAdapter
        {
	    Menu txtPadMenu;
	    StyledText txtPad;
	    this()
	    {
		this.txtPad = getTextPad;
		this.txtPadMenu = this.txtPad.getMenu;
	    }
	    public void menuShown(MenuEvent event)
	    {
		if(this.txtPad.isDisposed)
		{
		    this.txtPad = getTextPad;
		    this.txtPadMenu = this.txtPad.getMenu;
		}

		Point selection = this.txtPad.getSelection;
		int start = selection.x;
		int length = selection.y - selection.x;
		int end = selection.y;

		// Nothing selected and no style on this line.
		int lineBegin = this.txtPad.getOffsetAtLine(this.txtPad.getLineAtOffset(start));
		if(this.txtPad.getCharCount <= lineBegin) return;

		static MenuOption separator1 = {id:SEPARATOR1_ID,
						style:DWT.SEPARATOR};
		static MenuOption timestamp = {id:TIMESTAMP_ID};
		timestamp.text = "(" ~ util.timestamp ~ ")";
		static MenuOption separator2 = {id:SEPARATOR2_ID,
						style:DWT.SEPARATOR};
		static MenuOption clear = {id:CLEAR_ID,
					   text:CLEAR_MENU_ITEM_TEXT};

		// Add option to remove style from paragraph.
		StyleRange style = this.txtPad.getStyleRangeAtOffset(lineBegin);
		if((length <= 0) && style)
		{
		    addMenuOption(separator1);
		    addMenuOption(timestamp);
		    addMenuOption(separator2);
		    addMenuOption(clear);
		}
		// Remove separator and option to remove style from paragraph.
		else
		{
		    removeMenuOption(separator1);
		    removeMenuOption(timestamp);
		    removeMenuOption(separator2);
		    removeMenuOption(clear);
		}
		this.txtPad.setMenu(this.txtPadMenu);
	    }
	});
    }


    private void addMenuItemListener(MenuItem menuItem)
    {
	menuItem.addSelectionListener(new class(menuItem) SelectionAdapter
        {
	    MenuItem item;
	    Menu txtPadMenu;
	    StyledText txtPad;
	    this(MenuItem mi)
	    {
		this.item = menuItem;
		this.txtPadMenu = getTextPad.getMenu;
		this.txtPad = getTextPad;
	    }

	    public void widgetSelected(SelectionEvent event)
	    {
		Data itemData = cast(Data)this.item.getData;

		if(itemData.get("id") == CLEAR_ID)
		{
		    // Set line to remove style down from.
		    int lineAtOffset = this.txtPad.getLineAtOffset(this.txtPad.getCaretOffset) + 1;
		    if((this.txtPad.getLineCount - 1) < lineAtOffset)
			lineAtOffset = this.txtPad.getLineCount - 1;

		    int titlePos = clearStyle(this.txtPad,
					      this.txtPad.getCaretLine,
					      this.txtPad.getOffsetAtLine(lineAtOffset));
		    if(-1 == titlePos) titlePos = 0;
		    
		    // Remove category names - paragraph title.
		    int length = this.txtPad.getLine(titlePos).length;
		    this.txtPad.replaceTextRange(this.txtPad.getOffsetAtLine(titlePos), length + 1, "");
		    Storage.setCategoryRanges(null, styleRangesToCategoryRanges(this.txtPad.getStyleRanges));
		    return;
		}   

		if(itemData.get("id") == TIMESTAMP_ID)
		{
		    this.txtPad.insert(this.item.getText);
		    this.txtPad.setCaretOffset(this.txtPad.getCaretOffset + this.item.getText.length);
		    return;
		}

		Point selection = this.txtPad.getSelection;

		int start = selection.x;
		int length = selection.y - selection.x;
		int end = selection.y;

		// Nothing selected and no style on this line.
		int lineBegin = this.txtPad.getOffsetAtLine(this.txtPad.getLineAtOffset(start));
		if(this.txtPad.getCharCount <= lineBegin) return;
		StyleRange style = this.txtPad.getStyleRangeAtOffset(lineBegin);
		if((length <= 0) && !style) return;

		// Style underneath cursor, but no selection.
		// Find line in bold and add selected category name.
		char[] catName = Storage.getCategoryName(Integer.toInt(itemData.get("id")));
		if(length <= 0)
		{
		    Point boldLine;
		    getBoldLine(this.txtPad, this.txtPad.getCaretLine, boldLine);
 		    if(boldLine) addCategoryName(this.txtPad, boldLine, catName);
		    Storage.setCategoryRanges(null, styleRangesToCategoryRanges(this.txtPad.getStyleRanges));
		    return;
		}

		// Does selection overlap with existing styles?
 		if(0 < this.txtPad.getRanges(start, length).length) return;

		// Background for category title(s).
		StyleRange styleTitle = new StyleRange(start,
						       catName.length,
						       null,
						       getColor(getConfig(USER_CATEGORY_BACKGROUND_COLOR_SETTING_NAME)),
						       DWT.BOLD);
		// Background for paragraph.
		StyleRange styleBody = new StyleRange(start + catName.length,
						      length + 1,
						      null,
						      getColor(getConfig(USER_CATEGORY_BACKGROUND_COLOR_SETTING_NAME)));

		// Add empty line at the end if replacement is longer than original text.
		if(this.txtPad.getCharCount < start + length + 1)
		    this.txtPad.append("\n");
		
		char[] paragraph = catName ~ "\n" ~ this.txtPad.getTextRange(start, length + 1);
		this.txtPad.replaceTextRange(start, length + 1, paragraph);
		this.txtPad.setStyleRange(styleTitle);
		this.txtPad.setStyleRange(styleBody);
		Storage.setCategoryRanges(null, styleRangesToCategoryRanges(this.txtPad.getStyleRanges));
	    }
	});
    }


    private void drawSearchResultsWindow(char[] content,
					 StyledText textPad,
					 DateTime calendar)
    {
	Composite parent = textPad.getParent;

	// Remove previous search results.
	hideSearchChildren(parent);

	GridData gdSearch = new GridData(DWT.FILL, DWT.FILL, true, true);
	uint widgetHeight = parent.getSize.y / 2;
	gdSearch.heightHint = widgetHeight;
 	ScrolledComposite sc = new ScrolledComposite(parent, DWT.V_SCROLL | DWT.H_SCROLL);
	sc.setLayoutData(gdSearch);
	Composite c = new Composite(sc, DWT.BORDER);
	c.setLayout(new GridLayout(1, false));
	GridData gdLink = new GridData(DWT.FILL, DWT.FILL, true, true);
	Link link = new Link(c, DWT.NONE);

	// Append CLOSE link at the top.
	content = "<a>CLOSE</a>\n\n" ~ content;

	// Adjust container height.
	uint contentHeight = SEARCH_RESULTS_LINE_HEIGHT * Txt.count(content, "\n");
	gdLink.heightHint = contentHeight;

	// Append CLOSE link at the bottom when content exceeds widget boundaries.
	if(widgetHeight < contentHeight)
	    content ~= "\n\n<a>CLOSE</a>";

	link.setLayoutData(gdLink);
	link.setText(toUtf8(content));

        redrawParent(c, true);

	// Adjust height of text pad above.
	(cast(GridData)textPad.getLayoutData).heightHint = parent.getSize.y / 2;
	parent.layout(true);

	link.addSelectionListener(new class(parent, sc, link, calendar) SelectionAdapter
        {
	    Composite _parent;
	    ScrolledComposite scrolled;
	    Link lnk;
	    DateTime cal;
	    this(Composite c, ScrolledComposite s, Link l, DateTime dt)
	    {
		this._parent = parent;
		this.scrolled = sc;
		this.lnk = link;
		this.cal = calendar;
	    }
	    public void widgetSelected(SelectionEvent event)
	    {
		// Close "Search results" window.
		if("CLOSE" == event.text)
		{
		    this.scrolled.dispose;
		    this._parent.layout;
		}

		// Load requested page.
		if("PAGE" == event.text[0..4])
		{
		    char[] content = Storage.getSearchResultPage(Integer.toInt(event.text[4..$]));
		    content = "<a>CLOSE</a>\n\n" ~ content;
		    content ~= "\n\n<a>CLOSE</a>";

		    // Adjust container height.
		    (cast(GridData)this.lnk.getLayoutData).heightHint = SEARCH_RESULTS_LINE_HEIGHT * Txt.count(content, "\n");
		    this.scrolled.setMinSize((cast(Composite)this.scrolled.getChildren[0]).computeSize(DWT.DEFAULT, DWT.DEFAULT));
		    this.lnk.setText(content);
		}

		StyledText txtPad;
		foreach(control; this._parent.getChildren)
		{
		    if("StyledText" == control.getName)
			txtPad = cast(StyledText)control;
		}

		// Load text associated with clicked link
		// into window above, scroll to the first appearance
		// of given keywords and highlight the keywords.
		if("JUMP" == event.text[0..4])
		{
		    char[] dayName = event.text[4..12];
		    Date date = dateStrToDate(dayName);

		    saveText;

		    if(getTodayFileName == dayName) txtPad.setEditable(true);
		    else txtPad.setEditable(false);

		    this.cal.setYear(date.year);
		    this.cal.setMonth(date.month - 1);
		    this.cal.setDay(date.day);
		    markCalendarDays(this.cal);

		    txtPad.setText(Storage.getText(this.cal));
		    txtPad.setData(new Data("noteid", "-1"));
		    txtPad.setStyleRanges(categoryRangesToStyleRanges(Storage.getCategoryRanges(this.cal)));

		    // Highlight matching keywords and scroll to view.
  		    int start = Integer.toInt(Txt.split(event.text[12..$], "-")[0]);
  		    int end = start + Txt.split(event.text[12..$], "-")[1].length;
		    txtPad.setSelection(start, end);
		}
	    }
	});
    }


    private void addTextSearchKeyListener(Composite rightComposite,
					  Text textSearch,
					  Composite catEditList,
					  DateTime calendar)
    {
	textSearch.addKeyListener(new class(rightComposite,
					    textSearch,
					    catEditList,
					    calendar) KeyListener
	{
	    Composite _rightComposite;
	    Text txtSearch;
	    StyledText txtPad;
	    Composite catList;
	    DateTime cal;
	    this(Composite c, Text t, Composite cl, DateTime dt)
	    {
		this._rightComposite = rightComposite;
		this.txtSearch = textSearch;
		this.txtPad = getTextPad;
		this.catList = catEditList;
		this.cal = calendar;
	    }
	    public void keyPressed(KeyEvent event)
	    {
		if(this.txtPad.isDisposed) this.txtPad = getTextPad;

		if((event.keyCode == KEY_ENTER) || (event.keyCode == KEY_KP_ENTER))
		{
		    // Save current text so it becomes searchable,
		    // and cannot be overwritten when jump to search result is made.
		    saveText;

		    char[] searchResults;
		    // Get the first search result page.
		    if(0 == (searchResults = Storage.search(this.txtSearch.getText,
							    getSelectedCategories(this.catList))).length)
			searchResults = Storage.getSearchResultPage;

		    drawSearchResultsWindow(searchResults, this.txtPad, this.cal);
		}
	    }
	    public void keyReleased(KeyEvent event){}
	});
    }


    /*
      Store note name when modified.
     */
    private void addNoteNameModifyListener(Text textInput)
    {
	textInput.addModifyListener(new class(textInput) ModifyListener
        {
	    Text noteText;
	    this(Text t)
            {
		this.noteText = textInput;
	    }

	    public void modifyText(ModifyEvent event)
            {
		int id = Integer.toInt((cast(Data)this.noteText.getData).get("id"));
		Storage.noteName(id, this.noteText.getText);
	    }
	});
    }


    /*
      Store current text when focused on note.
     */
    private void addNoteMouseListener(Text noteText)
    {
	noteText.addMouseListener(new class(noteText) MouseAdapter
        {
	    Text noteTxt;
	    StyledText txtPad;
	    this(Text t)
            {
		this.noteTxt = noteText;
		this.txtPad = getTextPad;
	    }
	    public void mouseDown(MouseEvent event)
	    {
		if(this.txtPad.isDisposed) this.txtPad = getTextPad;

		hideSearchChildren(this.txtPad.getParent);
		saveText;
		char[] noteID = (cast(Data)this.noteTxt.getData).get("id");
		this.txtPad.setText(Storage.noteContent(Integer.toInt(noteID)));

		// Set note ID in text pad to real note ID so note is saved
		// next time saveText is called.
		this.txtPad.setData(new Data("noteid", (noteID)));
		this.txtPad.setEditable(true);
	    }
	});
    }


    /*
      Draw text pad on the right and return it.
    */
    private StyledText drawTextPad(Composite rightComposite)
    {
	GridData rightData = new GridData(DWT.FILL, DWT.FILL, true, true);
	StyledText textPad = new StyledText(rightComposite,
					    DWT.BORDER | DWT.MULTI | DWT.H_SCROLL | DWT.V_SCROLL);
	textPad.setFocus;
	setFont(textPad, FONT_SIZE_1, DWT.NONE);
	textPad.setText(Storage.getText);
	textPad.setData(new Data("noteid", "-1"));
	textPad.setStyleRanges(categoryRangesToStyleRanges(Storage.getCategoryRanges));
	textPad.setLayoutData(rightData);
	textPad.setKeyBinding(DWT.MOD1 + 'A', ST.SELECT_ALL);
	textPad.setScrollBarVisible(textPad.getVerticalBar, false);
	textPad.setScrollBarVisible(textPad.getHorizontalBar, false);
	return textPad;
    }


    /*
      Return text pad.
    */
    private StyledText getTextPad()
    {
	foreach(child; getShellGroup(RIGHT_GROUP).getChildren)
	    if("StyledText" == child.getName)
	    {
		this.tp = cast(StyledText)child;
		break;
	    }

	DateTime calendar;
	foreach(child; getShellGroup(LEFT_GROUP).getChildren)
	{
	    if("DateTime" == child.getName) calendar = cast(DateTime)child;
	    break;
	}

	if(!this.tp || (this.tp && this.tp.isDisposed))
	{
	    this.tp = drawTextPad(getShellGroup(RIGHT_GROUP));
	    this.tp.setMenu(new Menu(this.tp));
	    updateMenu;
	    addTextPadListeners(this.tp, calendar);
	}

	return this.tp;
    }


    /*
      Draw text input for global search.
    */
    private Text drawSearchInput(Composite composite, StyledText textPad)
    {
	GridData gdSearch = new GridData(MAIN_WINDOW_LEFT_COLUMN_WIDTH - 8, DWT.DEFAULT);
	Text textSearch = new Text(composite, DWT.DEFAULT);
	setFont(textSearch, FONT_SIZE_3, DWT.ITALIC);
	textSearch.setText(SEARCH_BOX_TEXT);
	textSearch.setForeground(new Color(Display.getCurrent, 191, 191, 191));
	textSearch.setLayoutData(gdSearch);
	textSearch.setEditable(true);
	textSearch.setData(new Data("used", "0"));
	textSearch.setMenu(new Menu(textSearch));

	textSearch.addFocusListener(new class(textSearch, textPad) FocusListener
        {
	    Text txtSearch;
	    StyledText txtPad;
	    this(Text t, StyledText st)
	    {
		this.txtSearch = textSearch;
		this.txtPad = textPad;
	    }
	    // remove "Search..." text on first focus
	    public void focusGained(FocusEvent event)
	    {
		if("0" == (cast(Data)this.txtSearch.getData).get("used"))
		{
		    this.txtSearch.setText("");
		    setFont(this.txtSearch, FONT_SIZE_3, DWT.NONE);
		    this.txtSearch.setForeground(new Color(Display.getCurrent, 0, 0, 0));
		}
		this.txtSearch.setData(new Data("used", "1"));
	    }
	    public void focusLost(FocusEvent event){}
	});

	return textSearch;
    }


    /*
      Toggle checkboxes in category list.
     */
    private void addCategoryCheckListener(Button catCheck, Composite catEditList)
    {
	catCheck.addSelectionListener(new class(catCheck, catEditList) SelectionAdapter
	{
	    Button _catCheck;
	    Composite _catEditList;
	    this(Button b, Composite c)
	    {
		this._catCheck = catCheck;
		this._catEditList = catEditList;
	    }
	    public void widgetSelected(SelectionEvent event)
	    {
		foreach(Control c; this._catEditList.getChildren)
		{
		    if("Button" == c.getName)
		    {
			Button b = cast(Button)c;
			if(this._catCheck.getSelection)
			    b.setSelection = true;
			else
			    b.setSelection = false;
		    }
		}
	    }
	});	
    }


    /*
      Add new category.
     */
    private void addCatMenuDetectListener(Button catCheck, Composite catEditList)
    {
	catCheck.addMenuDetectListener(new class(catCheck, catEditList) MenuDetectListener
	{
	    Button _catCheck;
	    Composite _catEditList;
	    this(Button b, Composite c)
	    {
		this._catCheck = catCheck;
		this._catEditList = catEditList;
	    }
	    public void menuDetected(MenuDetectEvent event)
	    {
                // ID of new category.
                char[] id = Integer.toString(Storage.addCategory(CATEGORY_TEXT));
                char[] name = CATEGORY_TEXT ~ " " ~ Integer.toString(Integer.toInt(id) + 1);

                GridData gdCheck = new GridData(CATEGORY_CHECKBOX_WIDTH, DWT.DEFAULT);
                Button catCheck = new Button(this._catEditList, DWT.CHECK);
                catCheck.setData(new Data("id", id));
                catCheck.setLayoutData(gdCheck);
                catCheck.setSelection(true);

                GridData gdText = new GridData(CATEGORY_NAME_WIDTH, DWT.DEFAULT);
                Text catText = new Text(this._catEditList, DWT.NONE);
                setFont(catText, FONT_SIZE_1, DWT.NONE);
                catText.setData(new Data("id", id));
                catText.setText(name);
                catText.setLayoutData(gdText);
                catText.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
                // Prevent default menu.
                catText.setMenu(new Menu(catText));
                addCategoryNameModifyListener(catText);
                addCategoryNameMenuListener(catText);

                // Add category to textPad's context menu.
                // 0 puts menu item on top of menu.
                static MenuOption option = {index:0};
                option.text = name;
                option.id = id;
                addMenuOption(option);

                // Refresh category list.
                redrawParent(this._catEditList);
            }
        });
    }


    /*
      Populate category list with category names.
     */
    private void fillCategoryList(Composite catEditList, StyledText textPad)
    {
	Menu textPadMenu = textPad.getMenu;

	char[][] category;
	while(null !is (category = Storage.getCategory))
	{
	    char[] id = category[0];
	    char[] name = category[1];

	    GridData gdCatCheck = new GridData(CATEGORY_CHECKBOX_WIDTH, DWT.DEFAULT);
	    Button catChk = new Button(catEditList, DWT.CHECK);
	    catChk.setData(new Data("id", id));
	    catChk.setLayoutData(gdCatCheck);
	    catChk.setSelection(true);

	    GridData gdCatName = new GridData(CATEGORY_NAME_WIDTH, DWT.DEFAULT);
	    Text catText = new Text(catEditList, DWT.NONE);
	    setFont(catText, FONT_SIZE_1, DWT.NONE);
	    catText.setLayoutData(gdCatName);
	    catText.setData(new Data("id", id));
	    catText.setText(name);
	    catText.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
	    // Prevent default menu.
	    catText.setMenu(new Menu(catText));
	    addCategoryNameModifyListener(catText);
            addCategoryNameMenuListener(catText);

	    // Add category to textPad's context menu.
	    static MenuOption catItem;
	    catItem.id = id;
	    catItem.text = name;
	    addMenuOption(catItem);
 	}

        redrawParent(catEditList, true);
    }

    /*
      Draw category list.
    */
    private Composite drawCategoryList(Composite composite, StyledText textPad)
    {
	Composite catEditGroup = new Composite(composite, DWT.NONE);
	catEditGroup.setLayout(new GridLayout(2, false));

	GridData gdCat1 = new GridData(CATEGORY_LABEL_WIDTH, DWT.DEFAULT);
	Button catCheck = new Button(catEditGroup, DWT.CHECK);
	catCheck.setLayoutData(gdCat1);
	setFont(catCheck, FONT_SIZE_1, DWT.BOLD);
	catCheck.setSelection(true);
        catCheck.setText(CATEGORIES_TEXT);

	Composite c = new Composite(composite, DWT.NONE);
	c.setLayout(new FillLayout(DWT.VERTICAL));
	GridData gdc = new GridData(DWT.LEFT, DWT.TOP, true, true);
	gdc.widthHint = MAIN_WINDOW_LEFT_COLUMN_WIDTH;
	gdc.heightHint = CATEGORY_LIST_HEIGHT;
	c.setLayoutData(gdc);
	ScrolledComposite sc = new ScrolledComposite(c, DWT.V_SCROLL);
	Composite catEditList = new Composite(sc, DWT.NONE);
	catEditList.setLayout(new GridLayout(2, false));

	Menu textPadMenu = textPad.getMenu;

	// Populate category list box with saved user categories.
	fillCategoryList(catEditList, textPad);

	// Check or uncheck all categories.
	addCategoryCheckListener(catCheck, catEditList);

        // Menu for adding categories.
	addCatMenuDetectListener(catCheck, catEditList);

	return catEditList;
    }


    /*
      Populate note list.
     */
    private void fillNoteList(Composite noteEditList, StyledText textPad)
    {
	foreach(id, name; Storage.getNotes)
	{
	    GridData gdNoteName = new GridData(CATEGORY_NAME_WIDTH, DWT.DEFAULT);
	    Text noteText = new Text(noteEditList, DWT.NONE);
	    setFont(noteText, FONT_SIZE_1, DWT.NONE);
	    noteText.setLayoutData(gdNoteName);
	    noteText.setData(new Data("id", Integer.toString(id)));
	    noteText.setText(name);
	    noteText.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
	    // Prevent default menu.
	    noteText.setMenu(new Menu(noteText));
	    addNoteNameModifyListener(noteText);
	    addNoteMouseListener(noteText);
            addNoteNameMenuListener(noteText);
	}

        redrawParent(noteEditList, true);
    }


    /*
      Remove notes.
     */
    private void addNoteNameMenuItemListener(MenuItem menuItem, Text noteText)
    {
	menuItem.addSelectionListener(new class(noteText) SelectionAdapter
        {
            Text noteTxt;
            Composite _noteEditList;
	    this(Text t)
	    {
                this.noteTxt = noteText;
		this._noteEditList = this.noteTxt.getParent;
	    }

	    public void widgetSelected(SelectionEvent event)
	    {
                int idSelected = Integer.toInt((cast(Data)this.noteTxt.getData).get("id"));
                int id;
		foreach(Control c; this._noteEditList.getChildren)
		{
		    if("Text" == c.getName)
		    {
                        id = Integer.toInt((cast(Data)c.getData).get("id"));
                        if(idSelected == id)
			{
			    id = Integer.toInt((cast(Data)c.getData).get("id"));
			    Storage.removeNote(id);
 			    c.dispose;
                            // Clean up right side.
			    foreach(child; getShellGroup(RIGHT_GROUP).getChildren)
				child.dispose;
			}
		    }
		}

                // Refresh note list.
                redrawParent(this._noteEditList);
            }
        });
    }


    /*
      Show right-click / context menu for each note.
    */
    private void addNoteNameMenuListener(Text textInput)
    {
	textInput.addMenuDetectListener(new class(textInput) MenuDetectListener
        {
	    Text noteTxt;
	    this(Text t)
            {
		this.noteTxt = textInput;
	    }

	    public void menuDetected(MenuDetectEvent event)
            {
                Menu menu = new Menu(this.noteTxt);
                MenuItem item = new MenuItem(menu, DWT.NONE);
                item.setText(REMOVE_TEXT ~ " " ~ this.noteTxt.getText);
                this.noteTxt.setMenu(menu);
                addNoteNameMenuItemListener(item, this.noteTxt);
            }
        });
    }


    /*
      Add new note.
     */
    private void addNoteMenuDetectListener(Label lNotes, Composite noteEditList)
    {
	lNotes.addMenuDetectListener(new class(lNotes, noteEditList) MenuDetectListener
	{
            Label _lNotes;
            Composite _noteEditList;
	    this(Label l, Composite c)
	    {
                this._lNotes = lNotes;
		this._noteEditList = noteEditList;
	    }
	    public void menuDetected(MenuDetectEvent event)
	    {
                char[] id = Integer.toString(Storage.addNote);
                char[] name = NOTES_TEXT ~ " " ~ Integer.toString(Integer.toInt(id) + 1);

                GridData gdText = new GridData(CATEGORY_NAME_WIDTH, DWT.DEFAULT);
                Text noteText = new Text(this._noteEditList, DWT.NONE);
                setFont(noteText, FONT_SIZE_1, DWT.NONE);
                noteText.setData(new Data("id", id));
                noteText.setText(name);
                noteText.setLayoutData(gdText);
                noteText.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
                // Prevent default menu.
                noteText.setMenu(new Menu(noteText));
                Storage.noteContent(Integer.toInt(id), name);
                addNoteNameModifyListener(noteText);
                addNoteMouseListener(noteText);
                addNoteNameMenuListener(noteText);

                // Refresh note list.
                redrawParent(this._noteEditList);
            }
        });
    }


    /*
      Draw note list.
    */
    private void drawNoteList(Composite composite, StyledText textPad)
    {
	Composite notesEditGroup = new Composite(composite, DWT.NONE);
	notesEditGroup.setLayout(new GridLayout(2, false));

	GridData gdNote1 = new GridData(CATEGORY_LABEL_WIDTH, DWT.DEFAULT);
	Label lNotes = new Label(notesEditGroup, DWT.NONE);
	lNotes.setLayoutData(gdNote1);
	setFont(lNotes, FONT_SIZE_1, DWT.BOLD);
        lNotes.setText(NOTES_TEXT);

	Composite n = new Composite(composite, DWT.NONE);
	n.setLayout(new FillLayout(DWT.VERTICAL));
	GridData gdn = new GridData(DWT.LEFT, DWT.TOP, true, true);
	gdn.widthHint = MAIN_WINDOW_LEFT_COLUMN_WIDTH;
	gdn.heightHint = CATEGORY_LIST_HEIGHT;
	n.setLayoutData(gdn);

	ScrolledComposite scn = new ScrolledComposite(n, DWT.V_SCROLL);
	Composite noteEditList = new Composite(scn, DWT.NONE);
	noteEditList.setLayout(new GridLayout(1, false));

	// Populate note list box with saved user notes.
	fillNoteList(noteEditList, textPad);

	// Menu for adding notes.
	addNoteMenuDetectListener(lNotes, noteEditList);
    }


    /*
      Store chain name when modified.
     */
    private void addChainNameModifyListener(Text textInput)
    {
	textInput.addModifyListener(new class(textInput) ModifyListener
        {
	    Text chainText;
	    this(Text t)
            {
		this.chainText = textInput;
	    }

	    public void modifyText(ModifyEvent event)
            {
		int id = Integer.toInt((cast(Data)this.chainText.getData).get("id"));
		Storage.chainName(id, this.chainText.getText);
	    }
	});
    }


    /*
      Draw chain user has focused on.
     */
    private void addChainMouseListener(Text chainText)
    {
	chainText.addMouseListener(new class(chainText) MouseAdapter
        {
	    Text chainTxt;
	    this(Text t)
	    {
		this.chainTxt = chainText;
	    }
	    public void mouseDown(MouseEvent event)
	    {
		saveText;
		drawChainWindow(Integer.toInt((cast(Data)this.chainTxt.getData).get("id")));
	    }
	    // Canvas seems to steal focus.
	    public void mouseUp(MouseEvent event)
	    {
		    this.chainTxt.setFocus;
	    }
	});
    }


    /*
      Populate chain list.
     */
    private void fillChainList(Composite chainEditList)
    {
	foreach(id, name; Storage.getChains)
	{
	    GridData gdChainName = new GridData(CATEGORY_NAME_WIDTH, DWT.DEFAULT);
	    Text chainText = new Text(chainEditList, DWT.NONE);
	    setFont(chainText, FONT_SIZE_1, DWT.NONE);
	    chainText.setLayoutData(gdChainName);
	    chainText.setData(new Data("id", Integer.toString(id)));
	    chainText.setText(name);
	    chainText.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
	    // Prevent default menu.
	    chainText.setMenu(new Menu(chainText));
 	    addChainNameModifyListener(chainText);
 	    addChainMouseListener(chainText);
            addChainNameMenuListener(chainText);
	}

        redrawParent(chainEditList, true);
    }



    /*
      Remove chain.
     */
    private void addChainNameMenuItemListener(MenuItem menuItem, Text chainText)
    {
	menuItem.addSelectionListener(new class(chainText) SelectionAdapter
        {
            Text chainTxt;
            Composite _chainEditList;
	    this(Text t)
	    {
                this.chainTxt = chainText;
		this._chainEditList = this.chainTxt.getParent;
	    }

	    public void widgetSelected(SelectionEvent event)
	    {
                int idSelected = Integer.toInt((cast(Data)this.chainTxt.getData).get("id"));
                int id;
		foreach(Control c; this._chainEditList.getChildren)
		{
		    if("Text" == c.getName)
		    {
                        id = Integer.toInt((cast(Data)c.getData).get("id"));
                        if(idSelected == id)
			{
			    id = Integer.toInt((cast(Data)c.getData).get("id"));
			    Storage.removeChain(id);
 			    c.dispose;
                            // Clean up right side.
			    foreach(child; getShellGroup(RIGHT_GROUP).getChildren)
				child.dispose;
			}
		    }
		}

                // Refresh chain list.
                redrawParent(this._chainEditList);
            }
        });
    }


    /*
      Show right-click / context menu for each chain.
    */
    private void addChainNameMenuListener(Text textInput)
    {
	textInput.addMenuDetectListener(new class(textInput) MenuDetectListener
        {
	    Text chainTxt;
	    this(Text t)
            {
		this.chainTxt = textInput;
	    }

	    public void menuDetected(MenuDetectEvent event)
            {
                Menu menu = new Menu(this.chainTxt);
                MenuItem item = new MenuItem(menu, DWT.NONE);
                item.setText(REMOVE_TEXT ~ " " ~ this.chainTxt.getText);
                this.chainTxt.setMenu(menu);
                addChainNameMenuItemListener(item, this.chainTxt);
            }
        });
    }


    /*
      Add new chain.
     */
    private void addChainMenuDetectListener(Label lChains, Composite chainEditList)
    {
	lChains.addMenuDetectListener(new class(lChains, chainEditList) MenuDetectListener
	{
            Label _lChains;
            Composite _chainEditList;
	    this(Label l, Composite c)
	    {
                this._lChains = lChains;
		this._chainEditList = chainEditList;
	    }
	    public void menuDetected(MenuDetectEvent event)
	    {
                int id = Storage.addChain;
                char[] name = CHAIN_TEXT ~ " " ~ Integer.toString(id + 1);
                Storage.chainDesc(id, name);

                GridData gdText = new GridData(CATEGORY_NAME_WIDTH, DWT.DEFAULT);
                Text chainText = new Text(this._chainEditList, DWT.NONE);
                setFont(chainText, FONT_SIZE_1, DWT.NONE);
                chainText.setData(new Data("id", Integer.toString(id)));
                chainText.setText(name);
                chainText.setLayoutData(gdText);
                chainText.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
                // Prevent default menu.
                chainText.setMenu(new Menu(chainText));
                addChainNameModifyListener(chainText);
                addChainMouseListener(chainText);
                addChainNameMenuListener(chainText);

                // Refresh chain list.
                redrawParent(this._chainEditList);
            }
        });
    }


    /*
      Draw chain list.
     */
    private void drawChainList(Composite composite)
    {
	Composite chainsEditGroup = new Composite(composite, DWT.NONE);
	chainsEditGroup.setLayout(new GridLayout(2, false));

	GridData gdChain1 = new GridData(CATEGORY_LABEL_WIDTH, DWT.DEFAULT);
	Label lChains = new Label(chainsEditGroup, DWT.NONE);
	lChains.setLayoutData(gdChain1);
	setFont(lChains, FONT_SIZE_1, DWT.BOLD);
        lChains.setText(CHAIN_TITLE_TEXT);

	Composite c = new Composite(composite, DWT.NONE);
	c.setLayout(new FillLayout(DWT.VERTICAL));
	GridData gdc = new GridData(DWT.LEFT, DWT.TOP, true, true);
	gdc.widthHint = MAIN_WINDOW_LEFT_COLUMN_WIDTH;
	gdc.heightHint = CATEGORY_LIST_HEIGHT;
	c.setLayoutData(gdc);

	ScrolledComposite scc = new ScrolledComposite(c, DWT.V_SCROLL);
	Composite chainEditList = new Composite(scc, DWT.NONE);
	chainEditList.setLayout(new GridLayout(1, false));

	// Populate chain list box with saved user chains.
	fillChainList(chainEditList);

	// Menu for adding chains.
	addChainMenuDetectListener(lChains, chainEditList);
    }


    /*
      Wrapper for text pad listeners.
     */
    private void addTextPadListeners(StyledText textPad, DateTime calendar)
    {
	addTextPadExtendedModifyListener(textPad);
	addTextPadKeyListener(textPad, calendar);
	addTextPadMenuDetectListener(textPad);
	addTextMenuListener;
    }


    private void drawMainWindow(in Shell shell)
    {
	// Remove elements from login/registration form.
	foreach(child; shell.getChildren)
		child.dispose;

	GridLayout layout = new GridLayout(2, false);
        shell.setLayout(layout);

	// Left column.
	GridData leftCol = new GridData(DWT.FILL, DWT.FILL, false, true);
	GridLayout leftLayout = new GridLayout(1, false);

	// Left group.
	Composite leftComposite = new Composite(shell, DWT.NONE);
	leftComposite.setLayout(leftLayout);
	leftComposite.setLayoutData(leftCol);
	leftComposite.setData(new Data("name", LEFT_GROUP));

	// Right column.
	GridData rightCol = new GridData(DWT.FILL, DWT.FILL, true, true);
	GridLayout rightLayout = new GridLayout(1, false);

	// Right group.
	Composite rightComposite = new Composite(shell, DWT.NONE);
	rightComposite.setLayout(rightLayout);
	rightComposite.setLayoutData(rightCol);
	rightComposite.setData(new Data("name", RIGHT_GROUP));

	// Calendar.
        GridData calendarData = new GridData(MAIN_WINDOW_LEFT_COLUMN_WIDTH, DWT.DEFAULT);
	DateTime calendar = new DateTime(leftComposite, DWT.CALENDAR);
        calendarData.verticalAlignment = DWT.TOP;
	calendarData.heightHint = MAIN_WINDOW_CALENDAR_HEIGHT;
        calendar.setLayoutData(calendarData);
	markCalendarDays(calendar);

	// Big text field on the right.
	StyledText textPad = drawTextPad(rightComposite);

	// Right-click / context menu for text area.
	textPad.setMenu(new Menu(textPad));

	// Search field.
	Text textSearch = drawSearchInput(leftComposite, textPad);

	// Category list.
	Composite catEditList = drawCategoryList(leftComposite, textPad);

	// Note list.
	drawNoteList(leftComposite, textPad);

	// Chain list.
	drawChainList(leftComposite);
	
	// Close button.
	GridData gdButtonExit = new GridData(MAIN_WINDOW_LEFT_COLUMN_WIDTH, DWT.BOTTOM);
	Button bExit = new Button(leftComposite, DWT.BORDER);
        gdButtonExit.verticalAlignment = DWT.CENTER;
	gdButtonExit.heightHint = MAIN_WINDOW_LEFT_COLUMN_BUTTON_HEIGHT;
	setFont(bExit, FONT_SIZE_3, DWT.BOLD);
	bExit.setText(SAVE_CLOSE_TEXT);
        bExit.setLayoutData(gdButtonExit);

	bExit.addListener(DWT.Selection, new class(shell, bExit) Listener
	{
	    Shell shell;
	    Button btnExit;
	    this(Shell shell, Button button)
	    {
		this.shell = shell;
		this.btnExit = bExit;
	    }
	    public void handleEvent(Event event)
	    {
		if(event.widget is this.btnExit)
		{
		    saveText;
		    Storage.saveFinal;
		    this.shell.close;
		}
	    }
	});

	addCalendarListener(calendar);
	addCalendarMenuDetectListener(calendar);
	addTextPadListeners(textPad, calendar);
	addTextSearchKeyListener(rightComposite, textSearch, catEditList, calendar);

	setShellSize(shell);
	shell.layout;
    }


    public void draw()
    {
	setShellSize(this.shell);
	addShellListener(this.shell);

	this.shell.open;

	while(!this.shell.isDisposed)
	{
	    if(!this.display.readAndDispatch)
		this.display.sleep;
	}

	this.display.dispose;
    }
}