//
//  NSArray+map.h
//  Observer
//
//  Created by Regan Sarwas on 11/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (map)

- (NSMutableArray *)mapObjectsUsingBlock:(id (^)(id obj, NSUInteger idx))block;

@end
