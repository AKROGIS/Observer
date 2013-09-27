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
                                     //This is not a "true" singleton, it is still possible to create another object with [[BaseMapManager alloc] init]
                                     //I only need/want one shareable instance in my app, so I will use a factory method to return the sharedManager
+ (NSURL *) cacheDirectory;
+ (NSURL *) documentsDirectory;


@property (strong, nonatomic) BaseMap *currentMap;
@property (weak, nonatomic) id <MapMonitoring> delegate;


//A convenience to ensure that the maps are loaded, probably done on a background thread, at startup
- (void) loadLocalMaps;

- (NSUInteger) count;
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


@end


