//
//  MissionProperty.h
//  Observer
//
//  Created by Regan Sarwas on 12/11/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AdhocLocation, GpsPoint, Mission;

@interface MissionProperty : NSManagedObject

@property (nonatomic) BOOL observing;
@property (nonatomic, retain) AdhocLocation *adhocLocation;
@property (nonatomic, retain) GpsPoint *gpsPoint;
@property (nonatomic, retain) Mission *mission;

@end
