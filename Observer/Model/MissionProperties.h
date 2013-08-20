//
//  MissionProperties.h
//  Observer
//
//  Created by Regan Sarwas on 8/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AdhocLocations, Attributes, GpsPoints, Missions;

@interface MissionProperties : NSManagedObject

@property (nonatomic, retain) AdhocLocations *adhocLocation;
@property (nonatomic, retain) Attributes *attributes;
@property (nonatomic, retain) GpsPoints *gpsPoint;
@property (nonatomic, retain) Missions *mission;

@end
