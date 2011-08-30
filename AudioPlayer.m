//
//  AudioPlayer.m
//  AudioPlayer
//
//  Created by Mac-arena the Bored Zo on 2005-11-15.
//  Copyright 2005 Mac-arena the Bored Zo. All rights reserved.
//

#import "AudioPlayer.h"

#import "NSURLAdditions.h"
#import "NSMutableArray+EasyMutation.h"

#import "BZMovieButtonCell.h"
#import "AudioDevice.h"

#include <c.h>
#include <errno.h>
#include <string.h>
#include <math.h>
#include <float.h>
#include <unistd.h> //TEMP
#import <ExceptionHandling/NSExceptionHandler.h> //TEMP

//#define STORED_PLAYLIST_KEY @"Saved playlist"
#define LAST_DEVICE_KEY @"UID of last selected output device"
#define CONTENTS_OF_SOUNDBOARD_KEY @"Rows in soundboard"

//guaranteed invalid URL/path indicating an empty cell in the soundboard
#define EMPTY_CELL @"//empty_cell"

#import "CommonNotifications.h"

@interface AudioPlayer (PRIVATE)

- (void)fillOutDevicesPopUp;

@end

@interface AudioPlayer (PRIVATE_BindingsAccessors)

//relative to (used by) the pop-up menu.
- (int)currentDeviceSelectionIndex;
- (void)setCurrentDeviceSelectionIndex:(int)newIndex;

@end

@implementation AudioPlayer

- init {
	if (self = [super init]) {
	}
	return self;
}

- (void)awakeFromNib {
	//populate the devices pop-up with all the devices.
	[self fillOutDevicesPopUp];

	//if we had a device selected at last quit (which practically means, if there WAS a last quit), re-select it.
	NSString *lastDeviceUID = [[NSUserDefaults standardUserDefaults] stringForKey:LAST_DEVICE_KEY];
	if(lastDeviceUID) {
		int lastSelectedIndex = [devicesPopUp indexOfItemWithRepresentedObject:lastDeviceUID];
		//make sure the device still exists. if not, stay with the default device (already selected in the nib).
		if(lastSelectedIndex < 0)
			lastSelectedIndex = 0;

		//store it in our ivar.
		[self setCurrentDeviceSelectionIndex:lastSelectedIndex];
	}

	//IB has our top-left cell highlighted and on. this works around that.
	BZMovieButtonCell *cell = [moviesMatrix cellAtRow:0 column:0];
	[cell setHighlighted:NO];
	[cell setState:NSOffState];
	
	//position the window appropriately.
	if(![playerWindow setFrameUsingName:[playerWindow frameAutosaveName]])
		[playerWindow center];
	[playerWindow makeKeyAndOrderFront:nil];
}

- (void)dealloc {

	[super dealloc];
}

#pragma mark -

