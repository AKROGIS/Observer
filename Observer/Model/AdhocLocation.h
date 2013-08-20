//
//  AdhocLocation.h
//  Observer
//
//  Created by Regan Sarwas on 8/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Map, MissionProperty, Observation;

@interface AdhocLocation : NSManagedObject

@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic, retain) NSDate *timestamp;
@property (nonatomic, retain) Map *map;
@property (nonatomic, retain) MissionProperty *missionProperty;
@property (nonatomic, retain) Observation *observation;

@end
