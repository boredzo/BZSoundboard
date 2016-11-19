//
//  BZNotifyingMatrix.m
//  BZSoundboard
//
//  Created by Peter Hosey on 2006-01-26.
//  Copyright 2006 Peter Hosey. All rights reserved.
//

#import "BZNotifyingMatrix.h"

NSString *BZNotifyingMatrixWillAddCellNotification = @"BZNotifyingMatrixWillAddCellNotification";
NSString *BZNotifyingMatrixDidAddCellNotification  = @"BZNotifyingMatrixDidAddCellNotification";

//userInfo keys:
NSString *BZNotifyingMatrix_ColumnIndex = @"BZNotifyingMatrix_ColumnIndex"; //NSNumber
NSString *BZNotifyingMatrix_RowIndex = @"BZNotifyingMatrix_RowIndex"; //NSNumber
NSString *BZNotifyingMatrix_NewCell = @"BZNotifyingMatrix_NewCell"; //NSCell (only exists in DidAddCell)

@implementation BZNotifyingMatrix

- (NSCell *)makeCellAtRow:(int)row column:(int)col {
	NSMutableDictionary *willAddCellUserInfo = [[NSMutableDictionary alloc] initWithCapacity:3U];
	NSNumber *num = [[NSNumber alloc] initWithInt:row];
	[willAddCellUserInfo setObject:num forKey:BZNotifyingMatrix_RowIndex];
	[num release];
	num = [[NSNumber alloc] initWithInt:col];
	[willAddCellUserInfo setObject:num forKey:BZNotifyingMatrix_ColumnIndex];
	[num release];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:BZNotifyingMatrixWillAddCellNotification
					  object:self
					userInfo:willAddCellUserInfo];

	NSCell *cell = [super makeCellAtRow:row column:col];

	NSMutableDictionary *didAddCellUserInfo = [willAddCellUserInfo mutableCopy];
	[willAddCellUserInfo release];
	[didAddCellUserInfo setObject:cell forKey:BZNotifyingMatrix_NewCell];

	[nc postNotificationName:BZNotifyingMatrixDidAddCellNotification
					  object:self
					userInfo:didAddCellUserInfo];
	[didAddCellUserInfo release];

	return cell;
}

@end
