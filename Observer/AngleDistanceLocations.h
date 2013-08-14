//
//  AngleDistanceLocations.h
//  Observer
//
//  Created by Regan Sarwas on 8/14/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GpsPoints;

@interface AngleDistanceLocations : NSManagedObject

@property (nonatomic) double angle;
@property (nonatomic) double direction;
@property (nonatomic) double distance;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, retain) GpsPoints *gpsPoint;

@end
