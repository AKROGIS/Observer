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

@implementation LocationAngleDistance


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

//FIXME - write custom setter and getter for angle and distance to only return valid values

/*
- (void) setDefaultAngle:(NSNumber *)defaultAngle
{
    if (defaultAngle) {
        self.angleTextField.text = [NSString stringWithFormat:@"%@", defaultAngle];
    }
}

- (void) setDefaultDistance:(NSNumber *)defaultDistance
{
    if (defaultDistance) {
        double distance = [defaultDistance doubleValue];
        if (distance > 0)
            self.distanceTextField.text = [NSString stringWithFormat:@"%f", distance];
    }
}

- (NSNumber *) angle
{
    NSNumber *number = [self.parser numberFromString:self.angleTextField.text];
    return number;
}

- (NSNumber *) distance
{
    NSNumber *number = [self.parser numberFromString:self.distanceTextField.text];
    if ([number doubleValue] <= 0)
        return nil;
    return number;
}
*/

- (BOOL) usesProtocol
{
    return self.protocol && self.protocol.definesAngleDistanceMeasures;
}

- (BOOL) isValid
{
    return self.gpsPoint && self.deadAhead;
}

- (BOOL) isComplete
{
    return self.distance && self.angle;
}

- (AGSPoint *)observationPoint
{
    if (!self.isValid || !self.isComplete)
        return nil;
    
    double referenceAngle = self.usesProtocol ? self.protocol.angleBaseline : [Settings manager].angleDistanceDeadAhead;
    AGSSRUnit distanceUnits = self.usesProtocol ? self.protocol.distanceUnits : [Settings manager].distanceUnitsForSightings;
    AngleDirection angleDirection = self.usesProtocol ? self.protocol.angleDirection : [Settings manager].angleDistanceAngleDirection;
    
    double course = [self.deadAhead doubleValue];
    double direction = angleDirection == AngleDirectionClockwise ? 1.0 : -1.0;
    double angle  = course + direction * ([self.angle doubleValue]- referenceAngle);
    return [self.gpsPoint pointWithAngle:angle distance:[self.distance doubleValue] units:distanceUnits];
}


@end
