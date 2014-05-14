//
//  GpsPoint+Location.m
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "GpsPoint+Location.h"
#import "AGSPoint+AKRAdditions.h"

@implementation GpsPoint (Location)

- (CLLocationCoordinate2D)locationOfGps
{
    CLLocationCoordinate2D location;
    location.latitude = self.latitude;
    location.longitude = self.longitude;
    return location;
}

- (AGSPoint *)pointOfGpsWithSpatialReference:(AGSSpatialReference*)spatialReference
{
    CLLocationCoordinate2D location = [self locationOfGps];
    return [AGSPoint pointFromLocation:location spatialReference:spatialReference];
}

@end
