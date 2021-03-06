//
//  LocationAngleDistance.m
//  Observer
//
//  Created by Regan Sarwas on 8/8/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "LocationAngleDistance.h"
#import "AGSPoint+AKRAdditions.h"
#import "Settings.h"
#import "CommonDefines.h"

@interface LocationAngleDistance ()

@property (nonatomic,strong) AGSSpatialReference *srWithMeters;

@end

@implementation LocationAngleDistance

- (instancetype) init
{
    return [self initWithDeadAhead:0.0 protocolFeature:nil absoluteAngle:-1.0 distance:-1.0];
}

- (instancetype) initWithDeadAhead:(double)deadAhead protocolFeature:(ProtocolFeature *)feature
{
    return [self initWithDeadAhead:deadAhead protocolFeature:feature absoluteAngle:-1.0 distance:-1.0];
}

- (instancetype) initWithDeadAhead:(double)deadAhead protocolFeature:(ProtocolFeature *)feature absoluteAngle:(double)angle distance:(double)distance
{
    self = [super init];
    if (self)
    {
        _feature = feature;
        _deadAhead = deadAhead;
        _angle = [self numberFromAbsoluteAngle:angle];
        _defaultAngle = _angle;
        _distance = [self numberFromDistanceMeters:distance];
        _defaultDistance = _distance;
    }
    return self;
}

#pragma mark - Public Properties

- (NSString *)basisDescription
{
    double referenceAngle = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleBaseline : kAngleDistanceDeadAhead;
    AGSSRUnit distanceUnits = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.distanceUnits : kAngleDistanceDistanceUnits;
    AngleDirection angleDirection = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleDirection : kAngleDistanceAngleDirection;
    
    NSString *description =
    [NSString stringWithFormat:@"Angle increases %@ with dead ahead equal to %u degrees. Distance is in %@.",
     angleDirection == AngleDirectionClockwise ? @"clockwise" : @"counter-clockwise",
     (int)referenceAngle,
     distanceUnits == AGSSRUnitMeter ? @"meters" :
     distanceUnits == AGSSRUnitFoot ? @"feet" :
     distanceUnits == AGSSRUnitInternationalYard ? @"yards" : @"unknown units"
     ];
    return description;
}

- (double) absoluteAngle
{
    return [self doubleFromAngle:self.angle];
}

- (double) distanceMeters
{
    return [self doubleFromDistance:self.distance];
}

- (double)perpendicularMeters
{
    double radians = (self.absoluteAngle - self.deadAhead) * M_PI / 180.0;
    return fabs(self.distanceMeters * sin(radians));
}

- (BOOL) usesProtocol
{
    return self.feature.allowedLocations.definesAngleDistance;
}

- (BOOL) isValid
{
    return 0 <= self.deadAhead;
}

- (BOOL) inputAngleWrapsStern
{
    double referenceAngle = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleBaseline : kAngleDistanceDeadAhead;
    double inputAngle = self.angle.doubleValue;
    return (inputAngle < referenceAngle - 180.0 || referenceAngle + 180.0 < inputAngle);
}

- (BOOL) isComplete
{
    return (0 < self.distanceMeters)  && (0 <= self.absoluteAngle);
}

- (AGSPoint *)pointFromPoint:(AGSPoint *)point
{
    if (!self.isValid || !self.isComplete)
        return nil;
    
    return [point pointWithAngle:self.absoluteAngle distance:self.distanceMeters units:AGSSRUnitMeter];
}

- (CLLocationCoordinate2D)locationFromLocation:(CLLocationCoordinate2D)location
{
    //Find the UTM zone based on our lat/long, then use AGS to create a LL point
    // project to UTM, do angle/distance offset, then project new UTM point to LL
    NSUInteger zone = 1 + (NSUInteger)((180 + location.longitude)/6.0);
    NSUInteger wkid = location.latitude < 0 ? 32700 + zone : 32600 + zone;
    AGSSpatialReference *utm = [AGSSpatialReference spatialReferenceWithWKID:wkid];
    AGSSpatialReference *wgs84  = [AGSSpatialReference wgs84SpatialReference];
    AGSPoint *startLL = [AGSPoint pointFromLocation:location spatialReference:wgs84];
    AGSGeometryEngine *ge = [AGSGeometryEngine defaultGeometryEngine];
    AGSPoint *startUTM = (AGSPoint *)[ge projectGeometry:startLL toSpatialReference:utm];
    AGSPoint *endUTM = [startUTM pointWithAngle:self.absoluteAngle distance:self.distanceMeters units:AGSSRUnitMeter];
    AGSPoint *endLL = (AGSPoint *)[ge projectGeometry:endUTM toSpatialReference:wgs84];
    CLLocationCoordinate2D newLocation;
    newLocation.latitude = endLL.y;
    newLocation.longitude = endLL.x;
    return newLocation;
}

