//
//  AudioDevice.m
//  BZAudioPipe
//
//  Created by Mac-arena the Bored Zo on 2005-11-24.
//  Copyright 2005 Mac-arena the Bored Zo. All rights reserved.
//

#import "AudioDevice.h"

NSString *AudioDeviceWasAddedNotification = @"AudioDeviceWasAddedNotification";
NSString *AudioDeviceWasRemovedNotification = @"AudioDeviceWasRemovedNotification";

static NSMutableArray *allDeviceInstances = nil;
static NSMutableArray *allInputDevices = nil;
static NSMutableArray *allOutputDevices = nil;

static NSMutableDictionary *UIDsToDevices = nil;
static NSMutableDictionary *deviceIDsToDevices = nil;

static AudioDevice *defaultInputOutputDevice = nil;
static AudioDevice *defaultInputDevice = nil;
static AudioDevice *defaultOutputDevice = nil;

static OSStatus hardwarePropertyListener_devices(AudioHardwarePropertyID inPropertyID, void *refcon);
static OSStatus hardwarePropertyListener_defaultInputDevice(AudioHardwarePropertyID inPropertyID, void *refcon);
static OSStatus hardwarePropertyListener_defaultOutputDevice(AudioHardwarePropertyID inPropertyID, void *refcon);

@implementation AudioDevice

+ (void)initalize {
	//if the internal list of devices changes, we want to know about it.
	OSStatus err = AudioHardwareAddPropertyListener(kAudioHardwarePropertyDevices, hardwarePropertyListener_devices, /*refcon*/ NULL);
	if(err != kAudioHardwareNoError)
		NSLog(@"WARNING: tried to register for changes to the array of audio devices, but an error of type %@ occurred", NSFileTypeForHFSTypeCode(err));
	err = AudioHardwareAddPropertyListener(kAudioHardwarePropertyDefaultInputDevice, hardwarePropertyListener_defaultInputDevice, /*refcon*/ NULL);
	if(err != kAudioHardwareNoError)
		NSLog(@"WARNING: tried to register for changes to the array of audio devices, but an error of type %@ occurred", NSFileTypeForHFSTypeCode(err));
	err = AudioHardwareAddPropertyListener(kAudioHardwarePropertyDefaultOutputDevice, hardwarePropertyListener_defaultOutputDevice, /*refcon*/ NULL);
	if(err != kAudioHardwareNoError)
		NSLog(@"WARNING: tried to register for changes to the array of audio devices, but an error of type %@ occurred", NSFileTypeForHFSTypeCode(err));
	
	UIDsToDevices = [[NSMutableDictionary alloc] init];
	deviceIDsToDevices = [[NSMutableDictionary alloc] init];
}

+ (NSData *)allDeviceIDs {
	NSMutableData *data = nil;

	OSStatus err;
	UInt32 size;
		
	err = AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &size, /*outWritable*/ NULL);

	if(err != kAudioHardwareNoError) {
		NSLog(@"When trying to get the size of the array of audio devices, an error of type %@ occurred", NSFileTypeForHFSTypeCode(err));
	} else {
		data = [NSMutableData dataWithLength:size];
		AudioDeviceID *deviceIDs = [data mutableBytes];

		if(!deviceIDs) {
			NSLog(@"When trying to get memory for the array of audio devices, an error of type %@ occurred", NSFileTypeForHFSTypeCode(err));
		} else {
			err = AudioHardwareGetProperty(kAudioHardwarePropertyDevices, &size, deviceIDs);

			if(err != kAudioHardwareNoError)
				NSLog(@"When trying to get the array of audio devices, an error of type %@ occurred", NSFileTypeForHFSTypeCode(err));
		}
	}

	return data;
}

