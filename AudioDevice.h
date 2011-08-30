//
//  AudioDevice.h
//  BZAudioPipe
//
//  Created by Mac-arena the Bored Zo on 2005-11-24.
//  Copyright 2005 Mac-arena the Bored Zo. All rights reserved.
//

//a new device has (dis)?appeared.
extern NSString *AudioDeviceWasAddedNotification;
extern NSString *AudioDeviceWasRemovedNotification;

//the default (in|out)put device has changed.
extern NSString *AudioDeviceDefaultInputDeviceChangedNotification;
extern NSString *AudioDeviceDefaultOutputDeviceChangedNotification;

@interface AudioDevice : NSObject {
	NSString *name;
	NSString *UID;
	AudioDeviceID deviceID;

	UInt32 safetyOffset, numBufferFrames;
}

+ (NSArray *)allDevices;
+ (NSArray *)allInputDevices;
+ (NSArray *)allOutputDevices;

+ (AudioDevice *)defaultInputOutputDevice;
+ (AudioDevice *)defaultInputDevice;
+ (AudioDevice *)defaultOutputDevice;

#pragma mark -

+ (AudioDeviceID)deviceIDWithUID:(NSString *)UID;
+ (NSString *)UIDWithDeviceID:(AudioDeviceID)deviceID;

#pragma mark -

+ deviceWithDeviceID:(AudioDeviceID)newID;
+ deviceWithUID:(NSString *)newUID;

- initWithDeviceID:(AudioDeviceID)newID;
- initWithUID:(NSString *)newUID;

#pragma mark -

- (AudioDeviceID)deviceID;
- (NSString *)UID;

- (NSString *)name;

- (UInt32)safetyOffset;
- (UInt32)numberOfBufferFrames;

#pragma mark -

- (BOOL)supportsInput;
- (BOOL)supportsOutput;

@end
