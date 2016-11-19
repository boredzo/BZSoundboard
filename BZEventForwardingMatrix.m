//
//  BZEventForwardingMatrix.m
//  BZAudioPlayer
//
//  Created by Peter Hosey on 2006-01-20.
//  Copyright 2006 Peter Hosey. All rights reserved.
//

#import "BZEventForwardingMatrix.h"

#import "BZClickableCell.h"
#import "BZKeyAcceptingCell.h"

@implementation BZEventForwardingMatrix

- (void)mouseDown:(NSEvent *)event {
	NSPoint pt = [self convertPoint:[event locationInWindow] fromView:[[self window] contentView]];

	int row, col;
	[self getRow:&row column:&col forPoint:pt];

	NSCell <BZClickableCell> *cell = [self cellAtRow:row column:col];
	if(cell && [cell respondsToSelector:@selector(mouseDown:)])
		[cell mouseDown:event];
}
- (void)mouseUp:(NSEvent *)event {
	NSPoint pt = [self convertPoint:[event locationInWindow] fromView:[[self window] contentView]];
	
	int row, col;
	[self getRow:&row column:&col forPoint:pt];
	
	NSCell <BZClickableCell> *cell = [self cellAtRow:row column:col];
	if(cell && [cell respondsToSelector:@selector(mouseUp:)])
		[cell mouseUp:event];
}

#pragma mark -

- (void)keyDown:(NSEvent *)event {
	NSCell <BZKeyAcceptingCell> *cell = [self keyCell];
	BOOL success = (cell && [cell respondsToSelector:@selector(keyDown:)]);
	if(success)
		success = [cell keyDown:event];
	if(!success)
		[super keyDown:event];
}
- (void)keyUp:(NSEvent *)event {
	NSCell <BZKeyAcceptingCell> *cell = [self keyCell];
	BOOL success = (cell && [cell respondsToSelector:@selector(keyUp:)]);
	if(success)
		success = [cell keyUp:event];
	if(!success)
		[super keyUp:event];
}

@end
