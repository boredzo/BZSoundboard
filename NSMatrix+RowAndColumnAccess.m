/*NSMatrix+RowAndColumnAccess.m
 *
 *Created by Mac-arena the Bored Zo on 2006-01-29.
 *Copyright 2006 Mac-arena the Bored Zo. All rights reserved.
 */

#import "NSMatrix+RowAndColumnAccess.h"

@implementation NSMatrix (RowAndColumnAccess)

- (NSArray *)rowAtIndex:(unsigned)idx {
	unsigned rowLength = [self numberOfColumns];
	NSRange range = { idx * rowLength, rowLength };
	return [[self cells] subarrayWithRange:range];
}
- (NSArray *)columnAtIndex:(unsigned)idx {
	unsigned numRows = [self numberOfRows];
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:numRows];

	for(unsigned y = 0U; y < numRows; ++y)
		[array addObject:[self cellAtRow:y column:idx]];

	return array;
}

@end
