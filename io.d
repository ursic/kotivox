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

module io;

import tango.io.FilePath;
import tango.io.File;
import tango.io.FileSystem;
import Txt = tango.text.Util;
import tango.stdc.posix.unistd;
import tango.stdc.stringz;

import config;
import util;

private char[] configPath;
private char[][char[]] settings;


// Set root directory - application directory.
void setAppDirs()
{
    // Executable full path finding LINUX-only.
    int pid = getpid;
    char[200] lnk;
    char* link = toStringz(lnk);
    int len = readlink(toStringz("/proc/" ~ Integer.toString(pid) ~ "/exe"), link, 200);

    char[] result = fromStringz(link)[0..len];
    APP_DIR = result[0..Txt.rindex(result, "/", result.length) + 1];
    configPath = APP_DIR ~ CONFIG_DIR ~ "/" ~ CONFIG_FILE;
}


void saveConfig(char[] path = "")
{
    char[] configFilePath = path;
    if("" == configFilePath)
    {
	// Make output directory when nonexistent.
	FilePath outputDir = new FilePath(CONFIG_DIR);
	if(!outputDir.exists) outputDir.createFolder;

	configFilePath = configPath;
    }

    // Convert to output format.
    char[] outString;
    foreach(setting, value; settings)
	outString ~= setting ~ " " ~ value ~ "\n";

    (new File(configFilePath)).write(outString);
}


void readConfig(char[] path = "")
{
    char[] filePath = configPath;
    if(0 < path.length) filePath = path;

    if(!(new FilePath(filePath)).exists) return;

    settings = parseLines(cast(char[])(new File(filePath)).read);
}


void setConfig(char[] setting, char[] value)
{
    settings[setting] = value;
}


char[] getConfig(char[] setting)
{
    if(setting in settings)
	return settings[setting];
    else
	return null;
}