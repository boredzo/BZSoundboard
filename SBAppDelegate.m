//
//  SBAppDelegate.m
//  BZSoundboard
//
//  Created by Peter Hosey on 2006-01-23.
//  Copyright 2006 Peter Hosey. All rights reserved.
//

#import "SBAppDelegate.h"

#include <unistd.h> //TEMP
#import <ExceptionHandling/NSExceptionHandler.h> //TEMP

@implementation SBAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	NSExceptionHandler *handler = [NSExceptionHandler defaultExceptionHandler];
	[handler setExceptionHandlingMask:NSLogAndHandleEveryExceptionMask];
	[handler setDelegate:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
	return YES;
}

#pragma mark NSExceptionHandler delegate conformance (TEMP)

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(unsigned int)aMask {
	NSLog(@"logging exception: %@", exception);
	NSMutableArray *symbols = [[[[exception userInfo] objectForKey:NSStackTraceKey] componentsSeparatedByString:@"  "] mutableCopy];
	
	[symbols insertObject:@"-p" atIndex:0U];
	[symbols insertObject:[[NSNumber numberWithInt:getpid()] stringValue] atIndex:1U];
	
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/atos"];
	[task setArguments:symbols];
	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	
	[task launch];
	[task waitUntilExit];
	
	NSFileHandle *fh = [pipe fileHandleForReading];
	NSData *data = [fh readDataToEndOfFile];
	NSString *stackTrace = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	
	[task release];
	
	NSLog(@"got %@ with reason %@; stack trace follows\n%@", [exception name], [exception reason], stackTrace);
	
	return NO; //because we just did
}

@end
