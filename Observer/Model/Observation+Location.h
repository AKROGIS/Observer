//
//  Observation+Location.h
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//


// An observation can only have the following combinations
// non-nil references                 feature Location  observer Location
// ==================                 ================  =================
// gpsPoint                           gpsPoint          gpsPoint
// adhocLocation                      adhocLocation     gpsPoint at adhocLocation Timestamp
// gpsPoint && adhocLocation          gpsPoint          gpsPoint at adhocLocation Timestamp
// gpsPoint && angleDistanceLocation  calculated        gpsPoint

#import <ArcGIS/ArcGIS.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import "Observation.h"

@interface Observation (Location)

@property (nonatomic, readonly) CLLocationCoordinate2D locationOfFeature;
@property (nonatomic, readonly) CLLocationCoordinate2D locationOfObserver;
- (AGSPoint *)pointOfFeatureWithSpatialReference:(AGSSpatialReference*)spatialReference;
- (AGSPoint *)pointOfObserverWithSpatialReference:(AGSSpatialReference*)spatialReference;
@property (nonatomic, readonly, copy) NSDate *timestamp;

@end
