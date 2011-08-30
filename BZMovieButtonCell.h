//
//  BZMovieButtonCell.h
//  BZAudioPlayer
//
//  Created by Mac-arena the Bored Zo on 2006-01-20.
//  Copyright 2006 Mac-arena the Bored Zo. All rights reserved.
//

#import "BZClickableCell.h"
#import "BZKeyAcceptingCell.h"

@class AudioDevice;

@interface BZMovieButtonCell : NSButtonCell <BZClickableCell, BZKeyAcceptingCell> {
	QTMovie *movie;
	AudioDevice *device;
	id <NSObject> notificationObject;

	float volume;
	NSToolTipTag tooltipTag;

	unsigned reserved: 31;
	unsigned drawDragHighlight: 1;
}

- (QTMovie *)movie;
- (void)setMovie:(QTMovie *)newMovie;

- (AudioDevice *)audioDevice;
- (void)setAudioDevice:(AudioDevice *)newDevice;

- (float)volume;
- (void)setVolume:(float)newVol;

//used when listening for notifications. not retained.
- (id <NSObject>)notificationObject;
- (void)setNotificationObject:(id <NSObject>)newObj;

@end