+ (NSArray *)allDevices {
	if(!allDeviceInstances) {
		NSData *data = [self allDeviceIDs];
		const AudioDeviceID *deviceIDs = [data bytes];
		UInt32 numDevices = [data length] / sizeof(AudioDeviceID);

		allDeviceInstances = [[NSMutableArray alloc] initWithCapacity:numDevices];

		for(UInt32 deviceIdx = 0U; deviceIdx < numDevices; ++deviceIdx)
			[allDeviceInstances addObject:[self deviceWithDeviceID:deviceIDs[deviceIdx]]];
	} //if(!allDeviceInstances)

	return allDeviceInstances;
}
+ (NSArray *)allInputDevices {
	if(!allInputDevices) {
		allInputDevices = [[self allDevices] mutableCopy];

		//filter out devices that do not support input.
		unsigned idx = 0U, len = [allInputDevices count];
		while(idx < len) {
			AudioDevice *device = [allInputDevices objectAtIndex:idx];
			if([device supportsInput]) //keep it; skip over it
				++idx;
			else {
				//remove it from the input-devices array.
				[allInputDevices removeObjectAtIndex:idx];
				--len;
			}
		}
	}
	return allInputDevices;
}
+ (NSArray *)allOutputDevices {
	if(!allOutputDevices) {
		allOutputDevices = [[self allDevices] mutableCopy];

		//filter out devices that do not support input.
		unsigned idx = 0U, len = [allOutputDevices count];
		while(idx < len) {
			AudioDevice *device = [allOutputDevices objectAtIndex:idx];
			if([device supportsOutput]) //keep it; skip over it
				++idx;
			else {
				//remove it from the input-devices array.
				[allOutputDevices removeObjectAtIndex:idx];
				--len;
			}
		}
	}
	return allOutputDevices;
}

+ (AudioDevice *)defaultInputOutputDevice {
	if(!defaultInputOutputDevice)
		defaultInputOutputDevice = [[self alloc] initWithDeviceID:kAudioDeviceUnknown];
	return defaultInputOutputDevice;
}
+ (AudioDevice *)defaultInputDevice {
	if(!defaultInputDevice) {
		AudioDeviceID deviceID = kAudioDeviceUnknown;
		UInt32 size = sizeof(deviceID);

		OSStatus err = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultInputDevice,
												&size,
												&deviceID);
		if(err == noErr) {
			NSNumber *deviceIDNum = [NSNumber numberWithUnsignedInt:deviceID];

			defaultInputDevice = [deviceIDsToDevices objectForKey:deviceIDNum];
			if(!defaultInputDevice) {
				//no existing instance - create a new one.
				defaultInputDevice = [[self alloc] initWithDeviceID:deviceID];

				[UIDsToDevices      setObject:defaultInputDevice forKey:[defaultOutputDevice UID]];
				[deviceIDsToDevices setObject:defaultInputDevice forKey:deviceIDNum];
			}
		} else //XXX report this
			;
	}

	return defaultInputDevice;
}
+ (AudioDevice *)defaultOutputDevice {
	if(!defaultOutputDevice) {
		AudioDeviceID deviceID = kAudioDeviceUnknown;
		UInt32 size = sizeof(deviceID);
	
		OSStatus err = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice,
												&size,
												&deviceID);
		if(err == noErr) {
			NSNumber *deviceIDNum = [NSNumber numberWithUnsignedInt:deviceID];

			defaultOutputDevice = [deviceIDsToDevices objectForKey:deviceIDNum];
			if(!defaultOutputDevice) {
				defaultOutputDevice = [[self alloc] initWithDeviceID:deviceID];

				[UIDsToDevices setObject:defaultOutputDevice forKey:[defaultOutputDevice UID]];
				[deviceIDsToDevices setObject:defaultOutputDevice forKey:deviceIDNum];
			}
		} else //XXX report this
			;
	}

	return defaultOutputDevice;
}

#pragma mark -

