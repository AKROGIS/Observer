//
//  AKRAngleDistance.h
//  Observer
//
//  Created by Regan Sarwas on 12/12/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>
#import <CoreLocation/CoreLocation.h>

@interface AKRAngleDistance : NSObject

@property (nonatomic, readonly) double kilometers;
@property (nonatomic, readonly) double azimuth;

- (instancetype)initWithAzimuth:(double)azimuth kilometer:(double)kilometers NS_DESIGNATED_INITIALIZER;
- (instancetype)init __attribute__((unavailable("Must use class initWithAzimuth:kilometer: or class methods.")));

//returns a new AKRAngleDistance with:
// kilometers = -1 indicates distance is not available (either input is nil)
//            =  0 indicates location is inside the geometry
// azimuth = -1 for all non-positive kilometers;
+ (AKRAngleDistance *)angleDistanceFromLocation:(CLLocation *)location toGeometry:(AGSGeometry *)geometry;

@end
