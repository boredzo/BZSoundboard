//
//  QTMovie+AudioDevice.m
//  BZSoundboard
//
//  Created by Mac-arena the Bored Zo on 2006-01-22.
//  Copyright 2006 Mac-arena the Bored Zo. All rights reserved.
//

#import "QTMovie+AudioDevice.h"


@implementation QTMovie (AudioDevice)

- (void)setAudioDevice:(AudioDevice *)newDevice {
	QTAudioContextRef audioContext;
	OSStatus err = QTAudioContextCreateForAudioDevice(kCFAllocatorDefault, (CFStringRef)[newDevice UID], /*options*/ NULL, &audioContext);
	if(err != noErr) {
#warning XXX
	} else {
		err = SetMovieAudioContext([self quickTimeMovie], audioContext);
		if(err != noErr) {
#warning XXX
		}
	}
}

@end