+ (AudioDeviceID)deviceIDWithUID:(NSString *)UID {
	AudioDeviceID deviceID = kAudioDeviceUnknown;

	if(UID) {
		struct AudioValueTranslation translator = {
			&UID,
			sizeof(UID),
			&deviceID,
			sizeof(deviceID),
		};
		UInt32 translatorSize = sizeof(translator);

		OSStatus err = AudioHardwareGetProperty(kAudioHardwarePropertyDeviceForUID, &translatorSize, &translator);
		if(err != kAudioHardwareNoError) {
			NSLog(@"Got error %@ while mapping UID %@ to a device ID", NSFileTypeForHFSTypeCode(err), UID);
			return kAudioDeviceUnknown;
		}
	}

	return deviceID;
}
+ (NSString *)UIDWithDeviceID:(AudioDeviceID)deviceID {
	NSString *UID = nil;
	UInt32 size = sizeof(UID);
	
	OSStatus err = AudioDeviceGetProperty(deviceID,
										  /*inChannel*/ 0U,
										  /*isInput*/ false, //shouldn't matter
										  kAudioDevicePropertyDeviceUID,
										  &size,
										  &UID);
	if(err != kAudioHardwareNoError) {
		NSLog(@"Got error %@ while mapping device ID %u to a UID", NSFileTypeForHFSTypeCode(err), deviceID);
		return nil;
	}

	return UID;
}

#pragma mark -

+ deviceWithDeviceID:(AudioDeviceID)newID {
	return [[[self alloc] initWithDeviceID:newID] autorelease];
}
+ deviceWithUID:(NSString *)newUID {
	return [[[self alloc] initWithUID:newUID] autorelease];
}

- initWithDeviceID:(AudioDeviceID)newID {
	NSNumber *num = [NSNumber numberWithUnsignedInt:newID];

	AudioDevice *inst = [deviceIDsToDevices objectForKey:num];
	if(inst) {
		[self release];
		return inst;
	}

	//no existing instance; create a new one.
	if((self = [self init])) {
		deviceID = newID;
		//UID and name are obtained lazily

		[deviceIDsToDevices setObject:self forKey:num];
	}
	return self;
}
- initWithUID:(NSString *)newUID {
	AudioDevice *inst = [UIDsToDevices objectForKey:newUID];
	if(inst) {
		if(!inst->UID)
			inst->UID = [newUID copy];
	} else {
		inst = [self initWithDeviceID:[[self class] deviceIDWithUID:newUID]];
		if(inst) {
			inst->UID = [newUID copy];

			[UIDsToDevices setObject:inst forKey:newUID];
		}
	}
	return inst;
}

- (void)dealloc {
	[UID release];
	[name release];

	[super dealloc];
}

#pragma mark -

- (AudioDeviceID)deviceID {
	return deviceID;
}
- (NSString *)UID {
	if(deviceID == kAudioDeviceUnknown) //default device
		return nil;
	else {
		if(!UID)
			UID = [[[self class] UIDWithDeviceID:deviceID] copy];
		return UID;
	}
}

- (NSString *)name {
	if(!name) {
		UInt32 size = sizeof(name);
		OSStatus err = AudioDeviceGetProperty(deviceID,
											  /*inChannel*/ 0U,
											  /*isInput*/ 0U, //shouldn't matter
											  kAudioObjectPropertyName,
											  &size,
											  &name);
		if(err != kAudioHardwareNoError)
			NSLog(@"Got error %@ while getting name of device ID %u (cached UID %@)", NSFileTypeForHFSTypeCode(err), deviceID, UID);
	}

	return name;
}

- (UInt32)safetyOffset {
	return safetyOffset;
}
- (UInt32)numberOfBufferFrames {
	return numBufferFrames;
}

#pragma mark -

