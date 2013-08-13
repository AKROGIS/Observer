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

@end

@implementation LocationAngleDistance

- (id) init
{
    return [self initWithCourse:0.0];
}

- (id) initWithCourse:(double)course
{
    return [self initWithCourse:course Angle:-1.0 Distance:-1.0];
}

- (id) initWithCourse:(double)course Angle:(double)angle Distance:(double)distance
{
    self = [super init];
    if (self)
    {
        _deadAhead = course;
        _absoluteAngle = angle;
        _defaultAngle = [self numberFromAbsoluteAngle:angle];
        _angle = _defaultAngle;
        _distanceMeters = distance;
        _defaultDistance = [self numberFromDistanceMeters:distance];
        _distance = _defaultDistance;
    }
    return self;
}

#pragma mark - Public Properties

- (NSString *)basisDescription
{
    double referenceAngle = self.usesProtocol ? self.protocol.angleBaseline : [Settings manager].angleDistanceDeadAhead;
    AGSSRUnit distanceUnits = self.usesProtocol ? self.protocol.distanceUnits : [Settings manager].distanceUnitsForSightings;
    AngleDirection angleDirection = self.usesProtocol ? self.protocol.angleDirection : [Settings manager].angleDistanceAngleDirection;
    
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

- (void) setAngle:(NSNumber *)angle
{
    _angle = angle;
    _absoluteAngle = [self doubleFromAngle:angle];
}

- (void) setDistance:(NSNumber *)distance
{
    _distance = distance;
    _distanceMeters = [self doubleFromDistance:distance];
}

- (BOOL) usesProtocol
{
    return self.protocol && self.protocol.definesAngleDistanceMeasures;
}

- (BOOL) isValid
{
    return self.gpsPoint && 0 <= self.deadAhead;
}

- (BOOL) isComplete
{
    return (0 < self.distanceMeters)  && (0 <= self.absoluteAngle);
}

- (AGSPoint *)observationPoint
{
    if (!self.isValid || !self.isComplete)
        return nil;
    
    return [self.gpsPoint pointWithAngle:self.absoluteAngle distance:self.distanceMeters units:AGSSRUnitMeter];
}


#pragma mark - Private Methods

- (NSNumber *) numberFromAbsoluteAngle:(double)angle
{
    if (angle < 0)
        return nil;

    double referenceAngle = self.usesProtocol ? self.protocol.angleBaseline : [Settings manager].angleDistanceDeadAhead;
    AngleDirection angleDirection = self.usesProtocol ? self.protocol.angleDirection : [Settings manager].angleDistanceAngleDirection;
    double direction = angleDirection == AngleDirectionClockwise ? 1.0 : -1.0;
    double localAngle = referenceAngle + direction * (angle - self.deadAhead);
    return [NSNumber numberWithDouble:localAngle];
}

- (NSNumber *) numberFromDistanceMeters:(double)distance
{
    if (distance <= 0)
        return nil;

    AGSSRUnit distanceUnits = self.usesProtocol ? self.protocol.distanceUnits : [Settings manager].distanceUnitsForSightings;
    //ESRI web mercator has units of meters
    double localDistance = [[AGSSpatialReference webMercatorSpatialReference] convertValue:distance toUnit:distanceUnits];
    return [NSNumber numberWithDouble:localDistance];
}

- (double) doubleFromAngle:(NSNumber*)angle
{
    if (!angle || [angle doubleValue] < 0)
        return -1.0;

    double referenceAngle = self.usesProtocol ? self.protocol.angleBaseline : [Settings manager].angleDistanceDeadAhead;
    AngleDirection angleDirection = self.usesProtocol ? self.protocol.angleDirection : [Settings manager].angleDistanceAngleDirection;
    double direction = angleDirection == AngleDirectionClockwise ? 1.0 : -1.0;
    return self.deadAhead + direction * ([angle doubleValue]- referenceAngle);
}

- (double) doubleFromDistance:(NSNumber *)distance
{
    if (!distance || [distance doubleValue] <= 0)
        return -1.0;
    
    AGSSRUnit distanceUnits = self.usesProtocol ? self.protocol.distanceUnits : [Settings manager].distanceUnitsForSightings;
    if (distanceUnits == AGSSRUnitMeter)
        return [distance doubleValue];
    //ESRI web mercator has units of meters
    return [[AGSSpatialReference webMercatorSpatialReference] convertValue:[distance doubleValue] fromUnit:distanceUnits];
}

@end
