//
//  CommonDefines.h
//  Observer
//
//  Created by Regan Sarwas on 4/17/17.
//  Copyright © 2017 GIS Team. All rights reserved.
//

#ifndef CommonDefines_h

#define kAngleDistanceDistanceUnits      AGSLinearUnitIDMeters
#define kAngleDistanceAngleDirection     AngleDirectionClockwise
#define kAngleDistanceDeadAhead          0.0

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

#define CommonDefines_h

#endif /* CommonDefines_h */
