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

/*****************************************************************************
 *
 * Default settings
 *
 *****************************************************************************/

module config;

public const char[] APP_NAME = "Kotivox - Diary Program For Writing Beings";
public const char[] CONFIG_DIR = "output";
public const char[] CONFIG_FILE = "config.txt";

public const char[] USER_DIR = "users";

public const int LOGIN_WINDOW_MARGIN_TOP = 20;
public const int LOGIN_WINDOW_MARGIN_LEFT = 40;
public const int LOGIN_CONTROL_WIDTH = 200;
public const int LOGIN_TEXT_INPUT_HEIGHT = 30;

public const int WINDOW_HEIGHT = 520;
public const int WINDOW_WIDTH = 810;

public const int MAIN_WINDOW_LEFT_COLUMN_WIDTH = 240;
public const int MAIN_WINDOW_CALENDAR_HEIGHT = 200;
public const int MAIN_WINDOW_LEFT_COLUMN_BUTTON_HEIGHT = 40;
public const int CATEGORY_CHECKBOX_WIDTH = 24;
public const int CATEGORY_LABEL_WIDTH = 182;
public const int ADD_REMOVE_BUTTON_WIDTH = 49;
public const int ADD_REMOVE_BUTTON_HEIGHT = 34;
public const int CATEGORY_NAME_WIDTH = 180;
public const int CATEGORY_LIST_HEIGHT = 300;

public const char[] USER_DAY_FILE_EXTENSION = ".kt";
public const char[] USER_CATEGORY_RANGES_FILE_EXTENSION = ".kcr";
public const char[] USER_CATEGORIES_FILE = "catnames.kc";
public const char[] USER_CATEGORY_BACKGROUND_COLOR_SETTING_NAME = "categoryBackgroundColor";
public const char[] CATEGORY_LIST_BACKGROUND_COLOR = "239 239 239";
public const char[] USER_CATEGORY_BACKGROUND_COLOR = "231 239 255";

public const char[] USERNAME_TEXT = "Username:";
public const char[] PASSWORD_TEXT = "Password:";
public const char[] PASSWORD_AGAIN_TEXT = "Password again:";
public const char[] OR_TEXT = "OR";
public const char[] LOGIN_TEXT = "Login";
public const char[] REGISTER_TEXT = "Register";
public const char[] CANNOT_REGISTER = "I don't have enough data for registration.\nPlease enter username and matching passwords.";
public const char[] CATEGORIES_TEXT = "Categories";
public const char[] NEW_CATEGORY_TEXT = "New category";
public const char[] CLEAR_MENU_ITEM_TEXT = "Clear";
public const char[] ADD_REMOVE_TEXT = "+ −";
public const char[] ADD_REMOVE_BUTTON_TOOLTIP = "Add/Remove";
public const char[] SAVE_CLOSE_TEXT = "Save && Close";

public const int KEY_ENTER = 13;
public const int KEY_KP_ENTER = 16777296;
public const int KEY_ESC = 27;
public const int KEY_F = 102;
public const int KEY_R = 114;
public const int KEY_S = 115;

public char[] APP_DIR;

public char[] FONT_FACE_1 = "Sans";
public int FONT_SIZE_1 = 12;
public int FONT_SIZE_2 = 16;
public int FONT_SIZE_3 = 22;
public int FONT_SIZE_4 = 14;

public int SEARCH_RESULTS_LINE_HEIGHT = 16;
public int SEARCH_KEYWORDS_MIN_LENGTH = 3;

// Character length of prepended and appended text
// to single search result.
public int SEARCH_RESULT_LENGTH = 80;
// Character length of single search result page.
public int SEARCH_RESULT_PAGE_LENGTH = 1400;

public const char[] TODAY_TEXT = "Today";
public const char[] SEARCH_BOX_TEXT = "Search...";

public int INCREMENTAL_SEARCH_BOX_HEIGHT = 68;

public const char[] NOTE_FILE_EXTENSION = ".kn";
public const char[] NOTES_TEXT = "Notes";

public const char[] CHAIN_FILE_EXTENSION = ".ksc";
public const char[] CHAIN_TITLE_TEXT = "Seinfeld's chains";
public const char[] CHAIN_TEXT = "Chain";
public const char[] CHAIN_BACKROUNG_COLOR = "255 255 255";
public const int CHAIN_LOCK_BUTTON_WIDTH = 30;
public const char[] CHAIN_LOCK_TEXT = "LOCK";
public const char[] CHAIN_UNLOCK_TEXT = "UNLOCK";
public const int CHAIN_DESCRIPTION_LENGTH = 200;
public const char[] RIGHT_GROUP = "rightGroup";
public const int CHAIN_DESCRIPTION_INPUT_HEIGHT = 100;
public const int CHAIN_BUTTON_SIZE = 26;
// Half thickness of mark stroke in percent.
public const float CHAIN_MARK_STROKE_HALF_THICKNESS = 0.18;
