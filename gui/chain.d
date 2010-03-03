module gui.chain;

import tango.stdc.math;
import tango.core.Array;
import tango.time.chrono.Gregorian;

public import gui.util;
import util;
import storage;

import tango.io.Stdout;


private struct ChainData
{
    int id;
    Date start;
    int year;
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


private void drawDate(GC gc, char[] str, int x, int y, int width, int height, bool center = true)
{
    
    int fontSize = width / 2;

    if(!center) fontSize = width / 6;

    Font font = new Font(Display.getCurrent,
			 new FontData("Sans", fontSize, DWT.NONE));
    gc.setFont(font);

    Point extent = gc.stringExtent(str);
    int yPos = y + cast(int)round(height / 2) - cast(int)round(extent.y / 2);

    if(!center) yPos = y - cast(int)round(height * 0.01);

    gc.drawText(str,
		x + cast(int)round(width / 2) - cast(int)round(extent.x / 2),
		yPos,
		true);
}


private class Day
{
    int x;
    int y;
    int width;
    int height;
    int date = -1;
    bool marked;

    static Day[] days;

    this(int x, int y, int width, int height, int date)
    {
	this.x = x;
	this.y = y;
	this.width = width;
	this.height = height;
	this.date = date;
    }

    private static Day add(int x, int y, int width, int height, int date)
    {
	Day d = new Day(x, y, width, height, date);
	Day.days ~= d;
	return d;
    }

    /*
      Modify existing day.
      Add new one if it doesn't exist already.
     */
    private static Day modify(int x, int y, int width, int height, int date)
    {
	foreach(day; days)
	{
	    if(day.date == date)
	    {
		day.x = x;
		day.y = y;
		day.width = width;
		day.height = height;
		return day;
	    }
	}
	return add(x, y, width, height, date);
    }

    private void mark(GC gc)
    {
	drawDate(gc,
		 Integer.toString(this.date),
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
		 Integer.toString(this.date),
		 this.x,
		 this.y,
		 this.width,
		 this.height);
	this.marked = false;
    }
}


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

	    foreach(day; Day.days)
	    {
		int x = day.x;
		int y = day.y;
		int width = day.width;
		int height = day.height;
		char[] date = Integer.toString(day.date);
		GC gc = new GC(this.cs);
		gc.setBackground(event.display.getSystemColor(DWT.COLOR_RED));
		if(x < event.x && event.x <= (x + width) &&
		   y < event.y && event.y <= (y + height))
		{
		    this.cs.drawBackground(gc, x + 1, y + 1, width - 1, height - 1);
		    if(day.marked)
		    {
			day.unmark(gc);
			break;
		    }
		    day.mark(gc);
		    break;
		}
	    }
	}
    });
}


// private void addChainYearListener(Button button,
// 				  Canvas canvas)
// {
//     button.addSelectionListener(new class(button, canvas) SelectionAdapter
//     {
// 	Button btn;
// 	Canvas cs;
// 	this(Button b, Canvas c)
// 	{
// 	    this.btn = button;
// 	    this.cs = canvas;
// 	}
// 	public void widgetSelected(SelectionEvent event)
// 	{
// 	    cd.year += Integer.toInt((cast(Data)this.btn.getData).get("increment"));
// 	    drawChainYear(this.cs);
// 	}
//     });
// }


/*
  Draw previous/next year depending on mousewheel motion.
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

	    drawChainYear(this.cs);
	}
    });
}


/*
  Draw chain for given days in a year.
 */
