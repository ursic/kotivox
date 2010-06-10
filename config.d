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

/*****************************************************************************
 *
 * Default settings
 *
 *****************************************************************************/

module config;

public const APP_NAME = "Kotivox - Diary Program For Writing Beings";
public const CONFIG_DIR = "output";
public const CONFIG_FILE = "config.txt";

public const USER_DIR = "users";

public const LOGIN_WINDOW_MARGIN_TOP = 20;
public const LOGIN_WINDOW_MARGIN_LEFT = 40;
public const LOGIN_CONTROL_WIDTH = 200;
public const LOGIN_TEXT_INPUT_HEIGHT = 30;

public const WINDOW_HEIGHT = 520;
public const WINDOW_WIDTH = 810;

public const MAIN_WINDOW_LEFT_COLUMN_WIDTH = 240;
public const MAIN_WINDOW_CALENDAR_HEIGHT = 200;
public const MAIN_WINDOW_LEFT_COLUMN_BUTTON_HEIGHT = 40;
public const CATEGORY_CHECKBOX_WIDTH = 24;
public const CATEGORY_LABEL_WIDTH = 182;
public const CATEGORY_NAME_WIDTH = 180;
public const CATEGORY_LIST_HEIGHT = 300;

public const USER_DAY_FILE_EXTENSION = ".kt";
public const USER_CATEGORY_RANGES_FILE_EXTENSION = ".kcr";
public const USER_CATEGORIES_FILE = "catnames.kc";
public const USER_CATEGORY_BACKGROUND_COLOR_SETTING_NAME = "categoryBackgroundColor";
public const CATEGORY_LIST_BACKGROUND_COLOR = "239 239 239";
public const USER_CATEGORY_BACKGROUND_COLOR = "231 239 255";

public const USERNAME_TEXT = "Username:";
public const PASSWORD_TEXT = "Password:";
public const PASSWORD_AGAIN_TEXT = "Password again:";
public const OR_TEXT = "OR";
public const LOGIN_TEXT = "Login";
public const REGISTER_TEXT = "Register";
public const CANNOT_REGISTER = "I don't have enough data for registration.\nPlease enter username and matching passwords.";
public const REMOVE_TEXT = "REMOVE";
public const CATEGORY_TEXT = "Category";
public const CATEGORIES_TEXT = "Categories";
public const CLEAR_MENU_ITEM_TEXT = "Clear";
public const SAVE_CLOSE_TEXT = "Save && Close";

public const KEY_ENTER = 13;
public const KEY_KP_ENTER = 16777296;
public const KEY_F3 = 16777228;
public const KEY_ESC = 27;
public const KEY_E = 101;
public const KEY_F = 102;
public const KEY_K = 107;
public const KEY_R = 114;
public const KEY_S = 115;

public char[] APP_DIR;

public const char[] FONT_FACE_1 = "Sans";
public const FONT_SIZE_1 = 12;
public const FONT_SIZE_2 = 16;
public const FONT_SIZE_3 = 22;
public const FONT_SIZE_4 = 14;

public const SEARCH_RESULTS_LINE_HEIGHT = 16;
public const SEARCH_KEYWORDS_MIN_LENGTH = 3;

// Character length of prepended and appended text
// to single search result.
public const SEARCH_RESULT_LENGTH = 80;
// Character length of single search result page.
public const SEARCH_RESULT_PAGE_LENGTH = 1400;

public const TODAY_TEXT = "Today";
public const SEARCH_BOX_TEXT = "Search...";

public const INCREMENTAL_SEARCH_BOX_HEIGHT = 68;

public const NOTE_FILE_EXTENSION = ".kn";
public const NOTES_TEXT = "Notes";

public const CHAIN_FILE_EXTENSION = ".ksc";
public const CHAIN_TITLE_TEXT = "Seinfeld's chains";
public const CHAIN_TEXT = "Chain";
public const CHAIN_BACKROUNG_COLOR = "255 255 255";
public const CHAIN_LOCK_BUTTON_WIDTH = 30;
public const CHAIN_LOCK_TEXT = "LOCK";
public const CHAIN_UNLOCK_TEXT = "UNLOCK";
public const CHAIN_DESCRIPTION_LENGTH = 200;
public const LEFT_GROUP = "leftGroup";
public const RIGHT_GROUP = "rightGroup";
public const CHAIN_DESCRIPTION_INPUT_HEIGHT = 100;
public const CHAIN_BUTTON_SIZE = 26;

// Half thickness of mark stroke in percent.
public const CHAIN_MARK_STROKE_HALF_THICKNESS = 0.18;

public const CALENDAR_TOOLTIP_TEXT = "Right-click for today";
public const NEW_TOOLTIP_TEXT = "Right-click for new";
public const REMOVE_TOOLTIP_TEXT = "Right-click to remove";
