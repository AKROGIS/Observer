//
//  Settings.h
//  Observer
//
//  Created by Regan Sarwas on 7/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>
#import "Enumerations.h"

/*
 * Manages reading and writing from the NSDefaults system
 * class is not generic, it is specifc to an application
 * See the implementation for default values, and keys
 * keys should be kept current with keys in Settings bundle
 */

@interface Settings : NSObject

//Short cut for a cached instance of [[[Settings alloc] init] registerDefaults]
//This should be prefered, to prevent re-reading the settings bundle.
+ (Settings *) manager;

//Loads the defaults from the settings bundle
- (Settings *) registerDefaults;

//properties always read from and write to NSDefaults, there is no caching by this class
//Views that need to updated thier display based on changes (made by settings app, or
//other views should subscribe to NSUserDefaultsDidChangeNotification

@property (nonatomic) NSUInteger indexOfCurrentMap;
@property (nonatomic) NSUInteger indexOfCurrentSurvey;

@property (nonatomic) BOOL autoPanEnabled;
@property (nonatomic) AGSLocationDisplayAutoPanMode autoPanMode;

@property (nonatomic) AGSSRUnit distanceUnitsForSightings;
@property (nonatomic) AGSSRUnit distanceUnitsForMeasuring;
@property (nonatomic) AngleDirection angleDistanceAngleDirection;
@property (nonatomic) double angleDistanceDeadAhead;
@property (nonatomic) NSNumber *angleDistanceLastDistance;
@property (nonatomic) NSNumber *angleDistanceLastAngle;

@end
