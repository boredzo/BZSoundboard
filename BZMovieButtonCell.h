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
}

- (QTMovie *)movie;
- (void)setMovie:(QTMovie *)newMovie;

@end
