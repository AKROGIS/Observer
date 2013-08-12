//
//  LocationAngleDistance.h
//  Observer
//
//  Created by Regan Sarwas on 8/8/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>
#import "SurveyProtocol.h"
#import "Enumerations.h"

@interface LocationAngleDistance : NSObject

//designated initializer
//This will initialize the readonly properties deadAhead, distanceMeters and absoluteAngles.
//values must be provided in the database neutral units and frame of reference specified below.
- (id) initWithCourse:(double)course Angle:(double)angle Distance:(double)distance;

//conenience initializer with default values of -1 for angle and distance.
- (id) initWithCourse:(double)course;

//conenience initializer with default values of 0 for course and -1 for angle and distance.
- (id) init;

//The point of reference for the angle/distance measurements
//Required to calculate the observationPoint
@property (strong, nonatomic) AGSPoint *gpsPoint;

//the course (or heading) for dead ahead (positive = clockwise, with 0 = north)
//default value = 0.0
@property (nonatomic,readonly) double deadAhead;

//the protocol may specify how angle/distance measurements are to be taken
@property (nonatomic, strong) SurveyProtocol *protocol;

//the current angle provided by the user - a nullable double
//in the reference frame provided by the protocol, or the NSUserDefaults
//Changes to this property will be reflected in absoluteAngle
@property (nonatomic, strong) NSNumber *angle;
//the current angle in a neutral reference frame for the database
//0 is north, and angles increase clockwise to 360 degrees;
//a negative value indicates no valid angle
@property (nonatomic, readonly) double absoluteAngle;
//the default angle provided in the initializer in the reference frame of angle - a nullable double
//this is used to check for changes to the angle
@property (nonatomic, strong, readonly) NSNumber *defaultAngle;

//the current distance provided by the user - a nullable positive double
//in the units provided by the protocol, or the NSUserDefaults
//changes in this property will also be reflected in distanceMeters
@property (nonatomic, strong) NSNumber *distance;
//the current distance in meters for the database
//a non-positive value indicates no valid distance
@property (nonatomic, readonly) double distanceMeters;
//the default distance provided in the initializer in the units of distance - a nullable positive double
//this is used to check for changes to the distance
@property (nonatomic, strong, readonly) NSNumber *defaultDistance;

//Current State

- (BOOL) usesProtocol;
- (BOOL) isValid;
- (BOOL) isComplete;
- (NSString *) basisDescription;

//the new observation point, requires non-null gpsPoint
//and 0 <= deadAhead, 0 < distanceMeters, 0 <= absoluteAngle
- (AGSPoint *) observationPoint;


@end
