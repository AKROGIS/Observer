//
//  Maps.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Map.h"
#import "MapMonitoring.h"

@interface Maps : NSObject

- (NSUInteger) count;
@property (strong, nonatomic) Map *currentMap;
@property (weak, nonatomic) id <MapMonitoring> delegate;

- (Map *) mapAtIndex:(NSUInteger)index;
- (void) addMap:(Map *)map;
- (void) insertMap:(Map *)map atIndex:(NSUInteger)index;
- (void) removeMap:(Map *)map;
- (void) removeMapAtIndex:(NSUInteger)index;
- (void) moveMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

+ (NSArray *) refreshServerMaps; //of Map
+ (NSArray *) getServerMaps; //of Map

+ (NSURL *) cacheDirectory;
+ (NSURL *) documentsDirectory;

@end


