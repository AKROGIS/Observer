//
//  Protocol.h
//  Observer
//
//  Created by Regan Sarwas on 7/29/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Enumerations.h"

@interface Protocol : NSObject

//Does the protocol define the units of measure for angle/distance observations
@property (nonatomic) BOOL definesAngleDistanceMeasures;

// Does the protocol require that all observations are angle distance
@property (nonatomic) BOOL requireAngleDistance;

// The units of measure (meters, feet, etc) for distances to observed items
@property (nonatomic) AGSSRUnit distanceUnits;

// The angle in degrees for dead ahead or true north
@property (nonatomic) double angleBaseline;

// What is the direction of increasing angles (clockwise or counter-clockwise)
@property (nonatomic) AngleDirection angleDirection;

// The list of point features
@property (strong, nonatomic) NSArray *features; //of Features

// The set of attributes collected along a tracklog
@property (strong, nonatomic) NSArray *segmentAttributes;


@end
