module gui.chain;

import tango.stdc.math;

public import gui.util;
import util;
import storage;

import tango.io.Stdout;


// Half thickness of stroke in percent.
float halfThickness = 0.18;


int[] strokeLeft(int x, int y, int width, int height)
{
    return [x + 1, y + cast(int)round(height * halfThickness),
	    x + 1, y + 1,
	    x + cast(int)round(width * halfThickness) + 1, y + 1,
	    x + width, y + height - cast(int)round(height * halfThickness),
	    x + width, y + height,
	    x + width - cast(int)round(width * halfThickness), y + height];
}


int[] strokeRight(int x, int y, int width, int height)
{
    return [x + width - cast(int)round(width * halfThickness), y + 1,
	    x + width, y + 1,
	    x + width, y + cast(int)round(height * halfThickness),
	    x + cast(int)round(width * halfThickness), y + height,
	    x + 1, y + height,
	    x + 1, y + height - cast(int)round(height * halfThickness)];
}


void drawDate(GC gc, char[] str, int x, int y, int width, int height, bool center = true)
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


void addChainMouseListener(Canvas canvas, int chainID)
{
    canvas.addMouseListener(new class(canvas, chainID) MouseAdapter
    {
	Canvas cs;
	int id;
	this(Canvas c, int cid)
	{
	    this.cs = canvas;
	    this.id = chainID;
	}
	public void mouseDown(MouseEvent event)
        {
	    if(Storage.isChainLocked(this.id)) return;

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


void addChainPaintListener(Canvas canvas, int chainID)
{
    canvas.addPaintListener(new class(canvas, chainID) PaintListener
    {
	Canvas cs;
	int id;
	this(Canvas c, int cid)
	{
	    this.cs = canvas;
	    this.id = chainID;
	}
	public void paintControl(PaintEvent event)
        {
	    Rectangle rect = (cast(Canvas)event.widget).getBounds;
	    GC gc = event.gc;
	    gc.setBackground(event.display.getSystemColor(DWT.COLOR_RED));
	    gc.setForeground(event.display.getSystemColor(DWT.COLOR_BLACK));
	    Point size = this.cs.getSize;
	    int cx = 0;
	    int cy = 0;

	    auto start = Storage.getChainStartDate(this.id);
	    Stdout("dates", Storage.getChainDates(this.id)).newline;

	    Stdout("date", start.day, start.month, start.year).newline;

	    if(start.year < today.year)
		Stdout("draw link to previous year").newline;

	    // Draw beginning of chain to the end.
	    // Draw month's name.
	    char[] monthName = dateFormat("%B", start);
	    Font font = new Font(Display.getCurrent,
				 new FontData(FONT_FACE_1,
					      FONT_SIZE_3,
					      DWT.NONE));
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
	    char[] w = "Wednesday";
	    extent = gc.stringExtent(w);
	    int xPos = 0;
	    int yPos = 0;
//	    static Date
	    for(int i = 0; i < 7; i++)
	    {
		gc.drawRectangle(cx, cy, width, height);
		xPos = cx + cast(int)round(width / 2) - cast(int)round(extent.x / 2);
		yPos = cy + cast(int)round(height / 2) - cast(int)round(extent.y / 2);
		gc.drawText("Wednesday", xPos, yPos, true);
		cx += width;
	    }

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
void addChainDescriptionListener(Text text, int chainID)
{
    text.addModifyListener(new class(text, chainID) ModifyListener
    {
	Text txt;
	int id;
	this(Text t, int cid)
	{
	    this.txt = text;
	    this.id = chainID;
	}
	public void modifyText(ModifyEvent event)
	{
	    Storage.chainDesc(this.id, this.txt.getText);
	}
    });
}


/*
  Menu option for locking and unlocking a chain.
*/
void addLockMenuOption(Text text, int chainID)
{
    Menu menu = text.getMenu;

    char[] lockStr = CHAIN_LOCK_TEXT;
    if(Storage.isChainLocked(chainID)) lockStr = CHAIN_UNLOCK_TEXT;

    MenuItem item = new MenuItem(menu, DWT.NONE);
    item.setText(lockStr);

    item.addSelectionListener(new class(item, text, chainID) SelectionAdapter
    {
	MenuItem option;
	Text txt;
	int id;
	this(MenuItem mi, Text t, int id)
	{
	    this.option = item;
	    this.txt = text;
	    this.id = chainID;
	}
	public void widgetSelected(SelectionEvent event)
	{
	    // Lock chain.
	    if(CHAIN_LOCK_TEXT == this.option.getText)
	    {
		Storage.lockChain(this.id);
		this.option.setText(CHAIN_UNLOCK_TEXT);
		this.txt.setEditable(false);
		// Cosmetics: by drawing it afresh we get rid of
		// blinking caret.
		drawChainWindow(this.id);
	    }
	    // Unlock chain.
	    else
	    {
		Storage.unlockChain(this.id);
		this.option.setText(CHAIN_LOCK_TEXT);
		this.txt.setEditable(true);
	    }
	}
    });
}


void drawChainWindow(int id)
{
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
    text.setText(Storage.chainDesc(id));
    text.setBackground(getColor(CATEGORY_LIST_BACKGROUND_COLOR));
    setFont(text, FONT_SIZE_3, DWT.NONE);
    if(Storage.isChainLocked(id)) text.setEditable(false);
    addChainDescriptionListener(text, id);
    addLockMenuOption(text, id);

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

    addChainPaintListener(canvas, id);
    addChainMouseListener(canvas, id);
}