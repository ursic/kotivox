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

#include <stdio.h>
#include <math.h>
#include "headers/tomcrypt.h"

/*
  Encrypt infile with tmpkey using AES cipher and write
  ciphered data into outfile
  Return 0 when OK -1 on error
 */
int encrypt_file(char *infile, char *outfile, char *tmpkey);

/*
  Decrypt ciphered infile with using AES cipher
  and write result into outfile
  Return 0 when OK -1 on error
 */
int decrypt_file(char *infile, char *outfile, char *tmpkey);

/*
  Encrypt string instring with tmpkey using AES cipher
  and write ciphered data into outfile
  Return 0 when OK -1 on error
 */
int encrypt_from_string(char *instring, char *outfile, char *tmpkey);

/*
  Decrypt ciphered file infile with tmpkey using AES cipher
  and point outstringp to decyrpted string
  Return pointer to deciphered string
 */
char* decrypt_to_string(const char *infile, char *outstringp, char *tmpkey);


int encrypt_file(char *infile,
		 char *outfile,
		 char *tmpkey)
{
    unsigned char plaintext[512], ciphertext[512];
    unsigned char key[MAXBLOCKSIZE], IV[MAXBLOCKSIZE];
    unsigned char inbuf[512];
    symmetric_CTR ctr;
    unsigned long outlen, ivsize, x, size_in;
    int cipher_idx, hash_idx, key_size;
    int errno;
    prng_state prng;
    int size_buf = 512;

    char *hash = "sha256";
    char *cipher = "aes";

    FILE *fin = fopen(infile, "r");
    FILE *fout = fopen(outfile, "wb");

    /* register hash */
    if (register_hash(&sha256_desc) == -1) {
	printf("Error registering SHA256\n");
	return -1;
    }

    /* register yarrow */
    if (register_prng(&yarrow_desc) == -1) {
	printf("Error registering yarrow PRNG\n");
	return -1;
    }

    /* register sprng */
    if (register_prng(&sprng_desc) == -1) {
	printf("Error registering sprng PRNG\n");
	return -1;
    }

    /* register aes */
    if ((errno = register_cipher(&aes_desc)) == -1)
    {
	printf("Error registering cipher\n");
	return -1;
    }

    hash_idx = find_hash(hash);
    key_size = hash_descriptor[hash_idx].hashsize;

    /* generate hash key */
    outlen = sizeof(key);
    if ((errno = hash_memory(hash_idx,
			     tmpkey,
			     strlen((char *)tmpkey),
			     key,
			     &outlen)
	    ) != CRYPT_OK)
    {
	printf("Error hashing key: %s\n", error_to_string(errno));
	return -1;
    }

    /* Setup yarrow for random bytes for IV */
    if ((errno = rng_make_prng(128,
			       find_prng("yarrow"),
			       &prng,
			       NULL)
	    ) != CRYPT_OK)
    {
	printf("Error setting up PRNG, %s\n", error_to_string(errno));
	return -1;
    }      

    cipher_idx = find_cipher(cipher);
    ivsize = cipher_descriptor[cipher_idx].block_length;

    // Get initial vector from pseudo-random generated number
    x = yarrow_read(IV, ivsize, &prng);
    if (x != ivsize)
    {
	printf("Error reading PRNG for IV required.\n");
	return -1;
    }

    // Write initial vector at the start of the ciphered file
    if (fwrite(IV, 1, ivsize, fout) != ivsize)
    {
	printf("Error writing IV to output.\n");
	return -1;
    }

    /* start up CTR mode */
    if ((errno = ctr_start(
	     cipher_idx,
	     IV,
	     key,
	     key_size,
	     0,
	     CTR_COUNTER_LITTLE_ENDIAN,
	     &ctr)
	    ) != CRYPT_OK)
    {
	printf("ctr_start error: %s\n", error_to_string(errno));
	return -1;
    }

    do
    {
	// read a chunk of plaintext data from input file fin
	size_in = fread(inbuf, 1, sizeof(inbuf), fin);

	// encrypt the chunk and buffer it into ciphertext
	if ((errno = ctr_encrypt(inbuf, /* plaintext */
				 ciphertext, /* ciphertext */
				 size_in,
				 &ctr)
		) != CRYPT_OK)
	{
	    printf("ctr_encrypt error: %s\n", error_to_string(errno));
	    return -1;
	}

	// append content from ciphered buffer to ciphered file
	if(fwrite(ciphertext, 1, size_in, fout) != size_in)
	{
            printf("Error writing to output.\n");
            return -1;
	}

    } while(size_in == sizeof(inbuf));

    fclose(fin);
    fclose(fout);

    /* terminate the stream */
    if ((errno = ctr_done(&ctr)) != CRYPT_OK)
    {
	printf("ctr_done error: %s\n", error_to_string(errno));
	return -1;
    }

    /* clear up and return */
    zeromem(key, sizeof(key));
    zeromem(&ctr, sizeof(ctr));

    return 0;
}


