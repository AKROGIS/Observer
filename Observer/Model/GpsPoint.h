//
//  GpsPoint.h
//  Observer
//
//  Created by Regan Sarwas on 8/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Mission, MissionProperty, Observation;

@interface GpsPoint : NSManagedObject

@property (nonatomic) double altitude;
@property (nonatomic) double course;
@property (nonatomic) double horizontalAccuracy;
@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic) double speed;
@property (nonatomic, retain) NSDate *timestamp;
@property (nonatomic) double verticalAccuracy;
@property (nonatomic, retain) Mission *mission;
@property (nonatomic, retain) MissionProperty *missionProperty;
@property (nonatomic, retain) Observation *observation;

@end
