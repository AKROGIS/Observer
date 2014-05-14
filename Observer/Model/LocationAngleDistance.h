//
//  LocationAngleDistance.h
//  Observer
//
//  Created by Regan Sarwas on 8/8/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

/*
 Facilitates entering/editing/saving angle/distance observations and creating new points
 
 Use Cases:
 1) Create a new location with a fixed protocol and angle for deadAhead.
 User edits angle distance (no change to protocol or course allowed).
 When done, create new point, and save absoulute angle, distance in meters.
 
 2) Create a new location with a deadAhead and no protocol.
 User edits angle,distance (no change to deadAhead allowed).
 User can change basis of angle/distance through settings or UI.
 Changes to basis do not change the angle/distance the user entered.
 When done, create new point, and save absolute angle, distance in meters
 based on current basis settings.
 
 3) Create a new location with prior absoluteAngle, distanceInMeters.  Historical
 deadAhead (from related GPS basis point) and project protocol are also provided.
 Relative angle and distance are calculated (based on protocol) and provided to the
 user for editing. When done, create new point, and save absoulute angle,
 distance in meters (based on protocol).
 
 4) Create a new location with prior absoluteAngle, distanceInMeters, and historical
 deadAhead (from related GPS basis point).  No protocol is provided.
 Relative angle and distance are calculated based on the current basis. Note, if the
 user has changed the basis, the relative angle and distance will be different than when
 they saved the absolute angle/distance, but the point will be in the same location.
 The user may then change the realtive angle/distance and basis.
 when done, an absolute angle/distance are calculated based on current basis.
 A new point is created, and the absolute angle/distance are saved.
 */

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>
#import "ProtocolFeature.h"
#import "Enumerations.h"

@interface LocationAngleDistance : NSObject

//designated initializer
//This will initialize the readonly properties deadAhead, protocol feature, distanceMeters and absoluteAngles.
//values must be provided in the database neutral units and frame of reference specified below.
- (id) initWithDeadAhead:(double)deadAhead protocolFeature:(ProtocolFeature *)feature absoluteAngle:(double)angle distance:(double)distance;

//convenience initializer with default values of -1 for angle and distance.
- (id) initWithDeadAhead:(double)deadAhead protocolFeature:(ProtocolFeature *)feature;

//convenience initializer with default values of 0 for deadAhead, nil for protocol feature and -1 for angle and distance.
- (id) init;

//the course (or heading) for dead ahead (positive = clockwise, with 0 = north)
//default value = 0.0
@property (nonatomic,readonly) double deadAhead;

//the protocol feature may specify how angle/distance measurements are to be taken
@property (nonatomic,strong,readonly) ProtocolFeature *feature;

//the current angle provided by the user - a nullable double
//in the reference frame provided by the protocol, or the NSUserDefaults
@property (nonatomic,strong) NSNumber *angle;
//the current angle in a neutral reference frame for the database
//0 is north, and angles increase clockwise to 360 degrees;
//The value returned is determined by the frame of reference in effect when called.
//a negative value indicates no valid angle
@property (nonatomic,readonly) double absoluteAngle;
//the default angle provided in the initializer in the reference frame of angle - a nullable double
//This is in the reference frame in effect during initialization.
//this is used to check for changes to the angle
@property (nonatomic,strong,readonly) NSNumber *defaultAngle;

//the current distance provided by the user - a nullable positive double
//in the units provided by the protocol, or the NSUserDefaults
//changes in this property will also be reflected in distanceMeters
@property (nonatomic,strong) NSNumber *distance;
//the current distance in meters for the database
//The value returned is determined by the basis in effect when called.
//a non-positive value indicates no valid distance
@property (nonatomic,readonly) double distanceMeters;
//the default distance (a nullable positive double) provided in the initializer
//This is in the units of distance based on the basis in effect during initialization.
//this is used to check for changes to the distance
@property (nonatomic,strong,readonly) NSNumber *defaultDistance;

//Current State

- (BOOL) usesProtocol;
- (BOOL) isValid;
- (BOOL) isComplete;
- (NSString *) basisDescription;

//Create a new observation point
//The input point is the point of reference for the angle/distance measurements
//Requires non-null input and 0 <= deadAhead, 0 < distanceMeters, 0 <= absoluteAngle
- (AGSPoint *) pointFromPoint:(AGSPoint *)point;
- (CLLocationCoordinate2D)locationFromLocation:(CLLocationCoordinate2D)location;


@end
