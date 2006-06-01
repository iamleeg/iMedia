/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 This file was Authored by Dan Wood & Terrence Talbot
 
 NOTE: THESE METHODS ARE SIMILAR OR IDENTICAL TO METHODS IN SANDVOX; THE CODE WILL HAVE THE
 SAME LICENSING TERMS.  PLEASE BE SURE TO "SYNC" THEM UP IF ANY FIXES ARE MADE HERE.
 
 
 */

#import "NSString+iMedia.h"
#include <openssl/bio.h>
#include <openssl/evp.h>

@implementation NSString ( UTI )


//  convert to UTI

+ (NSString *)UTIForFileAtPath:(NSString *)anAbsolutePath
{
	NSString *result = nil;
	
	// check extension first
	NSString *extension = [anAbsolutePath pathExtension];
	if ( (nil != extension) && ![extension isEqualToString:@""] )
	{
		result = [self UTIForFilenameExtension:extension];
	}
	
	// if no extension or no result, check file type
	if ( nil == result )
	{
		NSString *fileType = NSHFSTypeOfFile(anAbsolutePath);
		if (6 == [fileType length])
		{
			fileType = [fileType substringWithRange:NSMakeRange(1,4)];
		}
		result = [self UTIForFileType:fileType];
		if ([result hasPrefix:@"dyn."])
		{
			result = nil;		// reject a dynamic type if it tries that.
		}
	}
    
	if (nil == result)	// not found, figure out if it's a directory or not
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL isDirectory;
        if ( [fm fileExistsAtPath:anAbsolutePath isDirectory:&isDirectory] )
		{
			result = isDirectory ? (NSString *)kUTTypeDirectory : (NSString *)kUTTypeData;
		}
	}
	
	// Will return nil if file doesn't exist.
	
	return result;
}

+ (NSString *)UTIForFilenameExtension:(NSString *)anExtension
{
	NSString *UTI = nil;
	
	if ([anExtension isEqualToString:@"m4v"])
	{
		// Hack, since we already have this UTI defined in the system, I don't think I can add it to the plist.
		UTI = (NSString *)kUTTypeMPEG4;
	}
	else
	{
		UTI = (NSString *)UTTypeCreatePreferredIdentifierForTag(
																kUTTagClassFilenameExtension,
																(CFStringRef)anExtension,
																NULL
																);
	}
	
	// If we don't find it, add an entry to the info.plist of the APP,
	// along the lines of what is documented here: 
	// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/understand_utis_conc/chapter_2_section_4.html
	// A good starting point for informal ones is:
	// http://www.huw.id.au/code/fileTypeIDs.html
    
	return UTI;
}

+ (NSString *)UTIForFileType:(NSString *)aFileType;

{
	return (NSString *)UTTypeCreatePreferredIdentifierForTag(
															 kUTTagClassOSType,
															 (CFStringRef)aFileType,
															 NULL
															 );	
}

// See list here:
// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/utilist/chapter_4_section_1.html

+ (BOOL) UTI:(NSString *)aUTI conformsToUTI:(NSString *)aConformsToUTI
{
	return UTTypeConformsTo((CFStringRef)aUTI, (CFStringRef)aConformsToUTI);
}


@end

// This is from cocoadev.com -- public domain

@implementation NSString (Base64)

- (NSData *) decodeBase64;
{
    return [self decodeBase64WithNewlines: YES];
}

- (NSData *) decodeBase64WithNewlines: (BOOL) encodedWithNewlines;
{
    // Create a memory buffer containing Base64 encoded string data
    BIO * mem = BIO_new_mem_buf((void *) [self cString], [self cStringLength]);
    
    // Push a Base64 filter so that reading from the buffer decodes it
    BIO * b64 = BIO_new(BIO_f_base64());
    if (!encodedWithNewlines)
        BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
    mem = BIO_push(b64, mem);
    
    // Decode into an NSMutableData
    NSMutableData * data = [NSMutableData data];
    char inbuf[512];
    int inlen;
    while ((inlen = BIO_read(mem, inbuf, sizeof(inbuf))) > 0)
        [data appendBytes: inbuf length: inlen];
    
    // Clean up and go home
    BIO_free_all(mem);
    return data;
}

@end

@implementation NSString (UUID)

+ (id)uuid
{
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
	CFRelease(uuid);
	[(NSString *)uuidStr autorelease];
	return (NSString *)uuidStr;
}

@end
