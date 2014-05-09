//
//  MissionProperty+Location.h
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "MissionProperty.h"

@interface MissionProperty (Location)

- (CLLocationCoordinate2D)locationOfMissionProperty;
- (AGSPoint *)pointOfMissionPropertyWithSpatialReference:(AGSSpatialReference*)spatialReference;
- (NSDate *)timestamp;

@end