//- (CLLocationCoordinate2D)locationFromLocation1:(CLLocationCoordinate2D)location
//{
//    AGSSpatialReference *wgs84  = [AGSSpatialReference wgs84SpatialReference];
//    AGSPoint *startLL = [AGSPoint pointFromLocation:location spatialReference:wgs84];
//    AGSPoint *endLL = [startLL pointWithAngle:self.absoluteAngle distance:self.distanceMeters units:AGSSRUnitMeter];
//    CLLocationCoordinate2D newLocation;
//    newLocation.latitude = endLL.y;
//    newLocation.longitude = endLL.x;
//    return newLocation;
//}

//- (CLLocationCoordinate2D)locationFromLocation2:(CLLocationCoordinate2D)startLocation
//{
//    // haversine formula From http://www.movable-type.co.uk/scripts/latlong.html
//    const double radiusEarthMeters = 6371010.0;
//    double distRatio = self.distanceMeters / radiusEarthMeters;
//    double distRatioSine = sin(distRatio);
//    double distRatioCosine = cos(distRatio);
//    double initialBearingRadians = self.absoluteAngle;
//
//    double startLatRad = startLocation.latitude * M_PI / 180.0;
//    double startLonRad = startLocation.longitude * M_PI / 180.0;
//    double startLatCos = cos(startLatRad);
//    double startLatSin = sin(startLatRad);
//
//    double endLatRads = asin((startLatSin * distRatioCosine) + (startLatCos * distRatioSine * cos(initialBearingRadians)));
//    double endLonRads = startLonRad
//    + atan2(sin(initialBearingRadians) * distRatioSine * startLatCos,
//            distRatioCosine - startLatSin * sin(endLatRads));
//    CLLocationCoordinate2D location;
//    location.latitude = endLatRads * 180.0 / M_PI;
//    location.longitude = endLonRads * 180.0 / M_PI;
//    return location;
//}


#pragma mark - Private Methods

- (AGSSpatialReference *) srWithMeters
{
    if (!_srWithMeters) {
        //ESRI web mercator has units of meters
        _srWithMeters = [AGSSpatialReference webMercatorSpatialReference];
    }
    return _srWithMeters;
}

- (NSNumber *) numberFromAbsoluteAngle:(double)angle
{
    if (angle < 0)
        return nil;

    double referenceAngle = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleBaseline : kAngleDistanceDeadAhead;
    AngleDirection angleDirection = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleDirection : kAngleDistanceAngleDirection;
    double direction = angleDirection == AngleDirectionClockwise ? 1.0 : -1.0;
    double localAngle = referenceAngle + direction * (angle - self.deadAhead);
    if (localAngle < referenceAngle - 180.0)
        return @(localAngle + 360.0);
    if (referenceAngle + 180.0 < localAngle)
        return @(localAngle - 360.0);
    return @(localAngle);
}

- (NSNumber *) numberFromDistanceMeters:(double)distance
{
    if (distance <= 0)
        return nil;

    AGSSRUnit distanceUnits = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.distanceUnits : kAngleDistanceDistanceUnits;
    double localDistance = [self.srWithMeters convertValue:distance toUnit:distanceUnits];
    return @(localDistance);
}

- (double) doubleFromAngle:(NSNumber*)angle
{
    if (angle == nil)
        return -1.0;

    double referenceAngle = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleBaseline : kAngleDistanceDeadAhead;
    AngleDirection angleDirection = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleDirection : kAngleDistanceAngleDirection;
    double direction = angleDirection == AngleDirectionClockwise ? 1.0 : -1.0;
    double absoluteAngle = self.deadAhead + direction * (angle.doubleValue - referenceAngle);
    if (absoluteAngle < 0)
        absoluteAngle = fmod(absoluteAngle, 360.0) + 360.0;
    if (360.0 < absoluteAngle)
        absoluteAngle = fmod(absoluteAngle, 360.0);
    return absoluteAngle;
}

- (double) doubleFromDistance:(NSNumber *)distance
{
    if (distance == nil || distance.doubleValue <= 0)
        return -1.0;
    
    AGSSRUnit distanceUnits = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.distanceUnits : kAngleDistanceDistanceUnits;
    //Despite working in the debugger, the following fails with EXC_BAD_ACCESS in production.
    //return [self.srWithMeters convertValue:[distance doubleValue] fromUnit:distanceUnits];
    //My simple workaround
    double factor = [self.srWithMeters convertValue:1.0 toUnit:distanceUnits];
    return distance.doubleValue/factor;
}

@end
