//
//  AKRAngleDistance.m
//  Observer
//
//  Created by Regan Sarwas on 12/12/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AKRAngleDistance.h"

@implementation AKRAngleDistance

- (instancetype)initWithAzimuth:(double)azimuth kilometer:(double)kilometers
{
    self = [super init];
    if (self)
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

    AGSPoint *currentPoint = [[AGSPoint alloc] initWithX:location.coordinate.longitude
                                                       y:location.coordinate.latitude
                                        spatialReference:[AGSSpatialReference WGS84]];
    
    AGSSpatialReference *sr = geometry.spatialReference;
    if (sr != nil) {
        currentPoint = (AGSPoint *)[AGSGeometryEngine projectGeometry:currentPoint toSpatialReference:sr];
        if ([AGSGeometryEngine geometry:geometry containsGeometry:currentPoint]) {
            return [[AKRAngleDistance alloc] initWithAzimuth:-1.0 kilometer:0.0];
        }
        AGSGeometry *geometry2 = [AGSGeometryEngine geodeticDensifyGeometry:geometry maxSegmentLength:5.0 lengthUnit:[AGSLinearUnit kilometers] curveType:AGSGeodeticCurveTypeGeodesic];
        AGSProximityResult *proximity = [AGSGeometryEngine nearestCoordinateInGeometry:geometry2 toPoint:currentPoint];
        AGSPoint *closestPoint = proximity.point;
        AGSGeodeticDistanceResult *result = [AGSGeometryEngine geodeticDistanceBetweenPoint1:currentPoint point2:closestPoint distanceUnit:[AGSLinearUnit kilometers] azimuthUnit:[AGSAngularUnit degrees] curveType:AGSGeodeticCurveTypeGeodesic];
        if (result) {
            return [[AKRAngleDistance alloc] initWithAzimuth:result.azimuth1 kilometer:result.distance];
        }
    }
    return [[AKRAngleDistance alloc] initWithAzimuth:-1.0 kilometer:-1.0];
}


@end
