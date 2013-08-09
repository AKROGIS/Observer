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

//Inputs

//The point of reference for the angle/distance measurements - Required
@property (strong, nonatomic) AGSPoint *gpsPoint;
//the course (or heading) for dead ahead (positive = clockwise, with 0 = north) - Required
@property (nonatomic) NSNumber *deadAhead;
//the protocol may specify how angle/distance measurements are to be taken
@property (nonatomic, strong) SurveyProtocol *protocol;
//the default angle provided by the caller - a nullable double
@property (nonatomic, strong) NSNumber *defaultAngle;
//the default distance provided by the caller - a nullable positive double
@property (nonatomic, strong) NSNumber *defaultDistance;

//Current State

- (BOOL) usesProtocol;
- (BOOL) isValid;
- (BOOL) isComplete;
- (NSString *) basisDescription;

//Outputs

//the current angle provided by the user - a nullable double
@property (nonatomic, strong) NSNumber *angle;
//the current distance provided by the user - a nullable positive double
@property (nonatomic, strong) NSNumber *distance;

//the new observation point, requires non-null gpsPoint, deadAhead, distance, angle,
- (AGSPoint *) observationPoint;


@end
