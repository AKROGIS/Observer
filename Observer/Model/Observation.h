//
//  Observation.h
//  Observer
//
//  Created by Regan Sarwas on 12/11/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AdhocLocation, AngleDistanceLocation, GpsPoint, Mission;

@interface Observation : NSManagedObject

@property (nonatomic, retain) AdhocLocation *adhocLocation;
@property (nonatomic, retain) AngleDistanceLocation *angleDistanceLocation;
@property (nonatomic, retain) GpsPoint *gpsPoint;
@property (nonatomic, retain) Mission *mission;

@end
