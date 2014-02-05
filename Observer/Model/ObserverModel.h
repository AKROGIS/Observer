//
//  ObserverModel.h
//  Observer
//
//  Created by Regan Sarwas on 8/14/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "AdhocLocation.h"
#import "AGSPoint+AKRAdditions.h"
#import "AngleDistanceLocation.h"
#import "Enumerations.h"
#import "GpsPoint.h"
#import "LocationAngleDistance.h"
#import "NSArray+map.h"
#import "Observation.h"
#import "MissionProperty.h"
#import "MapReference.h"
#import "Settings.h"


#define kObservationPrefix               @"Obs_"
#define kObservationEntityName           @"Observation"
#define kMissionEntityName               @"Mission"
#define kMissionPropertyEntityName       @"MissionProperty"
#define kGpsPointEntityName              @"GpsPoint"
#define kMapEntityName                   @"Map"
#define kAngleDistanceLocationEntityName @"AngleDistanceLocation"
#define kAdhocLocationEntityName         @"AdhocLocation"
