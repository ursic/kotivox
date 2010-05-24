module gui.chain;

import tango.stdc.math;
import tango.core.Array;
import tango.time.chrono.Gregorian;

public import gui.util;
import util;
import storage;

private struct ChainData
{
    int id;
    Date start;
    int year;
    int todayOrigin = -1;
}
private ChainData cd;


// Half thickness of stroke in percent.
private float halfThickness = CHAIN_MARK_STROKE_HALF_THICKNESS;


private int[] strokeLeft(int x, int y, int width, int height)
{
    return [x + 1, y + cast(int)round(height * halfThickness),
	    x + 1, y + 1,
	    x + cast(int)round(width * halfThickness) + 1, y + 1,
	    x + width, y + height - cast(int)round(height * halfThickness),
	    x + width, y + height,
	    x + width - cast(int)round(width * halfThickness), y + height];
}


private int[] strokeRight(int x, int y, int width, int height)
{
    return [x + width - cast(int)round(width * halfThickness), y + 1,
	    x + width, y + 1,
	    x + width, y + cast(int)round(height * halfThickness),
	    x + cast(int)round(width * halfThickness), y + height,
	    x + 1, y + height,
	    x + 1, y + height - cast(int)round(height * halfThickness)];
}


/*
  Draws date number in a rectangle.
 */
private void drawDate(GC gc,
		      Date date,
		      int x,
		      int y,
		      int width,
		      int height,
		      bool center = true)
{
    gc.drawRectangle(x, y, width, height);

    int fontSize = width / 2;
    if(!center) fontSize = width / 6;

    int style = DWT.NONE;

    // Draw Sundays in red.
    if(0 == Integer.toInt(dateFormat("%w", date)))
	gc.setForeground(Display.getCurrent.getSystemColor(DWT.COLOR_RED));

    // Color today's day blue and bold.
    if(date == today)
    {
	style = DWT.BOLD;
	gc.setForeground(Display.getCurrent.getSystemColor(DWT.COLOR_BLUE));
    }

    gc.setFont(getFont(fontSize, style));

    char[] dateStr = Txt.stripl(Integer.toString(date.day), '0');

    Point extent = gc.stringExtent(dateStr);
    int yPos = y + cast(int)round(height / 2) - cast(int)round(extent.y / 2);

    if(!center) yPos = y - cast(int)round(height * 0.01);

    gc.drawText(dateStr,
		x + cast(int)round(width / 2) - cast(int)round(extent.x / 2),
		yPos,
		true);

    gc.setForeground(Display.getCurrent.getSystemColor(DWT.COLOR_BLACK));
}


private class Day
{
    Date date;
    int x;
    int y;
    int width;
    int height;
    bool marked;
    static Day[] days;

    this(Date date, int x, int y, int width, int height)
    {
	this.date = date;
	this.x = x;
	this.y = y;
	this.width = width;
	this.height = height;
    }

    private static Day add(Date date, int x, int y, int width, int height)
    {
	Day d = new Day(date, x, y, width, height);
	Day.days ~= d;
	return d;
    }


    private void mark(GC gc)
    {
	drawDate(gc,
		 this.date,
		 this.x,
		 this.y,
		 this.width,
		 this.height,
		 false);
	gc.fillPolygon(strokeLeft(this.x, this.y, this.width, this.height));
	gc.fillPolygon(strokeRight(this.x, this.y, this.width, this.height));
	this.marked = true;
    }

    private void unmark(GC gc)
    {
	drawDate(gc,
		 this.date,
		 this.x,
		 this.y,
		 this.width,
		 this.height);
	this.marked = false;
    }
}


/*
  Draw big red X over chosen day.
 */
private void addChainClickListener(Canvas canvas)
{
    canvas.addMouseListener(new class(canvas) MouseAdapter
    {
	Canvas cs;
	this(Canvas c)
	{
	    this.cs = canvas;
	}
	public void mouseDown(MouseEvent event)
        {
	    if(Storage.isChainLocked(cd.id)) return;

	    GC gc = new GC(this.cs);
	    gc.setBackground(Display.getCurrent.getSystemColor(DWT.COLOR_RED));

	    foreach(day; Day.days)
	    {
		// Today's day and past days can be marked or unmarked.
		if(today < day.date) return;

		int x = day.x;
		int y = day.y;
		int width = day.width;
		int height = day.height;
		if(x < event.x && event.x <= (x + width) &&
		   y < event.y && event.y <= (y + height))
		{
		    this.cs.drawBackground(gc, x + 1, y + 1, width - 1, height - 1);
		    if(day.marked)
		    {
			day.unmark(gc);
			Storage.removeChainDate(cd.id, Integer.toInt(dateStr(day.date)));
			break;
		    }
		    Storage.addChainDate(cd.id, Integer.toInt(dateStr(day.date)));
		    day.mark(gc);
		    break;
		}
	    }
	    gc.dispose;
	}
    });
}


/*
  Draw previous/next year depending on mouse button pressed.
 */
