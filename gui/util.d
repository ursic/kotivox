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
public import dwt.events.ControlListener;
public import dwt.events.ControlEvent;
public import dwt.events.TraverseListener;
public import dwt.events.TraverseEvent;

import Txt = tango.text.Util;
import Integer = tango.text.convert.Integer;

public import config;


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
 	if(key in this.values) return this.values[key];
	return "";
    }
}


/*
  Return required font.
*/
Font getFont(int size, int style)
{
    Font font = new Font(Display.getCurrent,
			 new FontData(FONT_FACE_1,
				      size,
				      style));
    return font;
}


/*
  Set control font
*/
void setFont(Control control, int size, int style)
{
    Font font = new Font(Display.getCurrent,
			 new FontData(FONT_FACE_1,
				      size,
				      style));
    control.setFont(font);
}


Color getColor(char[] colorSetting)
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
  Return major shell group.
 */
Composite getShellGroup(char[] groupName)
{
    Shell shell = Display.getCurrent.getShells[0];
    Composite shellGroup;
    foreach(child; shell.getChildren)
    {
	Data data = cast(Data)child.getData;
	if(data && (groupName == data.get("name")))
	{
	    shellGroup = cast(Composite)child;
	    break;
	}
    }
    return shellGroup;
}