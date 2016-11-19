/*NSMatrix+RowAndColumnAccess.h
 *
 *Created by Peter Hosey on 2006-01-29.
 *Copyright 2006 Peter Hosey. All rights reserved.
 */

#import <Cocoa/Cocoa.h>

@interface NSMatrix (RowAndColumnAccess)

- (NSArray *)rowAtIndex:(unsigned)idx;
- (NSArray *)columnAtIndex:(unsigned)idx;

@end
