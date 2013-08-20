//
//  Observation.h
//  Observer
//
//  Created by Regan Sarwas on 8/19/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AdhocLocation, AngleDistanceLocation, AttributeSet, GpsPoint, Mission;

@interface Observation : NSManagedObject

@property (nonatomic, retain) AdhocLocation *adhocLocation;
@property (nonatomic, retain) AngleDistanceLocation *angleDistanceLocation;
@property (nonatomic, retain) AttributeSet *attributeSet;
@property (nonatomic, retain) GpsPoint *gpsPoint;
@property (nonatomic, retain) Mission *mission;

@end
