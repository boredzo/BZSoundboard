//
//  BZMovieButtonCell.m
//  BZAudioPlayer
//
//  Created by Mac-arena the Bored Zo on 2006-01-20.
//  Copyright 2006 Mac-arena the Bored Zo. All rights reserved.
//

#import "BZMovieButtonCell.h"

#import "CommonNotifications.h"

#import "AudioDevice.h"
#import "QTMovie+AudioDevice.h"

#include <float.h>

@implementation BZMovieButtonCell

- initTextCell:(NSString *)str {
	if((self = [super initTextCell:str])) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(selectedDeviceChanged:)
													 name:SELECTED_DEVICE_CHANGED_NOTIFICATION
												   object:notificationObject];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(selectedVolumeChanged:)
													 name:VOLUME_CHANGED_NOTIFICATION
												   object:notificationObject];
	}
	return self;
}
- initImageCell:(NSImage *)img {
	if((self = [super initImageCell:img])) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(selectedDeviceChanged:)
													 name:SELECTED_DEVICE_CHANGED_NOTIFICATION
												   object:notificationObject];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(selectedVolumeChanged:)
													 name:VOLUME_CHANGED_NOTIFICATION
												   object:notificationObject];
	}
	return self;
}
- initWithCoder:(NSCoder *)coder {
	if((self = [super initWithCoder:coder])) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(selectedDeviceChanged:)
													 name:SELECTED_DEVICE_CHANGED_NOTIFICATION
												   object:notificationObject];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(selectedVolumeChanged:)
													 name:VOLUME_CHANGED_NOTIFICATION
												   object:notificationObject];
	}
	return self;
}
//DON'T FORGET to add new notifications in -setNotificationObject: as well!

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

#pragma mark Generating useful info

- (NSString *)tooltip {
	if(movie) {
		return [NSString stringWithFormat:@"%@\n%@",
			[movie attributeForKey:QTMovieDisplayNameAttribute],
			[movie attributeForKey:QTMovieFileNameAttribute]];
	} else
		return nil;
}

- (NSRect)frame {
	NSView *view = [self controlView];
	if([view isKindOfClass:[NSMatrix class]]) {
		NSMatrix *matrix = (NSMatrix *)view;
		int row, col;
		[matrix getRow:&row column:&col ofCell:self];
		return [matrix cellFrameAtRow:row column:col];
	} else {
		return [view frame];
	}
}

#pragma mark Accessors

- (QTMovie *)movie {
	return movie;
}
- (void)setMovie:(QTMovie *)newMovie {
	[self willChangeValueForKey:@"movie"];

	if(movie != newMovie) {
		[movie release];
		movie = [newMovie retain];

		NSView *view = [self controlView];
		NSMatrix *matrix = (NSMatrix *)view;
		if(movie) {
			[movie setAudioDevice:device];
			[movie setVolume:volume];

			NSString *path = [movie attributeForKey:QTMovieFileNameAttribute];
			[self setImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];
			[self setTitle:[movie attributeForKey:QTMovieDisplayNameAttribute]];

			if([view isKindOfClass:[NSMatrix class]]) {
				int row, col;
				[matrix getRow:&row column:&col ofCell:self];
				tooltipTag = [matrix addToolTipRect:[matrix cellFrameAtRow:row column:col]
											  owner:self
										   userData:NULL];
			} else {
				[view setToolTip:[self tooltip]];
			}
		} else {
			[self setImage:nil];
			[self setTitle:NSLocalizedString(@"Drop file here", /*comment*/ nil)];
			if([view isKindOfClass:[NSMatrix class]]) {
				[matrix removeToolTip:tooltipTag];
			} else {
				[view setToolTip:nil];
			}
			[self setState:NSOffState];
		}

		[[self controlView] setNeedsDisplay:YES];
	}

	[self didChangeValueForKey:@"movie"];
}

- (AudioDevice *)audioDevice {
	return device;
}
- (void)setAudioDevice:(AudioDevice *)newDevice {
	if(device != newDevice) {
		[device release];
		device = [newDevice retain];
		
		[movie setAudioDevice:device];
	}
}

- (float)volume {
	return volume;
}
- (void)setVolume:(float)newVol {
	volume = newVol;
	[movie setVolume:newVol];
}

- (id <NSObject>)notificationObject {
	return notificationObject;
}
- (void)setNotificationObject:(id <NSObject>)newObj {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	[nc removeObserver:self
				  name:SELECTED_DEVICE_CHANGED_NOTIFICATION
				object:notificationObject];
	[nc removeObserver:self
				  name:VOLUME_CHANGED_NOTIFICATION
				object:notificationObject];
	
	notificationObject = newObj;

	[nc addObserver:self
		   selector:@selector(selectedDeviceChanged:)
			   name:SELECTED_DEVICE_CHANGED_NOTIFICATION
			 object:notificationObject];
	[nc addObserver:self
		   selector:@selector(selectedVolumeChanged:)
			   name:VOLUME_CHANGED_NOTIFICATION
			 object:notificationObject];
}

#pragma mark Drawing

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	[super drawWithFrame:cellFrame inView:controlView];

	if(drawDragHighlight) {
		NSColor *color = [[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.5f];
		NSRect   frame = [self frame];

		[color set];
		NSFrameRectWithWidth(frame, 2.0f);

		drawDragHighlight = NO;
	}
}

