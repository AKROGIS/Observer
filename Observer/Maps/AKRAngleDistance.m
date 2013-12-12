//
//  AKRAngleDistance.m
//  Observer
//
//  Created by Regan Sarwas on 12/12/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AKRAngleDistance.h"

@implementation AKRAngleDistance

- (id)initWithAzimuth:(double)azimuth kilometer:(double)kilometers
{
    if (self = [super init])
    {
        _azimuth = azimuth;
        _kilometers = kilometers;
    }
    return self;
}

+ (AKRAngleDistance *)angleDistanceFromLocation:(CLLocation *)location toGeometry:(AGSGeometry *)geometry
{
    if (!location || !geometry || geometry.isEmpty) {
        return [[AKRAngleDistance alloc] initWithAzimuth:-1.0 kilometer:-1.0];
    }

    AGSGeometryEngine *engine = [AGSGeometryEngine new];
    AGSPoint *currentPoint = [[AGSPoint alloc] initWithX:location.coordinate.longitude
                                                       y:location.coordinate.latitude
                                        spatialReference:[AGSSpatialReference wgs84SpatialReference]];
    currentPoint = (AGSPoint *)[engine projectGeometry:currentPoint toSpatialReference:geometry.spatialReference];
    if ([engine geometry:geometry containsGeometry:currentPoint]) {
        return [[AKRAngleDistance alloc] initWithAzimuth:-1.0 kilometer:0.0];
    }
    AGSGeometry *geometry2 = [engine geodesicDensifyGeometry:geometry withMaxSegmentLength:5.0 inUnit:AGSSRUnitKilometer];
    AGSProximityResult *proximity = [engine nearestCoordinateInGeometry:geometry2 toPoint:currentPoint];
    AGSPoint *closestPoint = proximity.point;
    AGSGeodesicDistanceResult *result = [engine geodesicDistanceBetweenPoint1:currentPoint point2:closestPoint inUnit:AGSSRUnitKilometer];
    if (!result) {
        return [[AKRAngleDistance alloc] initWithAzimuth:-1.0 kilometer:-1.0];
    }
    return [[AKRAngleDistance alloc] initWithAzimuth:result.azimuth1 kilometer:result.distance];
}

@end
