//
//  Maps.m
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "Maps.h"
#import "Map.h"

@implementation Maps

+ (NSArray *) localMaps {
    NSMutableArray * maps = [[NSMutableArray alloc] init];
    if (maps) {
        for (int i = 0; i < 2 + rand() % 5; i++) {
            [maps addObject:[Map randomMap]];
        }
    }
    return [maps copy];
}

+ (NSArray *) serverMaps {
    NSMutableArray * maps = [[NSMutableArray alloc] init];
    if (maps) {
        for (int i = 0; i < 2 + rand() % 5; i++) {
            [maps addObject:[Map randomMap]];
        }
    }
    return [maps copy];
}


@end
