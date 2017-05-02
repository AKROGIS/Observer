//
//  Observation+Location.m
//  Observer
//
//  Created by Regan Sarwas on 5/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "AdhocLocation.h"
#import "AGSPoint+AKRAdditions.h"
#import "AngleDistanceLocation.h"
#import "CommonDefines.h"
#import "GpsPoint+Location.h"
#import "LocationAngleDistance.h"
#import "Observation+Location.h"

@implementation Observation (Location)

- (CLLocationCoordinate2D)locationOfFeature
{
    CLLocationCoordinate2D location;
    if (self.angleDistanceLocation) {
        LocationAngleDistance *angleDistance = [[LocationAngleDistance alloc] initWithDeadAhead:self.angleDistanceLocation.direction
                                                                                protocolFeature:nil
                                                                                  absoluteAngle:self.angleDistanceLocation.angle
                                                                                       distance:self.angleDistanceLocation.distance];
        location = [angleDistance locationFromLocation:self.gpsPoint.locationOfGps];
    }
    else if (self.adhocLocation && !self.gpsPoint) {
        location.latitude = self.adhocLocation.latitude;
        location.longitude = self.adhocLocation.longitude;
    }
    else {
        location = self.gpsPoint.locationOfGps;
    }

    return location;
}

- (CLLocationCoordinate2D)locationOfObserver
{
    CLLocationCoordinate2D location;
    if (self.adhocLocation) {
        //return the location of the gpsPoint matching the adhocLocation timestamp
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
        request.predicate = [NSPredicate predicateWithFormat:@"timestamp == %@",self.adhocLocation.timestamp];
        NSArray *results = [self.managedObjectContext executeFetchRequest:request error:nil];
        GpsPoint *gpsPoint = results.firstObject;
        location = gpsPoint.locationOfGps;
    } else {
        location = self.gpsPoint.locationOfGps;
    }
    return location;
}

- (AGSPoint *)pointOfFeatureWithSpatialReference:(AGSSpatialReference*)spatialReference
{
    CLLocationCoordinate2D location = self.locationOfFeature;
    return [AGSPoint pointFromLocation:location spatialReference:spatialReference];
}

- (AGSPoint *)pointOfObserverWithSpatialReference:(AGSSpatialReference*)spatialReference
{
    CLLocationCoordinate2D location = self.locationOfObserver;
    return [AGSPoint pointFromLocation:location spatialReference:spatialReference];
}

- (NSDate *)timestamp
{
    return self.gpsPoint ? self.gpsPoint.timestamp : self.adhocLocation.timestamp;
}

@end
