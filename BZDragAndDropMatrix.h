//
//  BZDragAndDropMatrix.h
//  BZAudioPlayer
//
//  Created by Mac-arena the Bored Zo on 2006-01-21.
//  Copyright 2006 Mac-arena the Bored Zo. All rights reserved.
//

#import "BZEventForwardingMatrix.h"

@interface BZDragAndDropMatrix : BZEventForwardingMatrix {
	NSCell *lastHoveredCell, *currentHoveredCell;
	NSDragOperation lastDragOperation;
}

@end