int decrypt_file(char *infile,
		 char *outfile,
		 char *tmpkey)
{
    unsigned char plaintext[512], ciphertext[512];
    unsigned char key[MAXBLOCKSIZE], IV[MAXBLOCKSIZE];
    unsigned char inbuf[512];
    symmetric_CTR ctr;
    unsigned long outlen, ivsize, x, size_in;
    int cipher_idx, hash_idx, key_size;
    int errno;
    prng_state prng;
    int size_buf = 512;

    char *hash = "sha256";
    char *cipher = "aes";

    FILE *fin = fopen(infile, "rb");
    FILE *fout = fopen(outfile, "w");

    /* register hash */
    if (register_hash(&sha256_desc) == -1) {
	printf("Error registering SHA256\n");
	return -1;
    }

    /* register aes */
    if ((errno = register_cipher(&aes_desc)) == -1)
    {
	printf("Error registering cipher\n");
	return -1;
    }

    hash_idx = find_hash(hash);
    key_size = hash_descriptor[hash_idx].hashsize;

    /* make hash key */
    outlen = sizeof(key);
    if ((errno = hash_memory(hash_idx,
			     tmpkey,
			     strlen((char *)tmpkey),
			     key,
			     &outlen)
	    ) != CRYPT_OK)
    {
	printf("Error hashing key: %s\n", error_to_string(errno));
	return -1;
    }

    cipher_idx = find_cipher(cipher);
    ivsize = cipher_descriptor[cipher_idx].block_length;

    /* Need to read in IV */
    if(fread(IV, 1, ivsize, fin) != ivsize)
    {
	printf("Error reading IV from input.\n");
	return -1;
    }

    /* start up CTR mode */
    if ((errno = ctr_start(
	     cipher_idx,
	     IV,
	     key,
	     key_size,
	     0,
	     CTR_COUNTER_LITTLE_ENDIAN,
	     &ctr)
	    ) != CRYPT_OK)
    {
	printf("ctr_start error: %s\n", error_to_string(errno));
	return -1;
    }

    do
    {
	// read a chunk of ciphered data
	size_in = fread(inbuf, 1, sizeof(inbuf), fin);

	// decrypt the chunk and buffer it into plaintext
	if ((errno = ctr_decrypt(inbuf, /* plaintext */
				 plaintext, /* ciphertext */
				 size_in,
				 &ctr)
		) != CRYPT_OK)
	{
	    printf("ctr_encrypt error: %s\n", error_to_string(errno));
	    return -1;
	}

	// write plaintext buffer content into file fout
	if(fwrite(plaintext, 1, size_in, fout) != size_in)
	{
            printf("Error writing to file.\n");
            return 0;
	}

    } while( size_in == sizeof(inbuf));

    fclose(fin);
    fclose(fout);

    /* terminate the stream */
    if ((errno = ctr_done(&ctr)) != CRYPT_OK)
    {
	printf("ctr_done error: %s\n", error_to_string(errno));
	return -1;
    }

    /* clear up and return */
    zeromem(key, sizeof(key));
    zeromem(&ctr, sizeof(ctr));

    return 0;
}


