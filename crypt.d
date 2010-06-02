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

module crypt;

import tango.stdc.stringz;

extern (C) int encrypt_file(char *infile, char *outfile, char *tmpkey);
extern (C) int decrypt_file(char *infile, char *outfile, char *tmpkey);
extern (C) int encrypt_from_string(char *instring, char *outfile, char *tmpkey);
extern (C) char* decrypt_to_string(char *infile, char *outstring, char *tmpkey);


/*
  Encrypt _infile using _key and AES cipher
  and write ciphered data into _outfile
 */
void k_encrypt_file(char[] _infile, char[] _outfile, char[] _key)
{
    char *key = toStringz(_key);
    char *infile = toStringz(_infile);
    char *outfile = toStringz(_outfile);

    encrypt_file(infile, outfile, key);
}


/*
  Decrypt _cipherfile using _key and AES cipher
  and write plaintext data into _outfile
 */
void k_decrypt_file(char[] _cipherfile, char[] _outfile, char[] _key)
{
    char *key = toStringz(_key);
    char *cipherfile = toStringz(_cipherfile);
    char *outfile = toStringz(_outfile);

    decrypt_file(cipherfile, outfile, key);
}


/*
  Encrypt _instring using _key and AES cipher
  and write ciphered data into _outfile
 */
void k_encrypt_from_string(char[] _instring, char[] _outfile, char[] _key)
{
    char *key = toStringz(_key);
    char *instring = toStringz(_instring);
    char *outfile = toStringz(_outfile);

    encrypt_from_string(instring, outfile, key);
}


/*
  Decrypt _infile using _key and AES cipher
  into string and point _oustring pointer to decrypted string
  Return decrypted string
 */
char[] k_decrypt_to_string(char[] _infile, char[] _key)
{
    char* infile = toStringz(_infile);
    char* _outstring;
    char* key = toStringz(_key);

    char[] textOut;
    char[] text = fromStringz(decrypt_to_string(infile, _outstring, key));
    foreach(char c; text) textOut ~= c;

    return textOut;
}