private void drawChainYear(Canvas canvas)
{
//    Stdout("DRAW CHAIN YEAR").newline;

    GC gc = new GC(canvas);
    canvas.drawBackground(gc, 0, 0, canvas.getSize.x, canvas.getSize.y);

    int[] chainDates = Storage.getChainDates(cd.id, cd.year);

    if(chainDates.length <= 0) return;

    int x = 0;
    int y = 0;
    int width = canvas.getSize.x;

    // Draw year number in the middle.
    char[] yearStr = Integer.toString(cd.year);
    gc.setFont(getFont(FONT_SIZE_3, DWT.NONE));
    Point extent = gc.stringExtent(yearStr);
    int marginTop = y + 10 + extent.y + 40;
    int xPos = (width / 2) - (extent.x / 2);
    int yPos = y + 10;
    gc.drawText(yearStr,
		xPos,
		yPos,
		true);

    // Store year text coordinates.
    char[] data = Integer.toString(xPos);
    data ~= "." ~ Integer.toString(yPos);
    data ~= "." ~ Integer.toString(extent.x);
    data ~= "." ~ Integer.toString(extent.y);
    canvas.setData(new Data("yearStr", data));

    // Draw start if chain starts given year.
    int dayOffset = 1;
    if(cd.start.year == cd.year)
	dayOffset = Integer.toInt(dateFormat("%j", cd.start));

    int daysInYear = (new Gregorian).getDaysInYear(cd.year, Gregorian.AD_ERA);
    Date date;
    width = canvas.getSize.x / 7;
    int xDayr = x;
    int yDayr;
    int xDayt = x;
    int yDayt = 0;
    for(int i = dayOffset; i <= daysInYear; i++)
    {
	date = yearDayToDate(i, cd.year);

	// Stop at current month for current year.
	if((today.year == cd.year) &&
	   (today.month < date.month))
	    break;

	// Vertical space after each month.
	if((1 == date.day) && (dayOffset < i))
	    marginTop += cast(int)(width * 1.5);

	// Draw month name and day names at the beginning of each month.
	if((dayOffset == i) || (1 == date.day))
	{
	    char[] monthName = dateFormat("%B", date);

	    gc.setFont(getFont(FONT_SIZE_3, DWT.NONE));
	    extent = gc.stringExtent(monthName);
	    gc.drawText(monthName, x, marginTop, true);

	    marginTop += extent.y;

	    // Draw weekday names.
	    gc.setFont(getFont(FONT_SIZE_2, DWT.NONE));

	    int height = width / 6;
	    int xr = x;
	    int yr = marginTop;
	    int xt = x;
	    int yt = 0;
	    char[][] dayNames = rotateLeft(dayNames);

	    for(int j = 0; j < 7; j++)
	    {
		gc.drawRectangle(xr, yr, width, height);
		extent = gc.stringExtent(dayNames[j]);
		xt = xr + cast(int)round(width / 2) - cast(int)round(extent.x / 2);
		yt = yr + cast(int)round(height / 2) - cast(int)round(extent.y / 2);
		gc.drawText(dayNames[j], xt, yt, true);
		xr += width;
	    }

	    marginTop += height + 40;
	}

	// Draw day numbers.
	int height = width;
	xDayr += width;

	// Put first day in month under its belonging name.
	if((1 == date.day) || (i == dayOffset))
	{
	    int wd = Integer.toInt(dateFormat("%w", date));
	    wd = (0 == wd) ? 7 : wd;
	    xDayr = (width * wd) - width;
	}

	// New line every Monday.
	if(1 == Integer.toInt(dateFormat("%w", date)) && (1 != date.day))
	{
	    xDayr = x;
	    marginTop += height;
	}

	yDayr = marginTop - 40;
	gc.drawRectangle(xDayr, yDayr, width, height);
    }

    (cast(GridData)canvas.getLayoutData).heightHint = marginTop + 200;

    Composite c = canvas.getParent;
    ScrolledComposite sc = cast(ScrolledComposite)c.getParent;
    sc.setMinSize(c.computeSize(DWT.DEFAULT, DWT.DEFAULT));

    // Draw current month as the last month.
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
//	    Stdout("PAINT CONTROL").newline;

	    Rectangle rect = (cast(Canvas)event.widget).getBounds;
	    GC gc = event.gc;
	    gc.setBackground(event.display.getSystemColor(DWT.COLOR_RED));
	    gc.setForeground(event.display.getSystemColor(DWT.COLOR_BLACK));

	    Point size = this.cs.getSize;
	    int cx = 0;
	    int cy = 0;

  	    drawChainYear(this.cs);

	    return;

// 	    (cast(GridData)this.cs.getLayoutData).heightHint = cast(int)(cy * 1.05);

// 	    Composite c = this.cs.getParent;
// 	    ScrolledComposite sc = cast(ScrolledComposite)c.getParent;
//  	    sc.setMinSize(c.computeSize(DWT.DEFAULT, DWT.DEFAULT));

//	    c.layout;

	    // Draw beginning of chain to the end.
	    // Draw month's name.
// 	    char[] monthName = dateFormat("%B", cd.start);
// 	    Font font = getFont(FONT_SIZE_3, DWT.NONE);
// 	    Font font = new Font(Display.getCurrent,
// 				 new FontData(FONT_FACE_1,
// 					      FONT_SIZE_3,
// 					      DWT.NONE));
// 	    gc.setFont(font);
// 	    gc.drawText(monthName, cx, cy, true);

// 	    Point extent = gc.stringExtent(monthName);
// 	    cy = extent.y + 10;

// 	    // Draw weekday names.
// 	    font = new Font(Display.getCurrent,
// 			    new FontData(FONT_FACE_1,
// 					 FONT_SIZE_2,
// 					 DWT.NONE));
// 	    gc.setFont(font);

// 	    int width = size.x / 7;
// 	    int height = width / 6;
// 	    int xPos = 0;
// 	    int yPos = 0;
// 	    char[][] dayNames = rotateLeft(dayNames);

// 	    for(int i = 0; i < 7; i++)
// 	    {
// 		gc.drawRectangle(cx, cy, width, height);
// 		extent = gc.stringExtent(dayNames[i]);
// 		xPos = cx + cast(int)round(width / 2) - cast(int)round(extent.x / 2);
// 		yPos = cy + cast(int)round(height / 2) - cast(int)round(extent.y / 2);
// 		gc.drawText(dayNames[i], xPos, yPos, true);
// 		cx += width;
// 	    }


// 	    return;

// //	    int height = width;
// 	    for(int i = 0; i < 6; i++)
// 	    {
// 		for(int j = 0; j < 7; j++)
// 		{
// 		    gc.drawRectangle(cx, cy, width, height);
// 		    int date = Integer.toInt(Integer.toString(i) ~ Integer.toString(j));
// 		    Day day = Day.modify(cx, cy, width, height, date);
// 		    if(day.marked)
// 			day.mark(gc);
// 		    else
// 			drawDate(gc,
// 				 Integer.toString(date),
// 				 cx,
// 				 cy,
// 				 width,
// 				 height);

// 		    cx += width;
// 		}
// 		cx = 0;
// 		cy += height;
// 	    }

// 	    (cast(GridData)this.cs.getLayoutData).heightHint = cast(int)(cy * 1.05);

// 	    Composite c = this.cs.getParent;
// 	    ScrolledComposite sc = cast(ScrolledComposite)c.getParent;
//  	    sc.setMinSize(c.computeSize(DWT.DEFAULT, DWT.DEFAULT));
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

    addChainPaintListener(canvas);
    addChainClickListener(canvas);
    addChainScrollListener(canvas);
}