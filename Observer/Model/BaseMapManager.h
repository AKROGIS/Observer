//
//  BaseMapManager.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BaseMap.h"
#import "MapMonitoring.h"

@interface BaseMapManager : NSObject

+ (BaseMapManager *) sharedManager;  //this is single instance BaseMapManager that unrelated classes can share.

- (NSUInteger) count;
@property (strong, nonatomic) BaseMap *currentMap;
@property (weak, nonatomic) id <MapMonitoring> delegate;

- (BaseMap *) mapAtIndex:(NSUInteger)index;
- (void) addMap:(BaseMap *)map;
- (void) insertMap:(BaseMap *)map atIndex:(NSUInteger)index;
- (void) removeMap:(BaseMap *)map;
- (void) removeMapAtIndex:(NSUInteger)index;
- (void) moveMapAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

- (BOOL) isOutdatedMap:(BaseMap *)map;
- (BOOL) isOrphanMap:(BaseMap *)map;

- (void) refreshServerStatusForMap:(BaseMap *)map;

- (NSArray *) serverMaps; //of BaseMap  //nil => not queried; empty => no results

- (NSArray *) refreshServerMaps; //of BaseMap
- (NSArray *) getServerMaps; //of BaseMap

+ (NSURL *) cacheDirectory;
+ (NSURL *) documentsDirectory;

@end