private void addChainScrollListener(Canvas canvas)
{
    canvas.addMouseListener(new class(canvas) MouseAdapter
    {
	Canvas cs;
	this(Canvas c)
	{
	    this.cs = canvas;
	}
	public void mouseDown(MouseEvent event)
	{
	    // Get year text coordinates and see if user clicked on year text.
	    char[][] data = Txt.split((cast(Data)this.cs.getData).get("yearStr"), ".");
	    int xPos = Integer.toInt(data[0]);
	    int yPos = Integer.toInt(data[1]);
	    int width = Integer.toInt(data[2]);
	    int height = Integer.toInt(data[3]);

	    if(((xPos <= event.x) && (event.x <= xPos + width)) &&
	       (yPos <= event.y) && (event.y <= yPos + height))
	    {
		if(1 == event.button)
		    cd.year--;

		if(3 == event.button)
		    cd.year++;
	    }
	    else
		return;
	    
	    if(cd.year < cd.start.year) cd.year = cd.start.year;
	    if(today.year < cd.year) cd.year = today.year;

	    cd.todayOrigin = -1;
	    drawChainYear(this.cs);
	}
    });
}


/*
  Draw chain for given days in a year.
 */
private void drawChainYear(Canvas canvas)
{
    int[] chainDates = Storage.getChainDates(cd.id, cd.year);
    Day.days = null;
    
    GC gc = new GC(canvas);
    gc.setBackground(Display.getCurrent.getSystemColor(DWT.COLOR_RED));
    canvas.drawBackground(gc, 0, 0, canvas.getSize.x, canvas.getSize.y);

    int x = 0;
    int y = 0;
    int width = canvas.getSize.x;
    int headerHeight = 40;

    // Draw year number in the middle.
    char[] yearStr = Integer.toString(cd.year);
    gc.setFont(getFont(width / 24, DWT.NONE));
    Point extent = gc.stringExtent(yearStr);
    // Bottom edge of current content.
    // As more stuff is drawn, marginTop increases.
    int marginTop = y + 10 + extent.y;
    int xPos = (width / 2) - (extent.x / 2);
    int yPos = y + 10;
    gc.drawText(yearStr, xPos, yPos, true);

    // Store year text coordinates for scrolling detection.
    char[] data = Integer.toString(xPos);
    data ~= "." ~ Integer.toString(yPos);
    data ~= "." ~ Integer.toString(extent.x);
    data ~= "." ~ Integer.toString(extent.y);
    canvas.setData(new Data("yearStr", data));

    // Draw start if chain starts on given year.
    int dayOffset = 1;
    if(cd.start.year == cd.year)
	dayOffset = Integer.toInt(dateFormat("%j", cd.start));

    int daysInYear = (new Gregorian).getDaysInYear(cd.year, Gregorian.AD_ERA);
    Date date;
    width = canvas.getSize.x / 7;
    int xDate = x;
    int yDate;
    for(int i = dayOffset; i <= daysInYear; i++)
    {
	date = yearDayToDate(i, cd.year);

	// Stop drawing at today.
        if(today < date) break;

	// Vertical space after each month.
	if((1 == date.day) && (dayOffset < i))
	    marginTop += cast(int)(width * 1.5);

	// Draw month name and day names at the beginning of each month.
	if((dayOffset == i) || (1 == date.day))
	{
	    // Set scroll point to the beginning of current month.
	    if((today.year == date.year) &&
	       (today.month == date.month))
		if(-1 == cd.todayOrigin) cd.todayOrigin = marginTop - (headerHeight - 10);

	    char[] monthName = dateFormat("%B", date);
	    gc.setFont(getFont(width / 5, DWT.NONE));
	    extent = gc.stringExtent(monthName);
	    gc.drawText(monthName, x, marginTop, true);
	    marginTop += extent.y;

	    // Draw weekday names.
	    gc.setFont(getFont(width / 9, DWT.NONE));

	    int height = width / 6;
	    int xr = x;
	    int yr = marginTop;
	    int xt = x;
	    int yt = 0;
	    // Make Monday first day of the week.
	    char[][] dayNames = rotateLeft(dayNames);

	    for(int j = 0; j < dayNames.length; j++)
	    {
		gc.drawRectangle(xr, yr, width, height);
		extent = gc.stringExtent(dayNames[j]);
		xt = xr + cast(int)round(width / 2) - cast(int)round(extent.x / 2);
		yt = yr + cast(int)round(height / 2) - cast(int)round(extent.y / 2);
		gc.drawText(dayNames[j], xt, yt, true);
		xr += width;
	    }
	    marginTop += height + headerHeight;
	}

	// Draw day numbers.
	int height = width;
	xDate += width;

	// Put first day in month under its belonging name.
	if((1 == date.day) || (i == dayOffset))
	{
	    int wd = Integer.toInt(dateFormat("%w", date));
	    wd = (0 == wd) ? 7 : wd;
	    xDate = (width * wd) - width;
	}

	// New line every Monday.
	if(1 == Integer.toInt(dateFormat("%w", date)) &&
           (1 != date.day) &&
           (cd.start.day != date.day))
	{
	    xDate = x;
	    marginTop += height;
	}

	yDate = marginTop - headerHeight;

	Day day = Day.add(date, xDate, yDate, width, height);
	if(contains(chainDates, Integer.toInt(dateStr(date))))
	    day.mark(gc);
	else
 	    drawDate(gc, date, xDate, yDate, width, height);
    }

    gc.dispose;
    (cast(GridData)canvas.getLayoutData).heightHint = marginTop + (headerHeight * 4);

    Composite c = canvas.getParent;
    ScrolledComposite sc = cast(ScrolledComposite)c.getParent;
    sc.setMinSize(c.computeSize(DWT.DEFAULT, DWT.DEFAULT));

    // Set scroll anchor only first time canvas is painted.
    if(0 < cd.todayOrigin)
    {
	sc.setOrigin(0, cd.todayOrigin);
	cd.todayOrigin = 0;
    }
}


