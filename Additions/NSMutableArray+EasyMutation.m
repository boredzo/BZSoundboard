//
//  NSMutableArray+EasyMutation.m
//  BZSoundboard
//
//  Created by Peter Hosey on 2006-01-22.
//  Copyright 2006 Peter Hosey. All rights reserved.
//

#import "NSMutableArray+EasyMutation.h"


@implementation NSMutableArray (EasyMutation)

- (void)setObject:(id)obj atIndex:(unsigned)idx {
	unsigned count = [self count];
	if(idx == count)
		[self addObject:obj];
	else //<>
		[self replaceObjectAtIndex:idx withObject:obj];
}

@end
