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

module gui;

import dwt.DWT;
import dwt.graphics.Rectangle;
import dwt.graphics.Font;
import dwt.graphics.FontData;
import dwt.graphics.Color;
import dwt.graphics.TextLayout;
import dwt.layout.FillLayout;
import dwt.layout.GridData;
import dwt.layout.GridLayout;
import dwt.widgets.Button;
import dwt.widgets.Composite;
import dwt.custom.ScrolledComposite;
import dwt.widgets.Control;
import dwt.widgets.Display;
import dwt.widgets.Group;
import dwt.widgets.Shell;
import dwt.widgets.Decorations;
import dwt.widgets.Text;
import dwt.custom.StyledText;
import dwt.custom.ST;
import dwt.custom.StyleRange;
import dwt.widgets.Button;
import dwt.widgets.Label;
import dwt.widgets.Event;
import dwt.widgets.Listener;
import dwt.widgets.DateTime;
import dwt.widgets.Menu;
import dwt.widgets.MenuItem;
import dwt.widgets.Link;
import dwt.events.ShellAdapter;
import dwt.events.SelectionAdapter;
import dwt.events.MenuAdapter;
import dwt.events.SelectionEvent;
import dwt.events.ShellEvent;
import dwt.events.ModifyListener;
import dwt.events.MenuDetectListener;
import dwt.events.MenuDetectEvent;
import dwt.custom.ExtendedModifyEvent;
import dwt.custom.ExtendedModifyListener;
import dwt.events.MenuListener;
import dwt.events.KeyListener;
import dwt.events.KeyEvent;
import dwt.events.MenuEvent;
import dwt.events.FocusListener;
import dwt.events.FocusEvent;

import Integer = tango.text.convert.Integer;
import Clock = tango.time.Clock;
import tango.io.Stdout;
import tango.core.Exception;
import tango.core.Array;
import Txt = tango.text.Util;
import tango.time.chrono.Gregorian;

import config;
import util;
import io;
import auth;
import storage;


/*
  Class for per-widget data
 */
private class Data
{
    private char[][char[]] values;
    private Object[char[]] objects;

    this(char[] key, char[] value)
    {
	this.values[key] = value;
    }

    private char[] get(char[] key)
    {
 	if(key in this.values)
 	    return this.values[key];

	return "";
    }
}

public class GUI
{
    private Shell shell;
    private Display display;
    private int gridDataMarginHeight;
    private int gridDataMarginWidth;
    private int gridDataWidthHint;

    private char errorMsg[];

    static private char[][char[]] authValues;

    private const char[] SEPARATOR_ID = "-1";
    private const char[] CLEAR_ID = "-2";


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


    private Color getColor(char[] colorSetting)
    {
	int[] colors;
	auto settings = Txt.split(colorSetting, " ");
	if(3 != settings.length)
	    settings = Txt.split(USER_CATEGORY_BACKGROUND_COLOR, " ");

	foreach(setting; settings)
	    colors ~= Integer.convert(setting);

	return new Color(Display.getCurrent,
			 colors[0],
			 colors[1],
			 colors[2]);
    }