/*
  Redraw chain on each paint event.
 */
private void addChainPaintListener(Canvas canvas)
{
    canvas.addPaintListener(new class(canvas) PaintListener
    {
	Canvas cs;
	this(Canvas c)
	{
	    this.cs = canvas;
	}
	public void paintControl(PaintEvent event)
        {
	    drawChainYear(this.cs);
	}
    });
}


/*
  Save chain description when changed.
*/
private void addChainDescriptionListener(Text text)
{
    text.addModifyListener(new class(text) ModifyListener
    {
	Text txt;
	this(Text t)
	{
	    this.txt = text;
	}
	public void modifyText(ModifyEvent event)
	{
	    Storage.chainDesc(cd.id, this.txt.getText);
	}
    });
}


/*
  Menu option for locking and unlocking a chain.
*/
private void addLockMenuOption(Text text)
{
    Menu menu = text.getMenu;

    char[] lockStr = CHAIN_LOCK_TEXT;
    if(Storage.isChainLocked(cd.id)) lockStr = CHAIN_UNLOCK_TEXT;

    MenuItem item = new MenuItem(menu, DWT.NONE);
    item.setText(lockStr);

    item.addSelectionListener(new class(item, text) SelectionAdapter
    {
	MenuItem option;
	Text txt;
	this(MenuItem mi, Text t)
	{
	    this.option = item;
	    this.txt = text;
	}
	public void widgetSelected(SelectionEvent event)
	{
	    // Lock chain.
	    if(CHAIN_LOCK_TEXT == this.option.getText)
	    {
		Storage.lockChain(cd.id);
		this.option.setText(CHAIN_UNLOCK_TEXT);
		this.txt.setEditable(false);
		// Cosmetics: by drawing it afresh we get rid of
		// blinking caret.
		drawChainWindow(cd.id);
	    }
	    // Unlock chain.
	    else
	    {
		Storage.unlockChain(cd.id);
		this.option.setText(CHAIN_LOCK_TEXT);
		this.txt.setEditable(true);
	    }
	}
    });
}


void drawChainWindow(int id)
{
    cd.id = id;
    cd.start = Storage.getChainStartDate(cd.id);
    cd.year = today.year;

    // Retrieve right composite.
    Shell shell = Display.getCurrent.getShells[0];

    Composite rightGroup;
    foreach(child; shell.getChildren)
    {
	Data data = cast(Data)child.getData;
	if(data && (RIGHT_GROUP == data.get("name")))
	{
	    rightGroup = cast(Composite)child;
	    break;
	}
    }

    // Clean up the composite.
    foreach(child; rightGroup.getChildren) child.dispose;

    // Chain description.
    GridData gdt = new GridData(GridData.FILL_HORIZONTAL);
    Text text = new Text(rightGroup, DWT.CENTER | DWT.MULTI | DWT.BORDER);
    text.setMenu(new Menu(text));
    gdt.heightHint = CHAIN_DESCRIPTION_INPUT_HEIGHT;
    text.setLayoutData(gdt);
    text.setText(Storage.chainDesc(cd.id));
    text.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
    setFont(text, FONT_SIZE_3, DWT.NONE);
    if(Storage.isChainLocked(cd.id)) text.setEditable(false);
    addChainDescriptionListener(text);
    addLockMenuOption(text);

    // Canvas for chain.
    ScrolledComposite sc = new ScrolledComposite(rightGroup, DWT.V_SCROLL);
    sc.setLayoutData(new GridData(DWT.FILL, DWT.FILL, true, true));
    Composite c = new Composite(sc, DWT.BORDER);
    c.setLayout(new GridLayout(1, false));
    c.setBackgroundMode(DWT.INHERIT_DEFAULT);
    c.setBackground(getColor(CHAIN_BACKROUNG_COLOR));

    Canvas canvas = new Canvas(c, DWT.NONE);
    canvas.setLayoutData(new GridData(DWT.FILL, DWT.FILL, true, true));
    sc.setContent(c);
    sc.setExpandHorizontal(true);
    sc.setExpandVertical(true);

    rightGroup.layout;
    cd.todayOrigin = -1;

    addChainPaintListener(canvas);
    addChainClickListener(canvas);
    addChainScrollListener(canvas);
}