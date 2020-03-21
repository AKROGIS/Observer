//
//  ProtocolFeatureAllowedLocations.h
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <Foundation/Foundation.h>
#import "Enumerations.h"
#import "Map.h"

@protocol LocationPresenter <NSObject>

@optional;
@property (nonatomic, readonly) BOOL hasMap;
@property (nonatomic, readonly) BOOL hasGPS;
@property (nonatomic, readonly) BOOL mapIsProjected;

@end

// This immutable class is a protocol support object and is only created by a protocol feature
// It is highly dependent on the specification for a protocol document.
// property values are undefined (but generally nil) if initialized with non-conformant json
@interface ProtocolFeatureAllowedLocations : NSObject


//Get an array of localized names (NSString *) for a bit mask of WaysToLocateFeature
+ (NSArray *)stringsForLocations:(WaysToLocateFeature)locationFlags;
//Get the WaysToLocateFeature enum for a localized name
+ (WaysToLocateFeature) locationMethodForName:(NSString *)name;

// If locations is not a NSArray, then all the properties will be nil
- (instancetype)initWithLocationsJSON:(id)json version:(NSInteger) version NS_DESIGNATED_INITIALIZER;
- (instancetype) init __attribute__((unavailable("Must use initWithLocationsJSON:version: instead.")));

// The protocol provides the Angle Distance parameters
@property (nonatomic, readonly) BOOL definesAngleDistance;
// The units of measure (meters, feet, etc) for distances to observed items
@property (nonatomic, readonly) AGSLinearUnitID distanceUnits;
// The angle in degrees for dead ahead or true north
@property (nonatomic, readonly) double angleBaseline;
// What is the direction of increasing angles (clockwise or counter-clockwise)
@property (nonatomic, readonly) AngleDirection angleDirection;

@property (nonatomic, readonly) BOOL allowsAngleDistanceLocations;
@property (nonatomic, readonly) BOOL allowsMapLocations;

//If I have a location presenter, then I can filter the list based on the presenters capabilities
@property (nonatomic, weak) id<LocationPresenter> locationPresenter;

@property (nonatomic, readonly) NSUInteger countOfTouchChoices;
@property (nonatomic, readonly) NSUInteger countOfNonTouchChoices;
@property (nonatomic, readonly) WaysToLocateFeature nonTouchChoices; //bitmask of allowed choices
@property (nonatomic, readonly) WaysToLocateFeature touchChoices;    //bitmask of allowed choices
@property (nonatomic, readonly) WaysToLocateFeature initialNonTouchChoice;
@property (nonatomic, readonly) WaysToLocateFeature defaultNonTouchChoice;

@end
