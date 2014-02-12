//
//  ProtocolFeatureAllowedLocations.m
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolFeatureAllowedLocations.h"

@interface ProtocolFeatureAllowedLocations()

@property (strong, nonatomic, readonly) NSDictionary *angleDistanceLocation;
@property (strong, nonatomic, readonly) NSDictionary *mapTouch;
@property (strong, nonatomic, readonly) NSDictionary *mapTarget;
@property (strong, nonatomic, readonly) NSDictionary *gpsLocation;
//@property (strong, nonatomic, readonly) NSDictionary *defaultLocation;
@property (nonatomic, readonly) BOOL includesGps;
@property (nonatomic, readonly) BOOL includesAngleDistance;
@property (nonatomic, readonly) BOOL includesmapTouch;
@property (nonatomic, readonly) BOOL includesmapTarget;

@end

@implementation ProtocolFeatureAllowedLocations

- (id)initWithLocationsJSON:(id)json version:(NSInteger) version
{
    if (self = [super init]) {
        if ([json isKindOfClass:[NSArray class]]) {
            switch (version) {
                case 1:
                    [self defineReadonlyProperties:(NSArray *)json];
                    break;
                default:
                    AKRLog(@"Unsupported version (%d) of the NPS-Protocol-Specification", version);
                    break;
            }
        }
    }
    return self;
}

// lazy loading doesn't work well when some of the properties may have a valid zero value
// so I just load it all up once when initialized
- (void)defineReadonlyProperties:(NSArray *)json
{
    //gpsLocation
    for (id item in json) {
        if ([self dictionary:item hasValues:@[@"gps", @"gpslocation", @"gps-location"] forKey:@"type"] &&
            [self dictionary:item is:@"allow"]) {
            _includesGps = YES;
            _gpsLocation = (NSDictionary *)item;
            break;
        }
    }
    
    //angleDistanceLocation
    for (id item in json) {
        if ([self dictionary:item hasValues:@[@"ad", @"angledistance", @"angle-distance"] forKey:@"type"] &&
            [self dictionary:item is:@"allow"]) {
            _includesAngleDistance = YES;
            _angleDistanceLocation = (NSDictionary *)item;
            break;
        }
    }
    
    //mapTouch
    for (id item in json) {
        if ([self dictionary:item hasValues:@[@"touch", @"maptouch", @"map-touch", @"adhoctouch", @"adhoc-touch"] forKey:@"type"] &&
            [self dictionary:item is:@"allow"]) {
            _includesmapTouch = YES;
            _mapTouch = (NSDictionary *)item;
            break;
        }
    }
    
    //mapTarget
    for (id item in json) {
        if ([self dictionary:item hasValues:@[@"target", @"maptarget", @"map-target", @"adhoctarget", @"adhoc-target"] forKey:@"type"] &&
            [self dictionary:item is:@"allow"]) {
            _includesmapTarget = YES;
            _mapTarget = (NSDictionary *)item;
            break;
        }
    }

    //default Angle/Distance parameters
    _distanceUnits = AGSSRUnitMeter;
    _angleBaseline = 0.0;
    _angleDirection = AngleDirectionClockwise;

    //distanceUnits
    NSString *key = [self keyForDictionary:_angleDistanceLocation possibleKeys:@[@"units", @"distanceunits", @"distance-units"]];
    if (key) {
        id value = _angleDistanceLocation[key];
        if ([value isKindOfClass:[NSString class]]) {
            NSString *units = (NSString *)value;
            if ([@[@"feet", @"foot"] containsObject:[units lowercaseString]]) {
                _distanceUnits = AGSSRUnitFoot;
            }
            if ([@[@"yard", @"yards"] containsObject:[units lowercaseString]]) {
                _distanceUnits = AGSSRUnitFoot;
            }
            if ([@[@"meter", @"metre", @"metres", @"meters"] containsObject:[units lowercaseString]]) {
                _distanceUnits = AGSSRUnitMeter;
            }
        }
    }
    //angleBaseline
    key = [self keyForDictionary:_angleDistanceLocation possibleKeys:@[@"deadAhead", @"baseline", @"anglebaseline", @"angle-baseline", @"baselineangle", @"baseline-angle"]];
    if (key) {
        id value = _angleDistanceLocation[key];
        if ([value isKindOfClass:[NSNumber class]]) {
            _definesAngleDistance = YES;
            _angleBaseline = [(NSNumber *)value  doubleValue];
        }
    }
    //angleDirection
    key = [self keyForDictionary:_angleDistanceLocation possibleKeys:@[@"direction", @"angledirection", @"angle-direction"]];
    if (key) {
        if ([self dictionary:_angleDistanceLocation hasValues:@[@"cw", @"clockwise"] forKey:key]) {
            _definesAngleDistance = YES;
            _angleDirection = AngleDirectionClockwise;
        } else {
            if ([self dictionary:_angleDistanceLocation hasValues:@[@"ccw", @"counterclockwise", @"counter-clockwise"] forKey:key]) {
                _definesAngleDistance = YES;
                _angleDirection = AngleDirectionCounterClockwise;
            }
        }
    }
    
    //Count of choices
    NSUInteger counter = 0;
    if (_includesGps) counter++;
    if (_includesAngleDistance) counter++;
    if (_includesmapTarget) counter++;
    _countOfNonTouchChoices =  counter;

    counter = 0;
    if (_includesmapTouch) counter++;
    _countOfTouchChoices =  counter;

    //Default Non-Touch Choice
    if ([self dictionary:_angleDistanceLocation is:@"default"]) {
        _defaultNonTouchChoice = LocateFeatureWithAngleDistance;
    }
    if ([self dictionary:_mapTarget is:@"default"]) {
        _defaultNonTouchChoice = LocateFeatureWithMapTarget;
    }
    if ([self dictionary:_gpsLocation is:@"default"]) {
        _defaultNonTouchChoice = LocateFeatureWithGPS;
    }

    //Initial Non-Touch Choice
    if (_includesAngleDistance) {
        _initialNonTouchChoice = LocateFeatureWithAngleDistance;
    }
    if (_includesmapTarget) {
        _initialNonTouchChoice = LocateFeatureWithMapTarget;
    }
    if (_includesGps) {
        _initialNonTouchChoice = LocateFeatureWithGPS;
    }
}


//return the key if dict is a dictionary and it has key in list of keys
- (NSString *) keyForDictionary:(id)possibleDict possibleKeys:(NSArray *)keys
{
    if ([possibleDict isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)possibleDict;
        for (NSString *key in keys) {
            if (dict[key]) {
                return key;
            }
        }
    }
    return nil;
}

//return true if dict is a dictionary where any key in keys has a string value in values
//key is case-sensitive, value is not;
- (BOOL) dictionary:(id)possibleDict hasValues:(NSArray *)values forKey:(NSString *)key
{
    if ([possibleDict isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)possibleDict;
        id item = dict[key];
        if ([item isKindOfClass:[NSString class]]) {
            NSString *text = [(NSString *)item lowercaseString];
            for (NSString *value in values) {
                if ([text isEqualToString:value]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

             - (BOOL) dictionary:(id)possibleDict is:(NSString *)key
             {
                 if ([possibleDict isKindOfClass:[NSDictionary class]]) {
                     NSDictionary *dict = (NSDictionary *)possibleDict;
                     id value = dict[key];
                 if ([value isKindOfClass:[NSNumber class]]) {
                     return [(NSNumber *)value boolValue];
                 }
                 }
                     return NO;
             }

@end
