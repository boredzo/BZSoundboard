//
//  BZDragAndDropMatrix.m
//  BZAudioPlayer
//
//  Created by Peter Hosey on 2006-01-21.
//  Copyright 2006 Peter Hosey. All rights reserved.
//

#import "BZDragAndDropMatrix.h"

#import <objc/objc.h>

@implementation BZDragAndDropMatrix

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	NSPoint pt = [self convertPoint:[sender draggingLocation] fromView:[[sender draggingDestinationWindow] contentView]];
	int row, col;
	[self getRow:&row column:&col forPoint:pt];

	lastHoveredCell = [self cellAtRow:row column:col];
	if(lastHoveredCell && [lastHoveredCell respondsToSelector:@selector(draggingEntered:)])
		lastDragOperation = [lastHoveredCell draggingEntered:sender];
	else
		lastDragOperation = NSDragOperationNone;

	return lastDragOperation;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
	NSPoint pt = [self convertPoint:[sender draggingLocation] fromView:[[sender draggingDestinationWindow] contentView]];
	int row, col;
	[self getRow:&row column:&col forPoint:pt];

	currentHoveredCell = [self cellAtRow:row column:col];
	if(currentHoveredCell == lastHoveredCell) {
		if(currentHoveredCell && [currentHoveredCell respondsToSelector:@selector(draggingUpdated:)])
			lastDragOperation = [currentHoveredCell draggingUpdated:sender];
	} else {
		//we have moved from one cell into another.
		if(lastHoveredCell && [lastHoveredCell respondsToSelector:@selector(draggingExited:)])
			[lastHoveredCell draggingExited:sender];
		lastHoveredCell = currentHoveredCell;
		if([currentHoveredCell respondsToSelector:@selector(draggingEntered:)])
			lastDragOperation = [currentHoveredCell draggingEntered:sender];
	}

	return lastDragOperation;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
	if(lastHoveredCell && [lastHoveredCell respondsToSelector:@selector(draggingExited:)])
		[lastHoveredCell draggingExited:sender];

	lastHoveredCell = currentHoveredCell = nil;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
	NSPoint pt = [self convertPoint:[sender draggingLocation] fromView:[[sender draggingDestinationWindow] contentView]];
	int row, col;
	[self getRow:&row column:&col forPoint:pt];

	id cell = [self cellAtRow:row column:col];
	if(cell && [cell respondsToSelector:@selector(prepareForDragOperation:)])
		return [cell prepareForDragOperation:sender];

	return [super prepareForDragOperation:sender];
}
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	NSPoint pt = [self convertPoint:[sender draggingLocation] fromView:[[sender draggingDestinationWindow] contentView]];
	int row, col;
	[self getRow:&row column:&col forPoint:pt];

	id cell = [self cellAtRow:row column:col];
	if(cell && [cell respondsToSelector:@selector(performDragOperation:)])
		return [cell performDragOperation:sender];

	return NO;
}
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
	NSPoint pt = [self convertPoint:[sender draggingLocation] fromView:[[sender draggingDestinationWindow] contentView]];
	int row, col;
	[self getRow:&row column:&col forPoint:pt];

	id cell = [self cellAtRow:row column:col];
	if(cell && [cell respondsToSelector:@selector(concludeDragOperation:)])
		[cell concludeDragOperation:sender];
}

@end
