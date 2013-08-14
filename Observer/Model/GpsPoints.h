//
//  GpsPoints.h
//  Observer
//
//  Created by Regan Sarwas on 8/14/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface GpsPoints : NSManagedObject

@property (nonatomic) double altitude;
@property (nonatomic) double course;
@property (nonatomic) double horizontalAccuracy;
@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic) double speed;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic) double verticalAccuracy;
@property (nonatomic, retain) NSManagedObject *adhocLocation;
@property (nonatomic, retain) NSManagedObject *angleDistanceLocation;
@property (nonatomic, retain) NSManagedObject *feature;

@end
