//
//  ProtocolFeatureAllowedLocations.h
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Enumerations.h"

@interface ProtocolFeatureAllowedLocations : NSObject

//locations is not copied, because it (and its contents are immuttable
- (id)initWithLocations:(NSArray *)locations;
- (id) init __attribute__((unavailable("Must use initWithLocations: instead.")));

@property (strong, nonatomic, readonly) NSArray *locations;

@property (nonatomic, readonly) BOOL includesGps;
@property (nonatomic, readonly) BOOL includesAngleDistance;
@property (nonatomic, readonly) BOOL includesAdhocTouch;
@property (nonatomic, readonly) BOOL includesAdhocTarget;
@property (nonatomic, readonly) BOOL hasDefault;
@property (nonatomic, readonly) BOOL multipleChoices;

//Does the protocol define the units of measure for angle/distance observations
@property (nonatomic, readonly) BOOL definesAngleDistanceMeasures;

// Does the protocol require that all observations are angle distance
@property (nonatomic, readonly) BOOL requireAngleDistance;

// The units of measure (meters, feet, etc) for distances to observed items
@property (nonatomic, readonly) AGSSRUnit distanceUnits;

// The angle in degrees for dead ahead or true north
@property (nonatomic, readonly) double angleBaseline;

// What is the direction of increasing angles (clockwise or counter-clockwise)
@property (nonatomic, readonly) AngleDirection angleDirection;

@end
