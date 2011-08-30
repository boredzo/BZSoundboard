//
//  NSURLAdditions.m
//  Growl
//
//  Created by Karl Adam on Fri May 28 2004.
//  Copyright 2004-2005 The Growl Project. All rights reserved.
//
// This file is under the BSD License, refer to License.txt for details

#import "NSURLAdditions.h"
#include "CFGrowlAdditions.h"

#define _CFURLAliasDataKey  CFSTR("_CFURLAliasData")
#define _CFURLStringKey     CFSTR("_CFURLString")
#define _CFURLStringTypeKey CFSTR("_CFURLStringType")

static Boolean aliasFilter_acceptFirstMatch(union CInfoPBRec *cpb, Boolean *quitFlag, Ptr myDataPtr);

@implementation NSURL (GrowlAdditions)

//'alias' as in the Alias Manager.
+ (NSURL *) fileURLWithAliasData:(NSData *)aliasData {
	NSParameterAssert(aliasData != nil);

	NSURL *url = nil;

	AliasHandle alias = NULL;
	CFDataRef cfData = (CFDataRef)aliasData;
	OSStatus err = PtrToHand(CFDataGetBytePtr(cfData), (Handle *)&alias, CFDataGetLength(cfData));
	if (err != noErr) {
		NSLog(@"in +[NSURL(GrowlAdditions) fileURLWithAliasData:]: Could not allocate an alias handle from %u bytes of alias data (data follows) because PtrToHand returned %li\n%@", [aliasData length], aliasData, (long)err);
	} else {
		FSRef match;
		short numMatches = 1;
		Boolean needsUpdate;
		err = FSMatchAlias(/*fromFile*/ NULL,
						   kARMSearch,
						   alias,
						   &numMatches,
						   &match,
						   &needsUpdate,
						   aliasFilter_acceptFirstMatch,
						   /*refcon*/ NULL);
		if (err != noErr) {
			if (err != fnfErr) //ignore file-not-found; it's harmless
				NSLog(@"in +[NSURL(GrowlAdditions) fileURLWithAliasData:]: Could not resolve alias (alias data follows) because FSResolveAlias returned %li - will try path\n%@", (long)err, aliasData);
		} else {
			if (numMatches)
				url = [(NSURL *)CFURLCreateFromFSRef(kCFAllocatorDefault, &match) autorelease];
			if (numMatches != 1)
				NSLog(@"in +[NSURL(GrowlAdditions) fileURLWithAliasData:]: FSMatchAlias returned %hi matches, not 1", numMatches);
		}
	}

	return url;
}

- (NSData *) aliasData {
	//return nil for non-file: URLs.
	CFStringRef scheme = CFURLCopyScheme((CFURLRef)self);
	CFComparisonResult isFileURL = CFStringCompare(scheme, CFSTR("file"), kCFCompareCaseInsensitive);
	CFRelease(scheme);
	if (isFileURL != kCFCompareEqualTo)
		return nil;

	NSData *aliasData = nil;

	FSRef fsref;
	if (CFURLGetFSRef((CFURLRef)self, &fsref)) {
		AliasHandle alias = NULL;
		OSStatus    err   = FSNewAlias(/*fromFile*/ NULL, &fsref, &alias);
		if (err != noErr) {
			NSLog(@"in -[NSURL(GrowlAdditions) dockDescription]: FSNewAlias for %@ returned %li", self, (long)err);
		} else {
			HLock((Handle)alias);

			aliasData = [(id)CFDataCreate(kCFAllocatorDefault, (const UInt8 *)*alias, GetHandleSize((Handle)alias)) autorelease];

			HUnlock((Handle)alias);
			DisposeHandle((Handle)alias);
		}
	}

	return aliasData;
}

//these are the type of external representations used by Dock.app.
+ (NSURL *) fileURLWithDockDescription:(NSDictionary *)dict {
	NSURL *URL = nil;

	CFDictionaryRef cfDict    = (CFDictionaryRef)dict;
	CFStringRef     path      = CFDictionaryGetValue(cfDict, _CFURLStringKey);
	CFDataRef       aliasData = CFDictionaryGetValue(cfDict, _CFURLAliasDataKey);

	if (aliasData)
		URL = [self fileURLWithAliasData:(NSData *)aliasData];

	if (!URL) {
		if (path) {
			CFNumberRef pathStyleNum = CFDictionaryGetValue(cfDict, _CFURLStringTypeKey);
			CFURLPathStyle pathStyle;
			if (pathStyleNum)
				CFNumberGetValue(pathStyleNum, kCFNumberIntType, &pathStyle);
			else
				pathStyleNum = kCFURLPOSIXPathStyle;

			BOOL isDir = YES;
			BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:(NSString *)path isDirectory:&isDir];

			if (exists)
				URL = [(NSURL *)CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path, pathStyle, /*isDirectory*/ isDir) autorelease];
		}
	}

	return URL;
}

- (NSDictionary *) dockDescription {
	CFMutableDictionaryRef dict;
	CFStringRef path     = CFURLCopyPath((CFURLRef)self);
	CFDataRef aliasData  = (CFDataRef)[self aliasData];

	if (path || aliasData) {
		dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

		if (path) {
			CFDictionarySetValue(dict, _CFURLStringKey, path);
			CFRelease(path);
			[(NSMutableDictionary *)dict setObject:[NSNumber numberWithInt:kCFURLPOSIXPathStyle] forKey:(NSString *)_CFURLStringTypeKey];
		}

		if (aliasData)
			CFDictionarySetValue(dict, _CFURLAliasDataKey, aliasData);

		[(id)dict autorelease];
	} else {
		dict = NULL;
	}

	return (NSDictionary *)dict;
}

@end

static Boolean aliasFilter_acceptFirstMatch(union CInfoPBRec *cpb, Boolean *quitFlag, Ptr myDataPtr) {
	*quitFlag = true; //stop after this one
	return false; //don't discard
}

