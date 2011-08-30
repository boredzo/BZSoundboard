//
//  AudioPlayer.h
//  AudioPlayer
//
//  Created by Mac-arena the Bored Zo on 2005-11-15.
//  Copyright 2005 Mac-arena the Bored Zo. All rights reserved.
//

@interface AudioPlayer : NSObject {
	IBOutlet NSWindow *playerWindow;
	IBOutlet NSMatrix *moviesMatrix;
	IBOutlet NSPopUpButton *devicesPopUp;

	int lastSelectedDeviceIndex; //in the pop-up menu (not adjusted for Default item, since it could be that item)
}

@end