int encrypt_from_string(char *instring,
			char *outfile,
			char *tmpkey)
{
    unsigned char plaintext[512], ciphertext[512];
    unsigned char key[MAXBLOCKSIZE], IV[MAXBLOCKSIZE];
    unsigned char inbuf[512];
    symmetric_CTR ctr;
    unsigned long outlen, ivsize, x, size_in;
    int cipher_idx, hash_idx, key_size;
    int errno;
    prng_state prng;
    int size_buf = 512;

    char *hash = "sha256";
    char *cipher = "aes";

    FILE *fout = fopen(outfile, "wb");

    /* register hash */
    if (register_hash(&sha256_desc) == -1) {
	printf("Error registering SHA256\n");
	return -1;
    }

    /* register yarrow */
    if (register_prng(&yarrow_desc) == -1) {
	printf("Error registering yarrow PRNG\n");
	return -1;
    }

    /* register sprng */
    if (register_prng(&sprng_desc) == -1) {
	printf("Error registering sprng PRNG\n");
	return -1;
    }

    /* register aes */
    if ((errno = register_cipher(&aes_desc)) == -1)
    {
	printf("Error registering cipher\n");
	return -1;
    }

    hash_idx = find_hash(hash);
    key_size = hash_descriptor[hash_idx].hashsize;

    /* make hash key */
    outlen = sizeof(key);
    if ((errno = hash_memory(hash_idx,
			     tmpkey,
			     strlen((char *)tmpkey),
			     key,
			     &outlen)
	    ) != CRYPT_OK)
    {
	printf("Error hashing key: %s\n", error_to_string(errno));
	return -1;
    }

    /* Setup yarrow for random bytes for IV */
    if ((errno = rng_make_prng(128,
			       find_prng("yarrow"),
			       &prng,
			       NULL)
	    ) != CRYPT_OK)
    {
	printf("Error setting up PRNG, %s\n", error_to_string(errno));
	return -1;
    }      

    cipher_idx = find_cipher(cipher);
    ivsize = cipher_descriptor[cipher_idx].block_length;

    // Get initial vector from pseudo-random generated number
    x = yarrow_read(IV, ivsize, &prng);
    if (x != ivsize)
    {
	printf("Error reading PRNG for IV required.\n");
	return -1;
    }

    // Write initial vector at the start of the ciphered file
    if (fwrite(IV, 1, ivsize, fout) != ivsize)
    {
	printf("Error writing IV to output.\n");
	return -1;
    }

    /* start up CTR mode */
    if ((errno = ctr_start(
	     cipher_idx,
	     IV,
	     key,
	     key_size,
	     0,
	     CTR_COUNTER_LITTLE_ENDIAN,
	     &ctr)
	    ) != CRYPT_OK)
    {
	printf("ctr_start error: %s\n", error_to_string(errno));
	return -1;
    }

    // chop instring and encrypt it one buffer chunk at a time
    size_in = strlen(instring);
    int num_chunks = floor(size_in  / size_buf);
    int rest = size_in - (num_chunks * size_buf); /* remaining chunk of characters, shorter than inbuf */

    int round = 0;
    int limit; /* current number of characters in buffer */
    int i = 0; /* counter for instring traversal, always incremented */
    int j = 0; /* counter for temporary inbuf buffer, reset on each round */
    for(round; round < num_chunks + 1; round++)
    {
	if(i < num_chunks)
	    limit = size_buf;

	if(round == num_chunks)
	    limit = rest;

	j = 0;
	for(i, j; i < limit, j < size_buf; i++, j++)
	    inbuf[j] = instring[i];

	inbuf[size_buf] = '\0';

	// encrypt the chunk and buffer it into ciphertext
	if ((errno = ctr_encrypt(inbuf, /* plaintext */
				 ciphertext, /* ciphertext */
				 size_buf,
				 &ctr)
		) != CRYPT_OK)
	{
	    printf("ctr_encrypt error: %s\n", error_to_string(errno));
	    return -1;
	}

	// append content from ciphered buffer to ciphered file
	if(fwrite(ciphertext, 1, limit, fout) != limit)
	{
            printf("Error writing to output.\n");
            return -1;
	}
    }

    fclose(fout);

    /* terminate the stream */
    if ((errno = ctr_done(&ctr)) != CRYPT_OK)
    {
	printf("ctr_done error: %s\n", error_to_string(errno));
	return -1;
    }

    /* clear up and return */
    zeromem(key, sizeof(key));
    zeromem(&ctr, sizeof(ctr));

    return 0;
}


