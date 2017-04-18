//
//  MissionProperty+Location.h
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import "MissionProperty.h"

@interface MissionProperty (Location)

- (CLLocationCoordinate2D)locationOfMissionProperty;
- (AGSPoint *)pointOfMissionPropertyWithSpatialReference:(AGSSpatialReference*)spatialReference;
- (NSDate *)timestamp;

@end
