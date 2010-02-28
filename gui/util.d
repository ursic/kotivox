module gui.util;

public import dwt.DWT;
public import dwt.widgets.Display;
public import dwt.widgets.Shell;
public import dwt.graphics.Rectangle;
public import dwt.graphics.Font;
public import dwt.graphics.FontData;
public import dwt.graphics.Color;
public import dwt.graphics.TextLayout;
public import dwt.graphics.GC;
public import dwt.layout.FillLayout;
public import dwt.layout.GridData;
public import dwt.layout.GridLayout;
public import dwt.widgets.Button;
public import dwt.widgets.Composite;
public import dwt.widgets.Canvas;
public import dwt.custom.ScrolledComposite;
public import dwt.widgets.Control;
public import dwt.widgets.Group;
public import dwt.widgets.Decorations;
public import dwt.widgets.Text;
public import dwt.custom.StyledText;
public import dwt.custom.ST;
public import dwt.custom.StyleRange;
public import dwt.widgets.Button;
public import dwt.widgets.Label;
public import dwt.widgets.Event;
public import dwt.widgets.Listener;
public import dwt.widgets.DateTime;
public import dwt.widgets.Menu;
public import dwt.widgets.MenuItem;
public import dwt.widgets.Link;
public import dwt.widgets.ScrollBar;
public import dwt.events.ShellAdapter;
public import dwt.events.SelectionAdapter;
public import dwt.events.MenuAdapter;
public import dwt.events.SelectionEvent;
public import dwt.events.ShellEvent;
public import dwt.events.ModifyListener;
public import dwt.events.MenuDetectListener;
public import dwt.events.MenuDetectEvent;
public import dwt.events.MouseEvent;
public import dwt.events.MouseAdapter;
public import dwt.events.MouseWheelListener;
public import dwt.events.MenuDetectEvent;
public import dwt.custom.ExtendedModifyEvent;
public import dwt.custom.ExtendedModifyListener;
public import dwt.events.MenuListener;
public import dwt.events.KeyListener;
public import dwt.events.KeyEvent;
public import dwt.events.MenuEvent;
public import dwt.events.FocusListener;
public import dwt.events.FocusEvent;
public import dwt.events.PaintListener;
public import dwt.events.PaintEvent;


/*
  Per-widget data.
 */
public class Data
{
    private char[][char[]] values;

    this(char[] key, char[] value)
    {
	this.values[key] = value;
    }

    public char[] get(char[] key)
    {
 	if(key in this.values)
 	    return this.values[key];

	return "";
    }
}