char* decrypt_to_string(const char *infile,
			char *outstringp,
			char *tmpkey)
{
    unsigned char plaintext[512], ciphertext[512];
    unsigned char key[MAXBLOCKSIZE], IV[MAXBLOCKSIZE];
    unsigned char inbuf[512];
    symmetric_CTR ctr;
    unsigned long outlen, ivsize, x, size_in;
    int cipher_idx, hash_idx, key_size;
    int errno;
    prng_state prng;
    int size_buf = 512;

    char *hash = "sha256";
    char *cipher = "aes";

    FILE *fin = fopen(infile, "rb");

    fseek(fin, 0L, SEEK_END);
    int size_f = ftell(fin);
    rewind(fin);
    char outstring[(int)(size_f + floor(size_f * 0.5))];

    outstring[0] = '\0';

    /* register hash */
    if (register_hash(&sha256_desc) == -1) {
	printf("Error registering SHA256\n");
    }

    /* register aes */
    if ((errno = register_cipher(&aes_desc)) == -1)
    {
	printf("Error registering cipher\n");
    }

    hash_idx = find_hash(hash);
    key_size = hash_descriptor[hash_idx].hashsize;


    /* make hash key */
    outlen = sizeof(key);
    if ((errno = hash_memory(hash_idx,
			     tmpkey,
			     strlen((char *)tmpkey),
			     key,
			     &outlen)
	    ) != CRYPT_OK)
    {
	printf("Error hashing key: %s\n", error_to_string(errno));
    }

    cipher_idx = find_cipher(cipher);
    ivsize = cipher_descriptor[cipher_idx].block_length;

    /* Need to read in IV */
    if(fread(IV, 1, ivsize, fin) != ivsize)
    {
	printf("Error reading IV from input.\n");
    }

    /* start up CTR mode */
    if ((errno = ctr_start(
	     cipher_idx,
	     IV,
	     key,
	     key_size,
	     0,
	     CTR_COUNTER_LITTLE_ENDIAN,
	     &ctr)
	    ) != CRYPT_OK)
    {
	printf("ctr_start error: %s\n", error_to_string(errno));
    }

    size_buf = sizeof(inbuf);
    char outbuf[size_buf];

    do
    {
	// read a chunk of ciphered data from input file fin	
	size_in = fread(inbuf, 1, size_buf, fin);

	if ((errno = ctr_decrypt(inbuf, /* plaintext */
				 plaintext, /* ciphertext */
				 size_in,
				 &ctr)
		) != CRYPT_OK)
	{
	    printf("ctr_decrypt error: %s\n", error_to_string(errno));
	}

	// plaintext appears to be longer by 1 byte, shorten it back
	int i = 0;
	for(i; i < size_buf; i++)
	    outbuf[i] = plaintext[i];

	if(size_in < size_buf)
	    outbuf[size_in] = '\0';
	else
	    outbuf[size_buf] = '\0';

	strcat(outstring, outbuf);

    } while(size_in == size_buf);

    outstringp = outstring;

    fclose(fin);

    /* terminate the stream */
    if ((errno = ctr_done(&ctr)) != CRYPT_OK)
    {
	printf("ctr_done error: %s\n", error_to_string(errno));
    }

    /* unregister aes */
    if ((errno = unregister_cipher(&aes_desc)) != CRYPT_OK)
    {
	printf("Error unregistering cipher: %s\n", error_to_string(errno));
    }

    /* clear up and return */
    zeromem(key, sizeof(key));
    zeromem(&ctr, sizeof(ctr));

    return outstringp;
}
