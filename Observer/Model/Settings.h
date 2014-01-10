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
#import "AutoPanStateMachine.h"

/*
 * Manages reading and writing from the NSDefaults system
 * class is not generic, it is specifc to an application
 * See the implementation for default values, and keys
 * keys should be kept current with keys in Settings bundle
 */

@interface Settings : NSObject

//Settings is a singleton obtained with the manager method
+ (Settings *) manager;

//properties always read from and write to NSDefaults, there is no caching by this class
//Views that need to updated thier display based on changes (made by settings app, or
//other views) need to subscribe to NSUserDefaultsDidChangeNotification

@property (nonatomic) NSInteger indexOfCurrentMap;
@property (nonatomic) NSInteger indexOfCurrentSurvey;
@property (nonatomic, strong) NSArray *surveys; //of NSURL

@property (nonatomic) BOOL showRemoteMaps;
@property (nonatomic) BOOL showRemoteProtocols;

@property (nonatomic) NSURL *urlForMaps;
@property (nonatomic) NSURL *urlForProtocols;

@property (nonatomic) MapAutoPanState autoPanMode;
@property (nonatomic) double maxSpeedForBearing;

@property (nonatomic) AGSSRUnit distanceUnitsForSightings;
@property (nonatomic) AGSSRUnit distanceUnitsForMeasuring;
@property (nonatomic) AngleDirection angleDistanceAngleDirection;
@property (nonatomic) double angleDistanceDeadAhead;
@property (nonatomic) NSNumber *angleDistanceLastDistance;
@property (nonatomic) NSNumber *angleDistanceLastAngle;

@end