    /*
      Set control font
     */
    private void setFont(Control control, int size, int style)
    {
	Font font = new Font(Display.getCurrent, new FontData(FONT_FACE_1,
							      size,
							      style));
	control.setFont(font);
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
      Add category name catName to line
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
      Embolden calendar days containing text
      Unmark all the rest
     */
    private void markCalendarDays(DateTime calendar)
    {
	Gregorian gc = new Gregorian;
	int maxDays = gc.getDaysInMonth(calendar.getYear,
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

    private void saveText(StyledText txtPad)
    {
	int id = Integer.toInt((cast(Data)txtPad.getData).get("noteid"));
	// Invalid note ID indicates day text, so we save to today's day.
	if(-1 == id)
	{
	    if(!txtPad.getEditable) return;
	    Stdout("SAVING TEXT", id).newline;
	    Storage.saveText(txtPad.getText);
	    Stdout("RANGES", styleRangesToCategoryRanges(txtPad.getStyleRanges)).newline;
	    Storage.setCategoryRanges(null, styleRangesToCategoryRanges(txtPad.getStyleRanges));
	}
	else if(0 <= id)
	{
	    Stdout("SAVING NOTE", id, Storage.noteName(id)).newline;
	    Storage.noteContent(id, txtPad.getText);
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
		    if(contains(this.outer.authValues.keys, "usernameL") &&
		       contains(this.outer.authValues.keys, "passwordL"))
	            {
			char[][] userData = [this.outer.authValues["usernameL"],
					     this.outer.authValues["passwordL"]];
			char[] errorMsg;
			if(Auth.login(userData, errorMsg))
			    drawMainWindow(this.newShell);
			else
			    msgLabel.setText(errorMsg);
		    }
		    break;

                    case "Register":
		    if(contains(this.outer.authValues.keys, "usernameR") &&
		       contains(this.outer.authValues.keys, "passwordR") &&
		       contains(this.outer.authValues.keys, "passwordRR"))
	            {
			char[][] userData = [this.outer.authValues["usernameR"],
					     this.outer.authValues["passwordR"],
					     this.outer.authValues["passwordRR"]];
			char[] errorMsg;
			if(Auth.register(userData, errorMsg))
			    drawMainWindow(this.newShell);
			else
			    msgLabel.setText(errorMsg);
		    }
		    else
			msgLabel.setText("I don't have enough data for registration.\nPlease enter username and matching passwords.");
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
	setFont(cast(Control)lMsg, FONT_SIZE_4, DWT.BOLD);
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
	// prevent default menu
	tUsernameL.setMenu(new Menu(tUsernameL));
	tUsernameL.setData(new Data("name", "usernameL"));

	Label lBlank2 = new Label(formGroup, DWT.NONE);
        lBlank2.setLayoutData (gd2);

	Text tUsernameR = new Text(formGroup, DWT.BORDER);
	gd2.widthHint = this.gridDataWidthHint;
        tUsernameR.setLayoutData(gd2);
	// prevent default menu
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
	// prevent default menu
	tPasswordL.setMenu(new Menu(tPasswordL));
	tPasswordL.setData(new Data("name", "passwordL"));

	Label lBlank4 = new Label(formGroup, DWT.NONE);
        lBlank4.setLayoutData(gd4);

	Text tPasswordR = new Text(formGroup, DWT.BORDER | DWT.PASSWORD);
	gd4.widthHint = this.gridDataWidthHint;
        tPasswordR.setLayoutData(gd4);
	// prevent default menu
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
	// prevent default menu
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

	// set font for all form children
	foreach(control; formGroup.getChildren)
	    setFont(control, FONT_SIZE_2, DWT.NONE);

	addTextListener(tUsernameL);
	addTextListener(tPasswordL);
	addTextListener(tUsernameR);
	addTextListener(tPasswordR);
	addTextListener(tPasswordRR);

	addButtonListener(bLogin, lMsg);
	addButtonListener(bRegister, lMsg);

	// set tab-order for login form
	// first element cast hints type for the rest
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


    private void addCalendarListener(DateTime calendar, StyledText textPad, Menu menu)
    {
	calendar.addSelectionListener(new class(calendar) SelectionAdapter
        {
	    StyledText txtPad;
	    DateTime cal;
	    Menu textMenu;
	    this(DateTime cal)
	    {
		this.cal = calendar;
		this.txtPad = textPad;
		this.textMenu = menu;
	    }
	    public void widgetSelected(SelectionEvent e)
	    {
		markCalendarDays(this.cal);

		char[] date = Integer.toString(this.cal.getDay) ~ "-";
		date ~= Integer.toString(this.cal.getMonth + 1) ~ "-";
		date ~= Integer.toString(this.cal.getYear);

		auto now = Clock.Clock().toDate;
		char[] today = Integer.toString(now.date.day) ~ "-";
		today ~= Integer.toString(now.date.month) ~ "-";
		today ~= Integer.toString(now.date.year);

		saveText(this.txtPad);

		// allow editing of today's entry only
		if(today == date)
		{
		    this.txtPad.setEditable(true);
		    this.txtPad.setMenu(this.textMenu);
		}
		else
		{
		    this.txtPad.setEditable(false);
		    this.txtPad.setMenu(null);
		}

		this.txtPad.setText(Storage.getText(this.cal));
		this.txtPad.setData(new Data("noteid", "-1"));
		this.txtPad.setStyleRanges(categoryRangesToStyleRanges(Storage.getCategoryRanges(this.cal)));
		this.txtPad.setFocus;
	    }
	});
    }


//     private void addTextPadModifyListener(StyledText text)
//     {
// 	text.addModifyListener(new class(text) ModifyListener
//         {
// 	    StyledText txtPad;
// 	    this(StyledText st)
//             {
// 		this.txtPad = text;
// 	    }

// 	    public void modifyText(ModifyEvent event)
//             {
// 		// only today's text is editable & storable
// 		if(this.txtPad.getEditable)
// 		    saveText(this.txtPad);
// 	    }
// 	});
//     }


    // Let new text take on colors of immediately preceding
    // or succeeding text.
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


    private void addTextPadKeyListener(StyledText text, DateTime cal)
    {
	text.addKeyListener(new class(text, cal) KeyListener
	{
	    StyledText txtPad;
	    DateTime calendar;
	    this(StyledText t, DateTime d)
	    {
		this.txtPad = text;
		this.calendar = cal;
	    }
	    public void keyPressed(KeyEvent event)
	    {
		// Save encrypted text to file when "CTRL + S" pressed
		if(this.txtPad.getEditable &&
		   (((event.stateMask & DWT.CTRL) == DWT.CTRL) && (KEY_S == event.keyCode)))
		    Storage.saveFinal;

		// Emerge small text input beneath text pad for
		// incremental find in currently displayed text
		if(((event.stateMask & DWT.CTRL) == DWT.CTRL) && (KEY_F == event.keyCode))
		    drawIncrementalFindInput(this.txtPad);

		// Refresh text pad content - DEBUG
		if(this.txtPad.getEditable &&
		   (((event.stateMask & DWT.CTRL) == DWT.CTRL) && (KEY_R == event.keyCode)))
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
    private void addTextPadMenuDetectListener(StyledText text, Menu menu)
    {
	text.addMenuDetectListener(new class(text, menu) MenuDetectListener
	{
	    StyledText txtPad;
	    Menu txtPadMenu;
	    this(StyledText t, Menu m)
	    {
		this.txtPad = text;
		this.txtPadMenu = menu;
	    }

	    public void menuDetected(MenuDetectEvent event)
	    {
		// only today's text is editable
		if(!this.txtPad.getEditable)
		{
		    this.txtPad.setMenu(null);
		    return;
		}

		// caret is too far, nothing underneath anymore
		if(this.txtPad.getCharCount <= this.txtPad.getCaretOffset)
		{
		    // move caret one character back
		    if(0 < this.txtPad.getCaretOffset)
		    {
			// preserve selection
			Point selection = this.txtPad.getSelection;
			this.txtPad.setCaretOffset(this.txtPad.getCaretOffset - 1);
			this.txtPad.setSelection(selection);
		    }
		    else
		    {
			this.txtPad.setMenu(null);
			return;
		    }
		}
		
		Point selection = this.txtPad.getSelection;
		int start = selection.x;
		int length = selection.y - selection.x;

		// selection is past character count
		if(this.txtPad.getCharCount <= start)
		{
		    this.txtPad.setMenu(null);
		    return;
		}

		// no selection and no style underneath cursor - hide menu
		if((length <= 0) && !this.txtPad.getStyleRangeAtOffset(start))
		{
		    this.txtPad.setMenu(null);
		    return;
		}

		// no selection but style underneath cursor - show menu
		if((length <= 0) && this.txtPad.getStyleRangeAtOffset(start))
		{
		    this.txtPad.setMenu(this.txtPadMenu);
		    return;
		}

		// selection overlaps with existing styles - hide menu
 		if(0 < this.txtPad.getRanges(start, length).length)
		{
		    this.txtPad.setMenu(null);
		    return;
		}

		// selected text is not associated with any category - show menu
		if((0 < length) && !this.txtPad.getStyleRangeAtOffset(start))
		{
		    this.txtPad.setMenu(this.txtPadMenu);
		    return;
		}
	    }
	});
    }


    /*
      Store new category name and change it in textPad's context menu.
    */
    private void addCategoryNameModifyListener(Text textInput, Menu menu, StyledText text)
    {
	textInput.addModifyListener(new class(textInput, menu, text) ModifyListener
        {
	    Text catText;
	    Menu txtPadMenu;
	    StyledText txtPad;
	    this(Text t, Menu m, StyledText st)
            {
		this.catText = textInput;
		this.txtPadMenu = menu;
		this.txtPad = text;
	    }

	    public void modifyText(ModifyEvent event)
            {
		int id = Integer.toInt((cast(Data)this.catText.getData).get("id"));
		Storage.renameCategory(id, this.catText.getText);

		foreach(MenuItem catItem; this.txtPadMenu.getItems)
		{
 		    int itemId = Integer.toInt((cast(Data)catItem.getData).get("id"));
 		    if(itemId == id)
		    {
			catItem.setText(this.catText.getText);
			break;
		    }
		}
	    }
	});
    }


    private void addTextMenuListener(Menu menu, StyledText text)
    {
	menu.addMenuListener(new class(menu, text) MenuAdapter
        {
	    Menu txtPadMenu;
	    StyledText txtPad;
	    this(Menu m, StyledText t)
	    {
		this.txtPadMenu = menu;
		this.txtPad = text;
	    }

	    public void menuShown(MenuEvent event)
	    {
		Point selection = this.txtPad.getSelection;
		int start = selection.x;
		int length = selection.y - selection.x;
		int end = selection.y;

		// nothing selected and no style on this line
		int lineBegin = this.txtPad.getOffsetAtLine(this.txtPad.getLineAtOffset(start));
		if(this.txtPad.getCharCount <= lineBegin) return;
		StyleRange style = this.txtPad.getStyleRangeAtOffset(lineBegin);
		if((length <= 0) && style)
		{
		    foreach(MenuItem item; this.txtPadMenu.getItems)
		    {
			Data itemData = cast(Data)item.getData;
			if(CLEAR_ID == itemData.get("id"))
			    return;
		    }

		    // add option to remove style from paragraph
		    MenuItem sepItem = new MenuItem(this.txtPadMenu, DWT.SEPARATOR);
		    sepItem.setData(new Data("id", SEPARATOR_ID));
		    MenuItem clearItem = new MenuItem(this.txtPadMenu, DWT.NONE);
		    clearItem.setData(new Data("id", CLEAR_ID));
		    clearItem.setText(CLEAR_MENU_ITEM_TEXT);
		    DateTime calendar;
		    addMenuItemListener(clearItem, this.txtPadMenu, this.txtPad, calendar);
		}
		// remove separator and option to remove style from paragraph
		else
		{
		    foreach(MenuItem item; this.txtPadMenu.getItems)
		    {
			Data itemData = cast(Data)item.getData;
			if(SEPARATOR_ID == itemData.get("id"))
			    item.dispose;
			if(CLEAR_ID == itemData.get("id"))
			    item.dispose;
		    }
		}
		this.txtPad.setMenu(this.txtPadMenu);
	    }
	});
    }


    private void addMenuItemListener(MenuItem menuItem, Menu menu, StyledText text, DateTime cal)
    {
	menuItem.addSelectionListener(new class(menuItem, menu, text, cal) SelectionAdapter
        {
	    MenuItem item;
	    Menu txtPadMenu;
	    DateTime calendar;
	    StyledText txtPad;
	    this(MenuItem mi, Menu m, StyledText t, DateTime d)
	    {
		this.item = menuItem;
		this.txtPadMenu = menu;
		this.calendar = cal;
		this.txtPad = text;
	    }

	    public void widgetSelected(SelectionEvent event)
	    {
		Data itemData = cast(Data)this.item.getData;

		if(itemData.get("id") == CLEAR_ID)
		{
		    // set line to remove style down from
		    int lineAtOffset = this.txtPad.getLineAtOffset(this.txtPad.getCaretOffset) + 1;
		    if((this.txtPad.getLineCount - 1) < lineAtOffset)
			lineAtOffset = this.txtPad.getLineCount - 1;

		    int titlePos = clearStyle(this.txtPad,
					      this.txtPad.getCaretLine,
					      this.txtPad.getOffsetAtLine(lineAtOffset));
		    if(-1 == titlePos)
			titlePos = 0;
		    
		    // remove category names - paragraph title
		    int length = this.txtPad.getLine(titlePos).length;
		    this.txtPad.replaceTextRange(this.txtPad.getOffsetAtLine(titlePos), length + 1, "");
		    Storage.setCategoryRanges(null, styleRangesToCategoryRanges(this.txtPad.getStyleRanges));

		    return;
		}   

		Point selection = this.txtPad.getSelection;

		int start = selection.x;
		int length = selection.y - selection.x;
		int end = selection.y;

		// nothing selected and no style on this line
		int lineBegin = this.txtPad.getOffsetAtLine(this.txtPad.getLineAtOffset(start));
		if(this.txtPad.getCharCount <= lineBegin) return;
		StyleRange style = this.txtPad.getStyleRangeAtOffset(lineBegin);
		if((length <= 0) && !style) return;

		// style underneath cursor, but no selection.
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

		// does selection overlap with existing styles?
 		if(0 < this.txtPad.getRanges(start, length).length) return;

		// background for category title(s)
		StyleRange styleTitle = new StyleRange(start,
						       catName.length,
						       null,
						       getColor(getConfig(USER_CATEGORY_BACKGROUND_COLOR_SETTING_NAME)),
						       DWT.BOLD);
		// background for paragraph
		StyleRange styleBody = new StyleRange(start + catName.length,
						      length + 1,
						      null,
						      getColor(getConfig(USER_CATEGORY_BACKGROUND_COLOR_SETTING_NAME)));

		// add empty line at the end if replacement is longer than original text
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


    private void addTextSearchKeyListener(Composite rightComposite,
					  Text textSearch,
					  StyledText textPad,
					  Composite catEditList,
					  DateTime calendar)
    {
	textSearch.addKeyListener(new class(rightComposite,
					    textSearch,
					    textPad,
					    catEditList,
					    calendar) KeyListener
	{
	    Composite _rightComposite;
	    Text txtSearch;
	    StyledText txtPad;
	    Composite catList;
	    DateTime cal;
	    this(Composite c, Text t, StyledText s, Composite cl, DateTime dt)
	    {
		this._rightComposite = rightComposite;
		this.txtSearch = textSearch;
		this.txtPad = textPad;
		this.catList = catEditList;
		this.cal = calendar;
	    }
	    public void keyPressed(KeyEvent event)
	    {
		if(KEY_ENTER == event.keyCode)
		{
		    // Save current text so it becomes searchable,
		    // and cannot be overwritten when jump to search result is made.
		    saveText(this.txtPad);

		    char[] searchResults;
		    // get the first search result page
		    if(0 == (searchResults = Storage.search(this.txtSearch.getText,
							    getSelectedCategories(this.catList))).length)
			searchResults = Storage.getSearchResultPage;
		    
		    drawSearchResultsWindow(this._rightComposite, searchResults, this.txtPad, this.cal);
		}
	    }
	    public void keyReleased(KeyEvent event){}
	});
    }


    private void addTodayButtonListener(Button button, DateTime calendar, StyledText text)
    {
	button.addListener(DWT.Selection, new class(calendar, text) Listener
	{
	    DateTime cal;
	    StyledText txtPad;
	    this(DateTime d, StyledText s)
	    {
		this.cal = calendar;
		this.txtPad = text;
	    }
	    // doing it the long way, because setDate of DateTime
	    // calls DateTime Selection listener twice for some reason
	    public void handleEvent(Event event)
	    {
		auto date = Clock.Clock().toDate.date;
		this.cal.setYear(date.year);
		this.cal.setMonth(date.month - 1);
		this.cal.setDay(date.day);
		markCalendarDays(this.cal);
		saveText(this.txtPad);
		this.txtPad.setText(Storage.getText);
		this.txtPad.setData(new Data("noteid", "-1"));
		this.txtPad.setEditable(true);
		this.txtPad.setStyleRanges(categoryRangesToStyleRanges(Storage.getCategoryRanges));
		this.txtPad.setFocus;
	    }
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
    private void addNoteFocusListener(Text noteText, StyledText textPad)
    {
	noteText.addFocusListener(new class(noteText, textPad) FocusListener
        {
	    Text noteTxt;
	    StyledText txtPad;
	    this(Text t, StyledText st)
            {
		this.noteTxt = noteText;
		this.txtPad = textPad;
	    }
	    public void focusGained(FocusEvent event)
	    {
		char[] noteID = (cast(Data)this.noteTxt.getData).get("id");
		this.txtPad.setText(Storage.noteContent(Integer.toInt(noteID)));

		// Set note ID in text pad to real note ID so note is saved
		// next time saveText is called.
		this.txtPad.setData(new Data("noteid", (noteID)));
		this.txtPad.setEditable(true);
	    }
	    public void focusLost(FocusEvent event){}
	});
    }


    private void drawMainWindow(in Shell shell)
    {
	foreach(child; shell.getChildren)
		child.dispose;

	GridLayout layout = new GridLayout(2, false);
        shell.setLayout(layout);

	// left column
	GridData leftCol = new GridData(DWT.FILL, DWT.FILL, false, true);
	GridLayout leftLayout = new GridLayout(1, false);

	// left group
	Composite leftComposite = new Composite(shell, DWT.NONE);
	leftComposite.setLayout(leftLayout);
	leftComposite.setLayoutData(leftCol);

	// right column
	GridData rightCol = new GridData(DWT.FILL, DWT.FILL, true, true);
	GridLayout rightLayout = new GridLayout(1, false);

	// right group
	Composite rightComposite = new Composite(shell, DWT.NONE);
	rightComposite.setLayout(rightLayout);
	rightComposite.setLayoutData(rightCol);

        GridData calendarData = new GridData(MAIN_WINDOW_LEFT_COLUMN_WIDTH, DWT.DEFAULT);
	DateTime calendar = new DateTime(leftComposite, DWT.CALENDAR);
        calendarData.verticalAlignment = DWT.TOP;
	calendarData.heightHint = MAIN_WINDOW_CALENDAR_HEIGHT;
        calendar.setLayoutData(calendarData);
	markCalendarDays(calendar);

	GridData gdButtonToday = new GridData(MAIN_WINDOW_LEFT_COLUMN_WIDTH, DWT.DEFAULT);
	Button bToday = new Button(leftComposite, DWT.BORDER);
        gdButtonToday.verticalAlignment = DWT.CENTER;
	gdButtonToday.heightHint = MAIN_WINDOW_LEFT_COLUMN_BUTTON_HEIGHT;
	setFont(cast(Control)bToday, FONT_SIZE_3, DWT.BOLD);
	bToday.setText(TODAY_TEXT);
        bToday.setLayoutData(gdButtonToday);

	// Big text field on the right
	GridData rightData = new GridData(DWT.FILL, DWT.FILL, true, true);
	StyledText textPad = new StyledText(rightComposite,
					    DWT.BORDER | DWT.MULTI | DWT.H_SCROLL | DWT.V_SCROLL);
	textPad.setFocus;
	setFont(cast(Control)textPad, FONT_SIZE_1, DWT.NONE);
	textPad.setText(Storage.getText);
	textPad.setData(new Data("noteid", "-1"));
	textPad.setStyleRanges(categoryRangesToStyleRanges(Storage.getCategoryRanges));
 	textPad.setLayoutData(rightData);
	textPad.setKeyBinding(DWT.MOD1 + 'A', ST.SELECT_ALL);

	// Search field
	GridData gdSearch = new GridData(MAIN_WINDOW_LEFT_COLUMN_WIDTH - 8, DWT.DEFAULT);
	Text textSearch = new Text(leftComposite, DWT.DEFAULT);
	setFont(cast(Control)textSearch, FONT_SIZE_3, DWT.ITALIC);
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
		    setFont(cast(Control)this.txtSearch, FONT_SIZE_3, DWT.NONE);
		    this.txtSearch.setForeground(new Color(Display.getCurrent, 0, 0, 0));
		}
		this.txtSearch.setData(new Data("used", "1"));
	    }
	    public void focusLost(FocusEvent event){}
	});

	Composite catEditGroup = new Composite(leftComposite, DWT.NONE);
	catEditGroup.setLayout(new GridLayout(2, false));

	GridData gdCat1 = new GridData(MAIN_WINDOW_LEFT_COLUMN_WIDTH - 58, DWT.DEFAULT);
	Button catCheck = new Button(catEditGroup, DWT.CHECK);
	catCheck.setLayoutData(gdCat1);
	setFont(cast(Control)catCheck, FONT_SIZE_1, DWT.BOLD);
	catCheck.setSelection(true);
        catCheck.setText(CATEGORIES_TEXT);

	GridData gdCat2 = new GridData(44, DWT.DEFAULT);
	Button catAdd = new Button(catEditGroup, DWT.LEFT);
	catAdd.setLayoutData(gdCat2);
	setFont(cast(Control)catAdd, FONT_SIZE_2, DWT.BOLD);
        catAdd.setText("+ —");
	catAdd.setToolTipText(ADD_REMOVE_BUTTON_TOOLTIP);

	Composite c = new Composite(leftComposite, DWT.NONE);
	c.setLayout(new FillLayout(DWT.VERTICAL));
	GridData gdc = new GridData(DWT.LEFT, DWT.TOP, true, true);
	gdc.widthHint = MAIN_WINDOW_LEFT_COLUMN_WIDTH;
	gdc.heightHint = CATEGORY_LIST_HEIGHT;
	c.setLayoutData(gdc);
	ScrolledComposite sc = new ScrolledComposite(c, DWT.V_SCROLL);
	Composite catEditList = new Composite(sc, DWT.NONE);
	catEditList.setLayout(new GridLayout(2, false));

	// check or uncheck all categories
	catCheck.addListener(DWT.Selection, new class(catCheck, catEditList) Listener
	{
	    Button _catCheck;
	    Composite _catEditList;
	    this(Button b, Composite c)
	    {
		this._catCheck = catCheck;
		this._catEditList = catEditList;
	    }
	    public void handleEvent(Event e)
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

	int catCheckWidth = 24;
	int catListWidth = MAIN_WINDOW_LEFT_COLUMN_WIDTH - 60;
	Color catTextBack = getColor(CATEGORY_LIST_BACKGROUND_COLOR);

	// right-click / context menu for text area
	Menu textPadMenu = new Menu(cast(Decorations)shell);
	addTextMenuListener(textPadMenu, textPad);

	// populate category list box with saved user categories
	char[][] category;
	while(null !is (category = Storage.getCategory))
	{
	    char[] id = category[0];
	    char[] name = category[1];

	    GridData gdCatCheck = new GridData(catCheckWidth, DWT.DEFAULT);
	    Button catChk = new Button(catEditList, DWT.CHECK);
	    catChk.setData(new Data("id", id));
	    catChk.setLayoutData(gdCatCheck);
	    catChk.setSelection(true);

	    GridData gdCatName = new GridData(catListWidth, DWT.DEFAULT);
	    Text catText = new Text(catEditList, DWT.NONE);
	    setFont(cast(Control)catText, FONT_SIZE_1, DWT.NONE);
	    catText.setLayoutData(gdCatName);
	    catText.setData(new Data("id", id));
	    catText.setText(name);
	    catText.setBackground(catTextBack);
	    // prevent default menu
	    catText.setMenu(new Menu(catText));
	    addCategoryNameModifyListener(catText, textPadMenu, textPad);

	    // add category to textPad's context menu
	    MenuItem catItem = new MenuItem(textPadMenu, DWT.NONE);
	    catItem.setData(new Data("id", id));
	    catItem.setText(name);
	    addMenuItemListener(catItem, textPadMenu, textPad, calendar);
 	}

	textPad.setMenu(textPadMenu);

        sc.setContent(catEditList);
	sc.setMinSize(catEditList.computeSize(DWT.DEFAULT, DWT.DEFAULT));
        sc.setExpandHorizontal(true);
        sc.setExpandVertical(true);

	// Add to or remove category from category list.
	catAdd.addListener(DWT.Selection, new class(catEditList, sc, textPadMenu, textPad) Listener
	{
	    Composite _catEditList;
	    ScrolledComposite _sc;
	    Menu txtPadMenu;
	    StyledText txtPad;
	    this(Composite c, ScrolledComposite _s, Menu m, StyledText t)
	    {
		this._catEditList = catEditList;
		this._sc = sc;
		this.txtPadMenu = textPadMenu;
		this.txtPad = textPad;
	    }

	    public void handleEvent(Event event)
	    {
		// remove categories with empty names
		// and belonging checkboxes
		Button b;
		bool disposed = false;
		foreach(Control c; this._catEditList.getChildren)
		{
		    if("Button" == c.getName)
			b = cast(Button)c;

		    if("Text" == c.getName)
		    {
			Text t = cast(Text)c;
 			if(Txt.trim(t.getText).length <= 0)
			{
			    int id = Integer.toInt((cast(Data)b.getData).get("id"));
			    Storage.removeCategory(id);
			    b.dispose;
 			    t.dispose;
			    disposed = true;

			    // remove category from textPad's context menu
			    foreach(catItem; this.txtPadMenu.getItems)
			    {
				int itemId = Integer.toInt((cast(Data)catItem.getData).get("id"));
				if(itemId == id)
				{
				    catItem.dispose;
				    break;
				}
			    }
			}
		    }
		}

		// add new category and checkbox if none have been disposed
		if(!disposed)
		{
		    int catCheckWidth = 24;
		    int catListWidth = MAIN_WINDOW_LEFT_COLUMN_WIDTH - 60;

		    // id of new category
		    char[] id = Integer.toString(Storage.addCategory(NEW_CATEGORY_TEXT));

		    GridData gdCheck = new GridData(catCheckWidth, DWT.DEFAULT);
		    Button catCheck = new Button(this._catEditList, DWT.CHECK);
		    catCheck.setData(new Data("id", id));
		    catCheck.setLayoutData(gdCheck);
		    catCheck.setSelection(true);

		    GridData gdText = new GridData(catListWidth, DWT.DEFAULT);
		    Text catText = new Text(this._catEditList, DWT.NONE);
		    setFont(cast(Control)catText, FONT_SIZE_1, DWT.NONE);
		    catText.setData(new Data("id", id));
		    catText.setText(NEW_CATEGORY_TEXT);
		    catText.setLayoutData(gdText);
		    catText.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
		    // prevent default menu
		    catText.setMenu(new Menu(catText));
		    addCategoryNameModifyListener(catText, this.txtPadMenu, this.txtPad);

		    // add category to textPad's context menu
		    // 0 puts menu item on top of menu
		    MenuItem catItem = new MenuItem(this.txtPadMenu, DWT.NONE, 0);
		    catItem.setData(new Data("id", id));
		    catItem.setText(NEW_CATEGORY_TEXT);
		    addMenuItemListener(catItem, this.txtPadMenu, this.txtPad, calendar);
		}

		// redraw parent container
		this._sc.setContent(this._catEditList);
		this._sc.setMinSize(this._catEditList.computeSize(DWT.DEFAULT, DWT.DEFAULT));
	    }
	});

	Composite notesEditGroup = new Composite(leftComposite, DWT.NONE);
	notesEditGroup.setLayout(new GridLayout(2, false));

	GridData gdNote1 = new GridData(MAIN_WINDOW_LEFT_COLUMN_WIDTH - 58, DWT.DEFAULT);
	Label lNotes = new Label(notesEditGroup, DWT.NONE);
	lNotes.setLayoutData(gdNote1);
	setFont(cast(Control)lNotes, FONT_SIZE_1, DWT.BOLD);
        lNotes.setText(NOTES_TEXT);

	GridData gdNote2 = new GridData(44, DWT.DEFAULT);
	Button noteAdd = new Button(notesEditGroup, DWT.LEFT);
	noteAdd.setLayoutData(gdNote2);
	setFont(cast(Control)noteAdd, FONT_SIZE_2, DWT.BOLD);
        noteAdd.setText("+ —");
	noteAdd.setToolTipText(ADD_REMOVE_BUTTON_TOOLTIP);

	Composite n = new Composite(leftComposite, DWT.NONE);
	n.setLayout(new FillLayout(DWT.VERTICAL));
	GridData gdn = new GridData(DWT.LEFT, DWT.TOP, true, true);
	gdn.widthHint = MAIN_WINDOW_LEFT_COLUMN_WIDTH;
	gdn.heightHint = CATEGORY_LIST_HEIGHT;
	n.setLayoutData(gdn);

	ScrolledComposite scn = new ScrolledComposite(n, DWT.V_SCROLL);
	Composite noteEditList = new Composite(scn, DWT.NONE);
	noteEditList.setLayout(new GridLayout(1, false));

	int noteListWidth = MAIN_WINDOW_LEFT_COLUMN_WIDTH - 60;
	Color noteTextBack = getColor(CATEGORY_LIST_BACKGROUND_COLOR);

	// populate note list box with saved user notes
	foreach(id, name; Storage.getNotes)
	{
	    GridData gdNoteName = new GridData(noteListWidth, DWT.DEFAULT);
	    Text noteText = new Text(noteEditList, DWT.NONE);
	    setFont(cast(Control)noteText, FONT_SIZE_1, DWT.NONE);
	    noteText.setLayoutData(gdNoteName);
	    noteText.setData(new Data("id", Integer.toString(id)));
	    noteText.setText(name);
	    noteText.setBackground(noteTextBack);
	    // prevent default menu
	    noteText.setMenu(new Menu(noteText));
	    addNoteNameModifyListener(noteText);
	    addNoteFocusListener(noteText, textPad);
	}

        scn.setContent(noteEditList);
	scn.setMinSize(noteEditList.computeSize(DWT.DEFAULT, DWT.DEFAULT));
        scn.setExpandHorizontal(true);
        scn.setExpandVertical(true);	

	// Add to or remove note from note list.
	noteAdd.addListener(DWT.Selection, new class(noteEditList, scn, textPad) Listener
	{
	    Composite _noteEditList;
	    ScrolledComposite _scn;
	    StyledText txtPad;
	    this(Composite c, ScrolledComposite _s, StyledText t)
	    {
		this._noteEditList = noteEditList;
		this._scn = scn;
		this.txtPad = textPad;
	    }

	    public void handleEvent(Event event)
	    {
		// Remove notes with empty names.
		bool disposed = false;
		foreach(Control c; this._noteEditList.getChildren)
		{
		    if("Text" == c.getName)
		    {
			Text t = cast(Text)c;
 			if(Txt.trim(t.getText).length <= 0)
			{
			    int id = Integer.toInt((cast(Data)t.getData).get("id"));
			    Storage.removeNote(id);
 			    t.dispose;
			    disposed = true;
			}
		    }
		}

		// Add new note if none have been disposed.
		if(!disposed)
		{
		    int noteListWidth = MAIN_WINDOW_LEFT_COLUMN_WIDTH - 60;

		    // id of new note
		    char[] id = Integer.toString(Storage.addNote);
		    char[] name = NOTES_TEXT ~ " " ~ id;

		    GridData gdText = new GridData(noteListWidth, DWT.DEFAULT);
		    Text noteText = new Text(this._noteEditList, DWT.NONE);
		    setFont(cast(Control)noteText, FONT_SIZE_1, DWT.NONE);
		    noteText.setData(new Data("id", id));
		    noteText.setText(name);
		    noteText.setLayoutData(gdText);
		    noteText.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
		    // prevent default menu
		    noteText.setMenu(new Menu(noteText));
		    addNoteNameModifyListener(noteText);
		    addNoteFocusListener(noteText, this.txtPad);
		}

		// redraw parent container
		this._scn.setContent(this._noteEditList);
		this._scn.setMinSize(this._noteEditList.computeSize(DWT.DEFAULT, DWT.DEFAULT));
	    }
	});

	GridData gdButtonExit = new GridData(MAIN_WINDOW_LEFT_COLUMN_WIDTH, DWT.BOTTOM);
	Button bExit = new Button(leftComposite, DWT.BORDER);
        gdButtonExit.verticalAlignment = DWT.CENTER;
	gdButtonExit.heightHint = MAIN_WINDOW_LEFT_COLUMN_BUTTON_HEIGHT;
	setFont(cast(Control)bExit, FONT_SIZE_3, DWT.BOLD);
	bExit.setText("Save && Close");
        bExit.setLayoutData(gdButtonExit);

	bExit.addListener(DWT.Selection, new class(textPad, shell, catEditList, bExit) Listener
	{
	    StyledText text;
	    Shell shell;
	    Button btnExit;
	    Composite catList;
	    this(StyledText text, Shell shell, Composite composite, Button button)
	    {
		this.text = textPad;
		this.shell = shell;
		this.catList = catEditList;
		this.btnExit = bExit;
	    }
	    public void handleEvent(Event event)
	    {
		if(event.widget is this.btnExit)
		{
		    Storage.saveFinal;
// 		    Storage.saveFinal(this.text.getText,
// 				      styleRangesToCategoryRanges(this.text.getStyleRanges));
		    this.shell.close;
		}
	    }
	});

	addCalendarListener(calendar, textPad, textPadMenu);
//	addTextPadModifyListener(textPad);
	addTextPadExtendedModifyListener(textPad);
	addTextPadKeyListener(textPad, calendar);
	addTextPadMenuDetectListener(textPad, textPadMenu);
	addTextSearchKeyListener(rightComposite, textSearch, textPad, catEditList, calendar);
	addTodayButtonListener(bToday, calendar, textPad);

	setShellSize(shell);
	shell.layout;
    }


    private void drawSearchResultsWindow(Composite parent,
					 char[] content,
					 StyledText textPad,
					 DateTime calendar)
    {
	// Remove previous search results.
	foreach(child; parent.getChildren)
	    if(("ScrolledComposite" == child.getName) || "Text" == child.getName)
		child.dispose;

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

	sc.setContent(c);
	sc.setMinSize(c.computeSize(DWT.DEFAULT, DWT.DEFAULT));
	sc.setExpandHorizontal(true);
	sc.setExpandVertical(true);

	// Adjust height of text pad above.
	(cast(GridData)textPad.getLayoutData).heightHint = parent.getSize.y / 2;
	parent.layout(true);

	link.addListener(DWT.Selection, new class(parent, sc, link, calendar) Listener
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
	    public void handleEvent(Event event)
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
		    char[] content = Storage.getSearchResultPage(Integer.toInt(event.text[4..event.text.length]));
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
		    int year = Integer.toInt(dayName[0..4]);
		    int month = Integer.toInt(dayName[4..6]);
		    int day = Integer.toInt(dayName[6..8]);

		    if(getTodayFileName == dateToFileName(year, month, day))
			txtPad.setEditable(true);
		    else
			txtPad.setEditable(false);

		    this.cal.setYear(year);
		    this.cal.setMonth(month - 1);
		    this.cal.setDay(day);

		    saveText(txtPad);
		    txtPad.setText(Storage.getText(this.cal));
		    txtPad.setData(new Data("noteid", "-1"));
		    txtPad.setStyleRanges(categoryRangesToStyleRanges(Storage.getCategoryRanges(this.cal)));

		    // highlight matching keywords and scroll to view
  		    int start = Integer.toInt(Txt.split(event.text[12..event.text.length], "-")[0]);
  		    int end = start + Txt.split(event.text[12..event.text.length], "-")[1].length;
		    txtPad.setSelection(start, end);
		}
	    }
	});
    }


    /*
      Emerge small text input beneath text pad for
      incremental search in currently displayed text
    */
    private void drawIncrementalFindInput(StyledText textPad)
    {
	Composite parent = textPad.getParent;

	// remove any previous text input boxes
	foreach(child; parent.getChildren)
	    if(("ScrolledComposite" == child.getName) || ("Text" == child.getName))
		child.dispose;

	GridData gdFind = new GridData(DWT.FILL, DWT.FILL, true, true);
	Text find = new Text(parent, DWT.BORDER);
	find.setLayoutData(gdFind);
	find.setMenu(new Menu(find));
	setFont(cast(Control)find, FONT_SIZE_3, DWT.NONE);
	find.setFocus;
	(cast(GridData)textPad.getLayoutData).heightHint = parent.getSize.y - INCREMENTAL_SEARCH_BOX_HEIGHT;
	parent.layout;
	
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
		// mark next match
		if(KEY_ENTER == event.keyCode)
		{
		    char[] find = (cast(Data)this.fnd.getData).get("find");
		    char[][] finds = Txt.split(find, " ");

		    if(finds.length <= 2) return;
		    
		    int length = Integer.toInt(finds[0]);
		    finds = finds[1..finds.length];

		    char[][] newFinds = shiftLeft(finds);

		    // mark previous match
		    if(((event.stateMask & DWT.SHIFT) == DWT.SHIFT) && (KEY_ENTER == event.keyCode))
			newFinds = shiftRight(finds);

		    int start = Integer.toInt(newFinds[0]);

		    char[] strFinds;
		    foreach(f; newFinds)
			strFinds ~= f ~ " ";

		    this.fnd.setData(new Data("find", Integer.toString(length) ~ " " ~ Txt.trim(strFinds)));
		    
		    this.txtPad.setSelection(start, start + length);
		}

		if(KEY_ESC == event.keyCode)
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
		    // match found, temporarily store it
		    if((0 == location) || (location < text.length))
		    {
			locations ~= location;
			strLocations ~= Integer.toString(location) ~ " ";
		    }

		    location += keywords.length;
		}while(location < text.length);

		this.fnd.setData(new Data("find", Integer.toString(keywords.length) ~ " " ~ Txt.trim(strLocations)));
		// mark first find
		if(0 < locations.length)
		    this.txtPad.setSelection(locations[0], locations[0] + keywords.length);
	    }
	});
    }


    public void draw()
    {
	setShellSize(this.shell);
	addShellListener(this.shell);

	this.shell.open;

	while(!this.shell.isDisposed)
	{
	    if(!this.display.readAndDispatch)
	    {
		// auto-save trap
		this.display.sleep;
	    }
	}

	this.display.dispose;
    }
}