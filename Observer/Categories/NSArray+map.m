//
//  NSArray+map.m
//  Observer
//
//  Created by Regan Sarwas on 11/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "NSArray+map.h"

@implementation NSArray (map)

- (NSMutableArray *)mapObjectsUsingBlock:(id (^)(id obj, NSUInteger idx))block {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        //[result addObject:block(obj, idx)];
        id newItem = block(obj, idx);
        if (newItem) {
            [result addObject:newItem];
        }
    }];
    return result;
}

@end