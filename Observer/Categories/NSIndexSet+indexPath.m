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
    NSMutableArray *paths = [NSMutableArray new];
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [paths addObject:[NSIndexPath indexPathForRow:idx inSection:section]];
    }];
    return paths;
}

@end
