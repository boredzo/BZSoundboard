//
//  BZDragAndDropMatrix.h
//  BZAudioPlayer
//
//  Created by Peter Hosey on 2006-01-21.
//  Copyright 2006 Peter Hosey. All rights reserved.
//

#import "BZEventForwardingMatrix.h"

@interface BZDragAndDropMatrix : BZEventForwardingMatrix {
	NSCell *lastHoveredCell, *currentHoveredCell;
	NSDragOperation lastDragOperation;
}

@end
