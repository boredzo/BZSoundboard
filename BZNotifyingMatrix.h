//
//  BZNotifyingMatrix.h
//  BZSoundboard
//
//  Created by Peter Hosey on 2006-01-26.
//  Copyright 2006 Peter Hosey. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *BZNotifyingMatrixWillAddCellNotification;
extern NSString *BZNotifyingMatrixDidAddCellNotification;

//userInfo keys:
extern NSString *BZNotifyingMatrix_ColumnIndex; //NSNumber
extern NSString *BZNotifyingMatrix_RowIndex; //NSNumber
extern NSString *BZNotifyingMatrix_NewCell; //NSCell (only exists in DidAddCell)

@interface BZNotifyingMatrix : NSMatrix {

}

@end
