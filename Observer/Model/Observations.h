//
//  Observations.h
//  Observer
//
//  Created by Regan Sarwas on 8/14/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AdhocLocations, AngleDistanceLocations, Attributes, GpsPoints;

@interface Observations : NSManagedObject

@property (nonatomic, retain) GpsPoints *gpsPoint;
@property (nonatomic, retain) Attributes *attributes;
@property (nonatomic, retain) AdhocLocations *adhocLocation;
@property (nonatomic, retain) AngleDistanceLocations *angleDistanceLocation;

@end
