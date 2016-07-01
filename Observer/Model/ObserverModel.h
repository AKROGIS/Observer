//
//  ObserverModel.h
//  Observer
//
//  Created by Regan Sarwas on 8/14/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

//CoreData entities
#import "Mission.h"
#import "AdhocLocation.h"
#import "AngleDistanceLocation.h"
#import "GpsPoint.h"
#import "GpsPoint+Location.h"
#import "LocationAngleDistance.h"
#import "Observation.h"
#import "Observation+Location.h"
#import "MissionProperty.h"
#import "MissionProperty+Location.h"
#import "MapReference.h"

#import "TrackLogSegment.h"

#import "AGSPoint+AKRAdditions.h"
#import "NSArray+map.h"

#import "Enumerations.h"
#import "Settings.h"

#import "Survey.h"

#import "Map.h"
#import "SProtocol.h"

#define kAttributePrefix                 @"A_"
#define kObservationPrefix               @"O_"
#define kObservationEntityName           @"Observation"
#define kMissionEntityName               @"Mission"
#define kMissionPropertyEntityName       @"MissionProperty"
#define kGpsPointEntityName              @"GpsPoint"
#define kMapEntityName                   @"Map"
#define kAngleDistanceLocationEntityName @"AngleDistanceLocation"
#define kAdhocLocationEntityName         @"AdhocLocation"
#define kTimestampKey                    @"timestamp"
#define kLabelLayerName                  @"ObservationLabels"

#define kTrackOff                        @"Off"
#define kTrackOn                         @"On"

#define kStaleInterval                   5 //Seconds before lastGpsPoint is considered too old to use.