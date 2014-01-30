//
//  ProtocolFeatureAllowedLocations.h
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Enumerations.h"


// This immutable class is a protocol support object and is only created by a protocol feature
// It is highly dependent on the specification for a protocol document.
// property values are undefined (but generally nil) if initialized with non-conformant json
@interface ProtocolFeatureAllowedLocations : NSObject

// If locations is not a NSArray, then all the properties will be nil
- (id)initWithLocationsJSON:(id)json;
- (id) init __attribute__((unavailable("Must use initWithLocationsJSON: instead.")));

@property (nonatomic, readonly) BOOL includesGps;
@property (nonatomic, readonly) BOOL includesAngleDistance;
@property (nonatomic, readonly) BOOL includesAdhocTouch;
@property (nonatomic, readonly) BOOL includesAdhocTarget;
@property (nonatomic, readonly) BOOL hasDefault;
@property (nonatomic, readonly) BOOL multipleChoices;

// The units of measure (meters, feet, etc) for distances to observed items
@property (nonatomic, readonly) BOOL definesDistanceUnits;
@property (nonatomic, readonly) AGSSRUnit distanceUnits;

// The angle in degrees for dead ahead or true north
@property (nonatomic, readonly) BOOL definesAngleBaseline;
@property (nonatomic, readonly) double angleBaseline;

// What is the direction of increasing angles (clockwise or counter-clockwise)
@property (nonatomic, readonly) BOOL definesAngleDirection;
@property (nonatomic, readonly) AngleDirection angleDirection;

@end