- (QTAudioContextRef)createAudioContextWithDeviceUID:(NSString *)deviceUID {
	QTAudioContextRef audioContext;
	OSStatus err = QTAudioContextCreateForAudioDevice(kCFAllocatorDefault, (CFStringRef)deviceUID, /*options*/ NULL, &audioContext);
	if(err != noErr) {
		NSPanel *alert = NSGetAlertPanel(@"Could not get default device", @"An error of type %li (%s) occurred: %s", @"OK", nil, nil, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
		[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	}

	return audioContext;
}

//this must return a new context every time, because QT doesn't like it when we reuse audio contexts (even if the previous movie has been released).
- (QTAudioContextRef)createAudioContextForSelectedDevice {
	NSString *deviceUID = [[devicesPopUp selectedItem] representedObject];
	//if it's the default device, there is no represented object, so the represented object is nil = NULL, so we will create the context with the default device.
	//if it's a specific device, there is a represented object, so the represented object (UID) is not nil, so we will create the context with the UID for a device.

	//make an audio context for the selected device.
	return [self createAudioContextWithDeviceUID:deviceUID];
}
- (QTMovie *)movieWithFile:(NSString *)path {
	QTMovie *movie = nil;
	if(path) {
		NSError *error = nil;
		movie = [[[QTMovie alloc] initWithFile:path error:&error] autorelease];
		if(error) {
			NSPanel *alert = NSGetAlertPanel(@"Could not open file", @"The file %@ could not be opened because: %@", @"OK", nil, nil, path, [error localizedFailureReason]);
			[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
		}

		//disable all video tracks.
		NSArray *videoTracks = [movie tracksOfMediaType:QTMediaTypeVideo];
		NSEnumerator *videoTracksEnum = [videoTracks objectEnumerator];
		QTTrack *track;
		while((track = [videoTracksEnum nextObject]))
			[track setEnabled:NO];
	
		QTAudioContextRef audioContext = [self createAudioContextForSelectedDevice];
		OSStatus err = SetMovieAudioContext([movie quickTimeMovie], audioContext);
		if(err != noErr) {
			NSPanel *alert = NSGetAlertPanel(@"Could not set audio device", @"When trying to set the audio output device for the movie, an error of type %i (%s) occurred: %s", @"OK", nil, nil, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
			[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];

			QTAudioContextRelease(audioContext);
		}
	}

	return movie;
}

#pragma mark NSApplication delegate conformance

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
	return YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	[moviesMatrix registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

	NSRange range = { 0U, [moviesMatrix numberOfRows] };
	NSArray *rows = [[NSUserDefaults standardUserDefaults] arrayForKey:CONTENTS_OF_SOUNDBOARD_KEY];
	if([rows count] > range.length)
		rows = [rows subarrayWithRange:range];

	//in the loop, we use this range to crop the rows to the proper number of columns.
	range.length = [moviesMatrix numberOfColumns];

	NSEnumerator *rowsEnum = [rows objectEnumerator];
	NSArray *row;
	unsigned rowIndex = 0U;
	while((row = [rowsEnum nextObject])) {
		NSEnumerator *rowEnum = [row objectEnumerator];
		NSObject *obj;
		unsigned colIndex = 0U;
		while((obj = [rowEnum nextObject])) {
			if(![obj isEqual:EMPTY_CELL]) {
				NSDictionary *desc = (NSDictionary *)obj;
				NSString *path = [[NSURL fileURLWithDockDescription:desc] path];

				NSError *error = nil;
				QTMovie *movie = [[QTMovie alloc] initWithFile:path error:&error];
				if(error) {
					NSPanel *alert = NSGetAlertPanel(@"Could not open file", @"The file %@ could not be opened because: %@", @"OK", nil, nil, path, [error localizedFailureReason]);
					[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL]; 
				}

				if(movie) {
					BZMovieButtonCell *cell = [moviesMatrix cellAtRow:rowIndex column:colIndex];
					[cell setMovie:movie];
					[movie release];
				}
			}

			if(++colIndex >= range.length)
				break;
		}

		++rowIndex;
	}
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *rowsFromPrefs = [defaults arrayForKey:CONTENTS_OF_SOUNDBOARD_KEY];
	unsigned rowsFromPrefsCount = [rowsFromPrefs count];

	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:rowsFromPrefsCount];

	unsigned numberOfColsInMatrix = [moviesMatrix numberOfColumns];
	unsigned numberOfRowsInMatrix = [moviesMatrix numberOfRows];

	NSRange rowsCrop = { 0U, 0U };

	unsigned rowIndex = 0U;
	NSMutableArray *row;
	while(rowIndex < numberOfRowsInMatrix) {
		if(rowIndex < rowsFromPrefsCount)
			row = [[rowsFromPrefs objectAtIndex:rowIndex] mutableCopy];
		else
			row = [[NSMutableArray alloc] init];

		//we want to crop any empty cells off of the end.
		NSRange columnsCrop = { 0U, 0U };

		unsigned colIndex = 0U;
		while(colIndex < numberOfColsInMatrix) {
			BZMovieButtonCell *cell = [moviesMatrix cellAtRow:rowIndex column:colIndex];

			NSObject *value;
			QTMovie *movie = [cell movie];
			if(movie) {
				//we know the movie has a filename because we create them with filenames, as does BZMovieButtonCell.
				NSString *path = [movie attributeForKey:QTMovieFileNameAttribute];
				value = [[NSURL fileURLWithPath:path] dockDescription];

				//start columns crop here.
				columnsCrop.location = colIndex + 1U;
			} else {
				value = EMPTY_CELL;
			}

			[row setObject:value atIndex:colIndex++];
		}

		//crop off any empty cells at the end.
		//this may leave the row empty, which is fine.
		columnsCrop.length = [row count] - columnsCrop.location;
		if(columnsCrop.length)
			[row removeObjectsInRange:columnsCrop];

		++rowIndex;
		
		//start rows crop here.
		if([row count])
			rowsCrop.location = rowIndex;

		[rows addObject:row];
		[row release];
	}

	rowsCrop.length = [rows count] - rowsCrop.location;
	if(rowsCrop.length)
		[rows removeObjectsInRange:rowsCrop];

	[defaults setObject:rows forKey:CONTENTS_OF_SOUNDBOARD_KEY];
}

#if 0
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
#endif //0
//END TEMP

#pragma mark Generic panel end handler

- (void)panelDidEnd:(NSPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[panel close];
}

#pragma mark Bindings accessors

//relative to (used by) the pop-up menu.
- (int)currentDeviceSelectionIndex {
	return lastSelectedDeviceIndex;
}
- (void)setCurrentDeviceSelectionIndex:(int)newIndex {
	[self willChangeValueForKey:@"currentDeviceSelectionIndex"];
	lastSelectedDeviceIndex = newIndex;
	[self  didChangeValueForKey:@"currentDeviceSelectionIndex"];

	//store it in user defaults.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *deviceUID = [[devicesPopUp selectedItem] representedObject];
	if(deviceUID)
		[defaults setObject:deviceUID forKey:LAST_DEVICE_KEY];
	else
		[defaults removeObjectForKey:LAST_DEVICE_KEY];

	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		deviceUID, SELECTED_DEVICE_UID,
		[AudioDevice deviceWithUID:deviceUID], SELECTED_DEVICE_AUDIODEVICE,
		nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:SELECTED_DEVICE_CHANGED_NOTIFICATION
														object:devicesPopUp
													  userInfo:userInfo];
}

#pragma mark End of implementation
@end

@implementation AudioPlayer (PRIVATE)

- (void)fillOutDevicesPopUp {
	OSStatus err;
	UInt32 size;

	err = AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &size, /*outWritable*/ NULL);

	if(err != noErr) {
		NSPanel *alert = NSGetAlertPanel(@"Could not get size of audio devices array", @"When trying to get the size of the array of audio output devices, an error of type %i (%s) occurred: %s", @"OK", nil, nil, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
		[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	} else {

		AudioDeviceID *deviceIDs = malloc(size);

		if(!deviceIDs) {
			NSPanel *alert = NSGetAlertPanel(@"Could not allocate audio devices array", @"When trying to get memory for the array of audio output devices, an error of type %i occurred: %s", @"OK", nil, nil, errno, strerror(errno));
			[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
		} else {

			err = AudioHardwareGetProperty(kAudioHardwarePropertyDevices, &size, deviceIDs);

			if(err != noErr) {
				NSPanel *alert = NSGetAlertPanel(@"Could not get audio devices array", @"When trying to get the the array of audio output devices, an error of type %i (%s) occurred: %s", @"OK", nil, nil, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
				[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
			} else {
				UInt32 numDevices = size / sizeof(AudioDeviceID);
				for(UInt32 deviceIdx = 0U; deviceIdx < numDevices; ++deviceIdx) {
					NSString *UID;
					size = sizeof(UID);

					err = AudioDeviceGetProperty(deviceIDs[deviceIdx], /*inChannel*/ 0U, /*isInput*/ false, kAudioDevicePropertyDeviceUID, &size, &UID);

					if(err != noErr) {
						NSPanel *alert = NSGetAlertPanel(@"Could not get audio device UID", @"When trying to get the UID (unique identifier) of an audio output device, an error of type %i (%s) occurred: %s", @"OK", nil, nil, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
						[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
					} else {
						NSString *name;
						size = sizeof(name);

						err = AudioDeviceGetProperty(deviceIDs[deviceIdx], /*inChannel*/ 0U, /*isInput*/ false, kAudioObjectPropertyName, &size, &name);

						if(err != noErr) {
							NSPanel *alert = NSGetAlertPanel(@"Could not get audio device name", @"When trying to get the name of an audio output device (with UID %@), an error of type %i (%s) occurred: %s", @"OK", nil, nil, UID, err, GetMacOSStatusErrorString(err), GetMacOSStatusCommentString(err));
							[NSApp beginSheet:alert modalForWindow:playerWindow modalDelegate:self didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
						} else {
							[devicesPopUp addItemWithTitle:name];
							NSMenuItem *menuItem = [devicesPopUp lastItem];
							[menuItem setRepresentedObject:UID];

							//CoreAudio gives us an implicitly-retained CFString.
							[name release];
						} //if(err == noErr) (AudioDeviceGetProperty(...kAudioObjectPropertyObjectName...))

						//CoreAudio gives us an implicitly-retained CFString.
						[UID release];
					} //if(err == noErr) (AudioDeviceGetProperty(...kAudioDevicePropertyDeviceUID...))
				} //for(UInt32 deviceIdx = 0U; deviceIdx < numDevices; ++deviceIdx)
			} //if(err == noErr) (AudioHardwareGetProperty(kAudioHardwarePropertyDevices...))
		} //if(deviceIDs)
	} //if(err == noErr) (AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices...))
}

@end
