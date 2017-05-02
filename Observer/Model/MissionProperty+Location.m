//
//  MissionProperty+Location.m
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "MissionProperty+Location.h"
#import "GpsPoint+Location.h"
#import "AGSPoint+AKRAdditions.h"
#import "AdhocLocation.h"

@implementation MissionProperty (Location)

- (CLLocationCoordinate2D)locationOfMissionProperty
{
    CLLocationCoordinate2D location;
    if (self.gpsPoint) {
        location = self.gpsPoint.locationOfGps;
    }
    else {
        location.latitude = self.adhocLocation.latitude;
        location.longitude = self.adhocLocation.longitude;
    }
    return location;
}

- (AGSPoint *)pointOfMissionPropertyWithSpatialReference:(AGSSpatialReference*)spatialReference
{
    CLLocationCoordinate2D location = self.locationOfMissionProperty;
    return [AGSPoint pointFromLocation:location spatialReference:spatialReference];
}

- (NSDate *)timestamp
{
    return self.gpsPoint ? self.gpsPoint.timestamp : self.adhocLocation.timestamp;
}

@end
