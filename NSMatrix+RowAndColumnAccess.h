/*NSMatrix+RowAndColumnAccess.h
 *
 *Created by Mac-arena the Bored Zo on 2006-01-29.
 *Copyright 2006 Mac-arena the Bored Zo. All rights reserved.
 */

#import <Cocoa/Cocoa.h>

@interface NSMatrix (RowAndColumnAccess)

- (NSArray *)rowAtIndex:(unsigned)idx;
- (NSArray *)columnAtIndex:(unsigned)idx;

@end