#pragma mark Drag-and-drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	NSArray *array = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	if(array && ([array count] == 1U)) {
		drawDragHighlight = YES;
		[[self controlView] setNeedsDisplayInRect:[self frame]];

		return NSDragOperationLink;
	} else
		return NSDragOperationNone;
}
- (void)draggingExited:(id <NSDraggingInfo>)sender {
	NSArray *array = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	if(array && ([array count] == 1U))
		[[self controlView] setNeedsDisplayInRect:[self frame]];
}
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
	[[self controlView] setNeedsDisplayInRect:[self frame]];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	NSArray *paths = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	NSString *path = [paths objectAtIndex:0U];

	NSError *error = nil;
	QTMovie *newMovie = [[QTMovie alloc] initWithFile:path error:&error];
	if(error) {
#warning XXX
	}

	NSNumber *num = nil;
	if(newMovie && (num = [newMovie attributeForKey:QTMovieHasAudioAttribute]) && [num boolValue]) {
		[self setMovie:newMovie];
		[newMovie release];
	}

	return (newMovie != nil);
}

#pragma mark BZClickableCell conformance

- (void)mouseDown:(NSEvent *)event {
	NSView *controlView = [self controlView];
	if([controlView isKindOfClass:[NSMatrix class]]) {
		NSMatrix *matrix = (NSMatrix *)controlView;
		[matrix setKeyCell:self];
	}

	if((!event) || !([event modifierFlags] & NSCommandKeyMask)) {
		[movie setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieLoopsAttribute];

		[movie setCurrentTime:QTZeroTime];

		if([movie rate] > FLT_EPSILON) {
			//if the movie is already playing, stop it.
			[movie stop];
			[[NSNotificationCenter defaultCenter] removeObserver:self
															name:QTMovieDidEndNotification
														  object:movie];
			[self setState:NSOffState];
		} else {
			//if the movie is not playing, start it.
			[movie play];
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(movieDidEnd:)
														 name:QTMovieDidEndNotification
													   object:movie];
			[self setState:NSOnState];
		}

		[controlView setNeedsDisplay:YES];
	}
}
- (void)mouseUp:(NSEvent *)event {
	if(event && ([event modifierFlags] & NSCommandKeyMask)) {
		//cmd-click reveals the file.
		NSString *filename = [movie attributeForKey:QTMovieFileNameAttribute];
		if(filename) {
			[[NSWorkspace sharedWorkspace] selectFile:filename
							 inFileViewerRootedAtPath:[filename stringByDeletingLastPathComponent]];
		}
	} else 
		[movie setAttribute:[NSNumber numberWithBool:NO] forKey:QTMovieLoopsAttribute];
}

- (void)performClick:sender {
	[self mouseDown:nil];
	[self mouseUp:nil];
}

#pragma mark BZKeyAcceptingCell conformance

- (BOOL)keyDown:(NSEvent *)event {
	NSString *characters = [event characters];
	if([characters length] == 1U) {
		switch([characters characterAtIndex:0U]) {
			case NSDeleteFunctionKey: //forward delete
			case 0x7f: //backwards delete
				[self setMovie:nil];

				//show a poof.
				NSRect frame = [self frame];
				NSView *view = [self controlView];

				NSPoint centerPoint = {
					frame.origin.x + frame.size.width  * 0.5f,
					frame.origin.y + frame.size.height * 0.5f
				};
				centerPoint = [view convertPoint:centerPoint toView:nil];
				NSRect windowFrame = [[view window] frame];
				centerPoint.x += windowFrame.origin.x;
				centerPoint.y += windowFrame.origin.y;

				NSShowAnimationEffect(NSAnimationEffectDisappearingItemDefault,
									  centerPoint,
									  frame.size,
									  /*delegate*/ nil,
									  /*selector*/ NULL,
									  /*contextInfo*/ NULL);
				return YES;
		}
	}

	return NO;
}
- (BOOL)keyUp:(NSEvent *)event {
	return NO;
}

#pragma mark NSToolTipOwner

//the tooltip for a cell is its path.
- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData {
	return [self tooltip];
}

#pragma mark Notifications

- (void)movieDidEnd:(NSNotification *)notification {
	[self setState:NSOffState];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:QTMovieDidEndNotification
												  object:movie];
}

- (void)selectedDeviceChanged:(NSNotification *)notification {
	[self setAudioDevice:[[notification userInfo] objectForKey:SELECTED_DEVICE_AUDIODEVICE]];
}
- (void)selectedVolumeChanged:(NSNotification *)notification {
	[self setVolume:[[[notification userInfo] objectForKey:NEW_VOLUME] floatValue]];
}

@end

//SAVE ME for j88!
static unsigned AppKitModifiersFromCarbonModifiers(unsigned carbonMask) {
	union {
		unsigned mask;
		struct {
			unsigned unused_high: 16;

			unsigned activeFlag: 1;
			unsigned unused_mid: 6;
			unsigned btnState  : 1;

			unsigned cmdKey         : 1;
			unsigned shiftKey       : 1;
			unsigned alphaLock      : 1;
			unsigned optionKey      : 1;
			unsigned controlKey     : 1;
			unsigned rightShiftKey  : 1;
			unsigned rightOptionKey : 1;
			unsigned rightControlKey: 1;
		} field;
	} input = { .mask = carbonMask };

	union {
		struct {
			unsigned unused_high: 8;

			unsigned alphaShiftKey: 1;
			unsigned shiftKey     : 1;
			unsigned controlKey   : 1;
			unsigned alternateKey : 1;
			unsigned commandKey   : 1;
			unsigned numericPadKey: 1;
			unsigned helpKey      : 1;
			unsigned functionKey  : 1;

			unsigned unused_low: 16;
		} field;
		unsigned mask;
	} result = { .mask = 0U };

	result.field.shiftKey      = input.field.shiftKey   || input.field.rightShiftKey;
	result.field.controlKey    = input.field.controlKey || input.field.rightControlKey;
	result.field.alternateKey  = input.field.optionKey  || input.field.rightOptionKey;
	result.field.alphaShiftKey = input.field.alphaLock;

	return result.mask;
}
