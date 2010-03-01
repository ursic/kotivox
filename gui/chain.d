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


private void addChainMouseListener(Canvas canvas)
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


private void addChainYearListener(Button button,
				  Date start,
				  Canvas canvas)
{
    button.addSelectionListener(new class(button, start, canvas) SelectionAdapter
    {
	Button btn;
	Date strt;
	Canvas cs;
	this(Button b, Date d, Canvas c)
	{
	    this.btn = button;
	    this.strt = start;
	    this.cs = canvas;
	}
	public void widgetSelected(SelectionEvent event)
	{
	    cd.year += Integer.toInt((cast(Data)this.btn.getData).get("increment"));

	    // Reset canvas for new chain year.
	    foreach(child; cs.getChildren) child.dispose;
	    this.cs.redraw;
	}
    });
}


/*
  Draw chain for given days in a year.
 */
private void drawChainYear(Date start, Canvas canvas)
{
    Stdout("DRAW CHAIN YEAR").newline;

    int[] chainDates = Storage.getChainDates(cd.id, cd.year);

    if(chainDates.length <= 0) return;

    GC gc = new GC(canvas);
    int x = 0;
    int y = 0;
    int width = canvas.getSize.x;

    // Draw year number in the middle.
    char[] yearStr = Integer.toString(cd.year);
    gc.setFont(getFont(FONT_SIZE_3, DWT.NONE));
    Point extent = gc.stringExtent(yearStr);
    gc.drawText(yearStr,
		(width / 2) - (extent.x / 2),
		y + 10,
		true);

    // Draw button to previous year.
    if(start.year < cd.year)
    {
	Button previousYear = new Button(canvas, DWT.ARROW | DWT.LEFT);
	char[] yearTxt = Integer.toString(cd.year - 1);
	previousYear.setBounds(x + 10,
			       y + 10,
			       CHAIN_BUTTON_SIZE,
			       CHAIN_BUTTON_SIZE);
// 	Stdout("drew button for", cd.year - 1).newline;
// 	Stdout("text dims", x + 10 + CHAIN_BUTTON_SIZE + 10).newline;
	gc.setFont(getFont(FONT_SIZE_2, DWT.NONE));
	gc.drawText(yearTxt,
		    x + 10 + CHAIN_BUTTON_SIZE + 10,
		    y + 12,
		    true);
	previousYear.setData(new Data("increment", "-1"));
	addChainYearListener(previousYear,
			     start,
			     canvas);
    }

    // Draw button to next year.
    if(cd.year < today.year)
    {
	Button nextYear = new Button(canvas, DWT.ARROW | DWT.RIGHT);
	char[] yearTxt = Integer.toString(cd.year + 1);
	nextYear.setBounds(width - CHAIN_BUTTON_SIZE - 10,
			   y + 10,
			   CHAIN_BUTTON_SIZE,
			   CHAIN_BUTTON_SIZE);
	gc.setFont(getFont(FONT_SIZE_2, DWT.NONE));
	gc.drawText(yearTxt,
		    width - CHAIN_BUTTON_SIZE - 10 - 10 - gc.stringExtent(yearTxt).x,
		    y + 12,
		    true);
	nextYear.setData(new Data("increment", "+1"));
	addChainYearListener(nextYear,
			     start,
			     canvas);
    }

    // Draw start if chain starts given year.
    int dayOffset = 0;
    if(start.year == cd.year)
	dayOffset = Integer.toInt(dateFormat("%j", start));

    int daysInYear = (new Gregorian).getDaysInYear(cd.year, Gregorian.AD_ERA);

//     for(int i = 1 + dayOffset; i <= daysInYear; i++)
//     {
	
//     }

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
	    foreach(child; this.cs.getChildren) child.dispose;

	    Rectangle rect = (cast(Canvas)event.widget).getBounds;
	    GC gc = event.gc;
	    gc.setBackground(event.display.getSystemColor(DWT.COLOR_RED));
	    gc.setForeground(event.display.getSystemColor(DWT.COLOR_BLACK));

	    Point size = this.cs.getSize;
	    int cx = 0;
	    int cy = 0;

	    Date start = Storage.getChainStartDate(cd.id);
//	    int[] chainYears = Storage.getChainDates(this.id, today.year);
//	    int[] chainDates = Storage.getChainDates(this.id, 2009);

	    // Draw this year's chains.
//	    if(0 < chainDates.length)
//	    cd.year = 2009;
	    drawChainYear(start, this.cs);

//  	    drawChainYear(start, 2008, canvas);

	    return;

// 	    if(start.year < today.year)
// 		Stdout("draw link to previous year").newline;

	    // Draw beginning of chain to the end.
	    // Draw month's name.
	    char[] monthName = dateFormat("%B", start);
	    Font font = getFont(FONT_SIZE_3, DWT.NONE);
// 	    Font font = new Font(Display.getCurrent,
// 				 new FontData(FONT_FACE_1,
// 					      FONT_SIZE_3,
// 					      DWT.NONE));
	    gc.setFont(font);
	    gc.drawText(monthName, cx, cy, true);

	    Point extent = gc.stringExtent(monthName);
	    cy = extent.y + 10;

	    // Draw weekday names.
	    font = new Font(Display.getCurrent,
			    new FontData(FONT_FACE_1,
					 FONT_SIZE_2,
					 DWT.NONE));
	    gc.setFont(font);

	    int width = size.x / 7;
	    int height = width / 6;
	    int xPos = 0;
	    int yPos = 0;
	    char[][] dayNames = rotateLeft(dayNames);

	    for(int i = 0; i < 7; i++)
	    {
		gc.drawRectangle(cx, cy, width, height);
		extent = gc.stringExtent(dayNames[i]);
		xPos = cx + cast(int)round(width / 2) - cast(int)round(extent.x / 2);
		yPos = cy + cast(int)round(height / 2) - cast(int)round(extent.y / 2);
		gc.drawText(dayNames[i], xPos, yPos, true);
		cx += width;
	    }



// 	    int dayDiff = Integer.toInt(dateFormat("%j", today)) - Integer.toInt(dateFormat("%j", start)) + 1;
// 	    Stdout("day diff", dayDiff).newline;
// 	    (new Gregorian).getDaysInMonth(calendar.getYear,
// 					   calendar.getMonth + 1,
// 					   Gregorian.AD_ERA);
	    

// 	    for(int i = start.day; i <= dayDiff; i++)
// 	    {
// 		Stdout("DRAWING DAY", i).newline;
// 	    }

	    return;

//	    int height = width;
	    for(int i = 0; i < 6; i++)
	    {
		for(int j = 0; j < 7; j++)
		{
		    gc.drawRectangle(cx, cy, width, height);
		    int date = Integer.toInt(Integer.toString(i) ~ Integer.toString(j));
		    Day day = Day.modify(cx, cy, width, height, date);
		    if(day.marked)
			day.mark(gc);
		    else
			drawDate(gc,
				 Integer.toString(date),
				 cx,
				 cy,
				 width,
				 height);

		    cx += width;
		}
		cx = 0;
		cy += height;
	    }

	    (cast(GridData)this.cs.getLayoutData).heightHint = cast(int)(cy * 1.05);

	    Composite c = this.cs.getParent;
	    ScrolledComposite sc = cast(ScrolledComposite)c.getParent;
 	    sc.setMinSize(c.computeSize(DWT.DEFAULT, DWT.DEFAULT));
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
    addChainMouseListener(canvas);
}