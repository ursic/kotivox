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

module auth;

import tango.io.FilePath;
import tango.io.Stdout;
import tango.core.Traits;
import tango.math.IEEE;
import tango.io.digest.Sha512;
import Integer = tango.text.convert.Integer;

import config;
import io;
import storage;


private class Validator
{
    // checks whether given user exists
    static private bool usernameExists(char[] username)
    {
	char[] userDirPath = APP_DIR ~ USER_DIR ~ "/" ~ usernameToIdent(username);
	FilePath userDir = new FilePath(userDirPath);

	if(!userDir.exists)
	    return false;

	return true;
    }


    static private bool validateUserData(char[][] userData, out char[] errorMsg)
    {
	char[] username = userData[0];
	char[] password1 = userData[1];
	char[] password2 = userData[2];

	// do passwords match?
	if(password1 != password2)
	{
	    errorMsg = "Please enter matching passwords.";
	    return false;
	}

	// is username taken?
	if(usernameExists(username))
	{
	    errorMsg = "Username " ~ username ~ " is already taken.\nPlease choose another one.";
	    return false;
	}

	// username should be 3 or more characters in length
	if(username.length < 3)
	{
	    errorMsg = "Username is too short.\nPlease make it at least 3 characters long.";
	    return false;
	}

	// username can be at most 100 characters long
	if(100 < username.length)
	{
	    errorMsg = "Username is too long.\nPlease make it 100 characters or shorter.";
	    return false;
	}

	// password must be at least 10 characters long
	if(password1.length < 10)
	{
	    errorMsg = "Password is too short.\nPlease make it at least 10 characters long.";
	    return false;
	}

	// password can be at most 100 characters long
	if(100 < password1.length)
	{
	    errorMsg = "Password is too long.\nPlease make it 100 characters or shorter.";
	    return false;
	}

	// password must contain at least 3 numbers
	int i = 0;
	foreach(char chr; password1)
	{
	    if(chr >= '0' && chr <= '9')
		i++;
	}

	if(i < 3)
	{
	    errorMsg = "Password is inadequate.\nPlease make it contain 3 numbers or more.";
	    return false;
	}
	    
	// password must contain at least 4 letters
	if((password1.length - i) < 4)
	{
	    errorMsg = "Password is inadequate.\nPlease make it contain 4 letters or more.";
	    return false;
	}
	
	return true;
    }
}


public class Auth
{
    static private bool userLoggedIn = false;
    static private char[] userDirPath;
    static private char[] userConfig;
    static private char[] cipherKey;

    static public bool login(char[][] userData, out char[] errorMsg)
    {
	char[] username = userData[0];
	
	// does given user exist?
	if(!Validator.usernameExists(username))
	{
	    errorMsg = "I cannot find user " ~ username ~ ".\nPlease enter registered username.";
	    return false;
	}

	// does user's ident exist?
	char[] ident = usernameToIdent(username);
	userDirPath = APP_DIR ~ USER_DIR ~ "/" ~ ident ~ "/";
	userConfig = userDirPath ~ "config.txt";

	readConfig(userConfig);

	// set default category background color if nonexistent
	if(!getConfig(USER_CATEGORY_BACKGROUND_COLOR_SETTING_NAME))
	  setConfig(USER_CATEGORY_BACKGROUND_COLOR_SETTING_NAME,
		    USER_CATEGORY_BACKGROUND_COLOR);
	
	// password idents have to match for log in
	char[] password = userData[1];
	char[] passwordIdent1 = getConfig("ident");
	char[] passwordIdent2 = passwordToIdent(password);

	// login the user if password digests match
	if(passwordIdent1 == passwordIdent2)
	{
	    userLoggedIn = true;
	    // decrypt user data
	    Storage.loadUserData;
	}
	else
	    errorMsg = "Password seems to be incorrect.\nPlease enter correct password.";

	return isUserLoggedIn;
    }


    static private char[] passwordToIdent(char[] password)
    {
	Sha512 digest = new Sha512;
	digest.update(cast(ubyte[])password);
	this.cipherKey = digest.hexDigest();
	digest.update(cast(ubyte[])(password ~ this.cipherKey));
	return digest.hexDigest();
    }


    static private void addNewUser(char[][] userData)
    {
	char[] ident = usernameToIdent(userData[0]);
	char[] usersDirPath = APP_DIR ~ USER_DIR;

	// create root user dir if nonexistent
	FilePath usersDir = new FilePath(usersDirPath);
	if(!usersDir.exists)
	  usersDir.createFolder;

	char[] userDirPath = APP_DIR ~ USER_DIR ~ "/" ~ ident ~ "/";
	userConfig = userDirPath ~ "config.txt";

	FilePath userDir = new FilePath(userDirPath);
	// create new user dir
	userDir.createFolder;

	// save password ident to configuration file
	setConfig("ident", passwordToIdent(userData[1]));
	saveConfig(userConfig);
    }


    static public bool register(char[][] userData, out char[] errorMsg)
    {
	char[] msg;
	if(Validator.validateUserData(userData, errorMsg))
	{
	    addNewUser(userData);

	    // log in the new user
	    readConfig(userConfig);
	    char[] loginStatus;
	    login(userData, loginStatus);
	    return true;
	}

	return false;
    }


    static public bool isUserLoggedIn()
    {
	return userLoggedIn;
    }
}


// converts given username to user ident
char[] usernameToIdent(char[] username)
{
  Sha512 digest = new Sha512;
  digest.update(cast(ubyte[])username);
  return digest.hexDigest()[0..8];
}