//
//  SBDocument.h
//  BZ Soundboard
//
//  Created by Peter Hosey on 2005-11-15.
//  Copyright 2005 Peter Hosey. All rights reserved.
//

@class BZResizeNotifyingWindow;

@interface SBDocument : NSDocument {
	IBOutlet BZResizeNotifyingWindow *playerWindow;
	IBOutlet NSMatrix *moviesMatrix;
	IBOutlet NSPopUpButton *devicesPopUp;

	NSMutableDictionary *plistRepresentation;
	NSPropertyListFormat plistFormat;

	NSSize sizeBeforeResize; //either of the matrix (in cells) or each cell (in points)
	NSSize cellSizeDuringResize;

	float volume;
	int lastSelectedDeviceIndex; //in the pop-up menu (not adjusted for Default item, since it could be that item)

	unsigned reservedFlags: 29;
	unsigned undoEnabled: 1; //disabled by -performUndo: around setting the movie (which would ordinarily trigger an undo push)
	unsigned resizingMatrix: 1; //resizes are cell-by-cell
	unsigned resizingCells: 1; //resizes are point-by-point
}

@end
