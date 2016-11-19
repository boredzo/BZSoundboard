//
//  BZResizeNotifyingWindow.m
//  BZSoundboard
//
//  Created by Peter Hosey on 2006-01-25.
//  Copyright 2006 Peter Hosey. All rights reserved.
//

#import "BZResizeNotifyingWindow.h"

NSString *BZWindowLiveResizeWillBegin = @"BZWindowLiveResizeWillBegin";
NSString *BZWindowLiveResizeDidBegin  = @"BZWindowLiveResizeDidBegin";
NSString *BZWindowLiveResizeWillEnd   = @"BZWindowLiveResizeWillEnd";
NSString *BZWindowLiveResizeDidEnd    = @"BZWindowLiveResizeDidEnd";

@interface NSWindow (BZResizeNotifyingWindow_UndocumentedGoodness)
- (void)_startLiveResize;
- (void)_endLiveResize;
@end

@implementation BZResizeNotifyingWindow

- (void)_startLiveResize {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:BZWindowLiveResizeWillBegin
					  object:self];

	[super _startLiveResize];

	[nc postNotificationName:BZWindowLiveResizeDidBegin
					  object:self];
}
- (void)_endLiveResize {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:BZWindowLiveResizeWillEnd
					  object:self];

	[super _endLiveResize];

	[nc postNotificationName:BZWindowLiveResizeDidEnd
					  object:self];
}

@end
