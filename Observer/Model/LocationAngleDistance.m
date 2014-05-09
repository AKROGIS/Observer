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

@interface LocationAngleDistance ()

@property (nonatomic,strong) AGSSpatialReference *srWithMeters;

@end

@implementation LocationAngleDistance

- (id) init
{
    return [self initWithDeadAhead:0.0 protocolFeature:nil absoluteAngle:-1.0 distance:-1.0];
}

- (id) initWithDeadAhead:(double)deadAhead protocolFeature:(ProtocolFeature *)feature
{
    return [self initWithDeadAhead:deadAhead protocolFeature:feature absoluteAngle:-1.0 distance:-1.0];
}

- (id) initWithDeadAhead:(double)deadAhead protocolFeature:(ProtocolFeature *)feature absoluteAngle:(double)angle distance:(double)distance
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
    double referenceAngle = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleBaseline : [Settings manager].angleDistanceDeadAhead;
    AGSSRUnit distanceUnits = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.distanceUnits : [Settings manager].distanceUnitsForSightings;
    AngleDirection angleDirection = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleDirection : [Settings manager].angleDistanceAngleDirection;
    
    NSString *description =
    [NSString stringWithFormat:@"Angle increases %@ with dead ahead equal to %u degrees. Distance is in %@.",
     angleDirection == 0 ? @"clockwise" : @"counter-clockwise",
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

- (BOOL) usesProtocol
{
    return self.feature.allowedLocations.definesAngleDistance;
}

- (BOOL) isValid
{
    return 0 <= self.deadAhead;
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

- (CLLocationCoordinate2D)locationFromLocation:(CLLocationCoordinate2D)startLocation
{
    // From http://www.movable-type.co.uk/scripts/latlong.html
    const double radiusEarthMeters = 6371010.0;
    double distRatio = self.distanceMeters / radiusEarthMeters;
    double distRatioSine = sin(distRatio);
    double distRatioCosine = cos(distRatio);
    double initialBearingRadians = self.absoluteAngle;

    double startLatRad = startLocation.latitude * M_PI / 180.0;
    double startLonRad = startLocation.longitude * M_PI / 180.0;
    double startLatCos = cos(startLatRad);
    double startLatSin = sin(startLatRad);

    double endLatRads = asin((startLatSin * distRatioCosine) + (startLatCos * distRatioSine * cos(initialBearingRadians)));
    double endLonRads = startLonRad
                        + atan2(sin(initialBearingRadians) * distRatioSine * startLatCos,
                                distRatioCosine - startLatSin * sin(endLatRads));
    CLLocationCoordinate2D location;
    location.latitude = endLatRads * 180.0 / M_PI;
    location.longitude = endLonRads * 180.0 / M_PI;
    return location;
}

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

    double referenceAngle = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleBaseline : [Settings manager].angleDistanceDeadAhead;
    AngleDirection angleDirection = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleDirection : [Settings manager].angleDistanceAngleDirection;
    double direction = angleDirection == AngleDirectionClockwise ? 1.0 : -1.0;
    double localAngle = referenceAngle + direction * (angle - self.deadAhead);
    return [NSNumber numberWithDouble:localAngle];
}

- (NSNumber *) numberFromDistanceMeters:(double)distance
{
    if (distance <= 0)
        return nil;

    AGSSRUnit distanceUnits = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.distanceUnits : [Settings manager].distanceUnitsForSightings;
    double localDistance = [self.srWithMeters convertValue:distance toUnit:distanceUnits];
    return [NSNumber numberWithDouble:localDistance];
}

- (double) doubleFromAngle:(NSNumber*)angle
{
    if (!angle)
        return -1.0;

    double referenceAngle = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleBaseline : [Settings manager].angleDistanceDeadAhead;
    AngleDirection angleDirection = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.angleDirection : [Settings manager].angleDistanceAngleDirection;
    double direction = angleDirection == AngleDirectionClockwise ? 1.0 : -1.0;
    double absoluteAngle = self.deadAhead + direction * ([angle doubleValue] - referenceAngle);
    if (absoluteAngle < 0)
        absoluteAngle = fmod(absoluteAngle, 360.0) + 360.0;
    if (360.0 < absoluteAngle)
        absoluteAngle = fmod(absoluteAngle, 360.0);
    return absoluteAngle;
}

- (double) doubleFromDistance:(NSNumber *)distance
{
    if (!distance || [distance doubleValue] <= 0)
        return -1.0;
    
    AGSSRUnit distanceUnits = self.feature.allowedLocations.definesAngleDistance ? self.feature.allowedLocations.distanceUnits : [Settings manager].distanceUnitsForSightings;
    //Despite working in the debugger, the following fails with EXC_BAD_ACCESS in production.
    //return [self.srWithMeters convertValue:[distance doubleValue] fromUnit:distanceUnits];
    //My simple workaround
    double factor = [self.srWithMeters convertValue:1.0 toUnit:distanceUnits];
    return [distance doubleValue]/factor;
}

@end
