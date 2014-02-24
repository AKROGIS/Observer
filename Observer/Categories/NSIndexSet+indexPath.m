//
//  NSIndexSet+indexPath.m
//  Observer
//
//  Created by Regan Sarwas on 11/27/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "NSIndexSet+indexPath.h"

@implementation NSIndexSet (indexPath)

- (NSArray *)indexPathsWithSection:(NSUInteger)section
{
    NSAssert1(section < NSIntegerMax, @"%@", @"section is greater then NSIntegerMax");
    NSAssert(self.count < NSIntegerMax, @"%@", @"array index is greater then NSIntegerMax");
    NSMutableArray *paths = [NSMutableArray new];
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [paths addObject:[NSIndexPath indexPathForRow:(NSInteger)idx inSection:(NSInteger)section]];
    }];
    return paths;
}

@end