- (BOOL)supportsInput {
	OSStatus err;
	UInt32 size;
	
	//check input.
	err = AudioDeviceGetPropertyInfo(deviceID, 0, /*isInput*/ true, kAudioDevicePropertyStreams, &size, /*outWritable*/ NULL);
	
	if (err != kAudioHardwareNoError) {
		NSLog(@"Got error %@ when trying to get size of audio device's input streams array", NSFileTypeForHFSTypeCode(err));
		return NO;
	} else
		return (size > 0U);
}
- (BOOL)supportsOutput {
	OSStatus err;
	UInt32 size;
	
	//check input.
	err = AudioDeviceGetPropertyInfo(deviceID, 0, /*isInput*/ false, kAudioDevicePropertyStreams, &size, /*outWritable*/ NULL);
	
	if (err != kAudioHardwareNoError) {
		NSLog(@"Got error %@ when trying to get size of audio device's input streams array", NSFileTypeForHFSTypeCode(err));
		return NO;
	} else
		return (size > 0U);
}

@end

static OSStatus hardwarePropertyListener_devices(AudioHardwarePropertyID inPropertyID, void *refcon) {
	if(!allDeviceInstances) {
		//cool! we don't need to update anything.
		return kAudioHardwareNoError;
	}

	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

	NSData *data = [AudioDevice allDeviceIDs];

	const AudioDeviceID *deviceIDs = [data bytes];
	unsigned numDevices = [data length] / sizeof(AudioDeviceID);

	NSMutableSet *newDeviceIDs = [NSMutableSet setWithCapacity:numDevices];
	for(unsigned i = 0U; i < numDevices; ++i) {
		NSNumber *num = [[NSNumber alloc] initWithUnsignedInt:deviceIDs[i]];
		[newDeviceIDs addObject:num];
		[num release];
	}

	NSArray *oldDeviceIDsArray = [allDeviceInstances valueForKey:@"deviceID"];
	NSMutableSet *oldDeviceIDs = [NSMutableSet setWithArray:oldDeviceIDsArray];

	NSMutableDictionary *oldDevices = [NSMutableDictionary dictionaryWithObjects:allDeviceInstances
																		 forKeys:oldDeviceIDsArray];

	//add the devices that really are new (in the new-devices set, not in the old-devices set).
	{
		NSMutableSet *devicesToAdd = [newDeviceIDs mutableCopy];
		[devicesToAdd minusSet:oldDeviceIDs];

		NSEnumerator *deviceIDsEnum = [devicesToAdd objectEnumerator];
		NSNumber *deviceIDNumber;
		while((deviceIDNumber = [deviceIDsEnum nextObject])) {
			AudioDevice *device = [[AudioDevice alloc] initWithDeviceID:[deviceIDNumber unsignedIntValue]];
			[allDeviceInstances addObject:device];
			[device release];

			[notificationCenter postNotificationName:AudioDeviceWasAddedNotification object:device];
		}

		[devicesToAdd release];
	}

	//remove the devices that really are old (in the old-devices set, not in the new-devices set).
	{
		NSMutableSet *devicesToRemove = [oldDeviceIDs mutableCopy];
		[devicesToRemove minusSet:newDeviceIDs];

		NSEnumerator *deviceIDsEnum = [devicesToRemove objectEnumerator];
		NSNumber *deviceIDNumber;
		while((deviceIDNumber = [deviceIDsEnum nextObject])) {
			AudioDeviceID deviceID = [deviceIDNumber unsignedIntValue];

			unsigned i = 0U, len = [allDeviceInstances count];
			while(i < len) {
				AudioDevice *device = [allDeviceInstances objectAtIndex:i];
				if([device deviceID] == deviceID) {
					//we have a match. remove it.
					[device retain];

					[allDeviceInstances removeObjectAtIndex:i];
					--len;

					[notificationCenter postNotificationName:AudioDeviceWasRemovedNotification object:device];
					[device release];
				} else
					++i;
			}
		}

		[devicesToRemove release];
	}

	return noErr;
}

static OSStatus hardwarePropertyListener_defaultInputDevice(AudioHardwarePropertyID inPropertyID, void *refcon) {
	[defaultInputDevice release]; defaultInputDevice = nil;
	return noErr;
}
static OSStatus hardwarePropertyListener_defaultOutputDevice(AudioHardwarePropertyID inPropertyID, void *refcon) {
	[defaultOutputDevice release]; defaultOutputDevice = nil;
	return noErr;
}
