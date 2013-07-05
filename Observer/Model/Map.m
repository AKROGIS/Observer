//
//  Map.m
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "Map.h"

@implementation Map


+ (Map *) randomMap {
    Map *map = [[Map alloc] init];
    if (map) {
        int i = 1 + rand() % 999;
        map.name = [NSString stringWithFormat:@"Map # %u", i];
        map.summary = [NSString stringWithFormat:@"This map covers the area around %u", i];
    }
    return map;
}

@end
