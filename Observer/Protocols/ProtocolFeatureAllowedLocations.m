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
@property (strong, nonatomic, readonly) NSDictionary *adhocTouch;
@property (strong, nonatomic, readonly) NSDictionary *adhocTarget;
@property (strong, nonatomic, readonly) NSDictionary *gpsLocation;
@property (strong, nonatomic, readonly) NSDictionary *defaultLocation;

@end

@implementation ProtocolFeatureAllowedLocations

- (id)initWithLocationsJSON:(id)json
{
    if (self = [super init]) {
        if ([json isKindOfClass:[NSArray class]]) {
            [self defineReadonlyProperties:(NSArray *)json];
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
        if ([self dictionary:item hasValues:@[@"gps", @"gpslocation", @"gps-location"] forKey:@"type"]) {
            _includesGps = YES;
            _gpsLocation = (NSDictionary *)item;
            break;
        }
    }
    
    //angleDistanceLocation
    for (id item in json) {
        if ([self dictionary:item hasValues:@[@"ad", @"angledistance", @"angle-distance"] forKey:@"type"]) {
            _includesAngleDistance = YES;
            _angleDistanceLocation = (NSDictionary *)item;
            break;
        }
    }
    
    //adhocTouch
    for (id item in json) {
        if ([self dictionary:item hasValues:@[@"touch", @"adhoctouch", @"adhoc-touch"] forKey:@"type"]) {
            _includesAdhocTouch = YES;
            _adhocTouch = (NSDictionary *)item;
            break;
        }
    }
    
    //adhocTarget
    for (id item in json) {
        if ([self dictionary:item hasValues:@[@"target", @"adhoctarget", @"adhoc-target"] forKey:@"type"]) {
            _includesAdhocTarget = YES;
            _adhocTarget = (NSDictionary *)item;
            break;
        }
    }
    
    //distanceUnits
    NSString *key = [self keyForDictionary:_angleDistanceLocation possibleKeys:@[@"units", @"distanceunits", @"distance-units"]];
    if (key) {
        id value = _angleDistanceLocation[key];
        if ([value isKindOfClass:[NSNumber class]]) {
            _definesDistanceUnits = YES;
            _distanceUnits = [(NSNumber *)value unsignedIntegerValue];
        }
    }
    //angleBaseline
    key = [self keyForDictionary:_angleDistanceLocation possibleKeys:@[@"baseline", @"anglebaseline", @"angle-baseline", @"baselineangle", @"baseline-angle"]];
    if (key) {
        id value = _angleDistanceLocation[key];
        if ([value isKindOfClass:[NSNumber class]]) {
            _definesAngleBaseline = YES;
            _angleBaseline = [(NSNumber *)value  doubleValue];
        }
    }
    //angleDirection
    key = [self keyForDictionary:_angleDistanceLocation possibleKeys:@[@"direction", @"angledirection", @"angle-direction"]];
    if (key) {
        if ([self dictionary:_angleDistanceLocation hasValues:@[@"cw", @"clockwise"] forKey:key]) {
            _definesAngleDirection = YES;
            _angleDirection = AngleDirectionClockwise;
        } else {
            if ([self dictionary:_angleDistanceLocation hasValues:@[@"ccw", @"counterclockwise", @"counter-clockwise"] forKey:key]) {
                _definesAngleDirection = YES;
                _angleDirection = AngleDirectionCounterClockwise;
            }
        }
    }
    
    //multipleChoices
    int counter = 0;
    if (_includesGps) counter++;
    if (_includesAngleDistance) counter++;
    if (_includesAdhocTouch) counter++;
    if (_includesAdhocTarget) counter++;
    _multipleChoices =  (counter > 1);
    //TODO: define behavior for no choices
    
    //hasDefault
    //TODO: define behavior for multiple defaults
    for (NSDictionary *dict in @[_gpsLocation, _angleDistanceLocation, _adhocTouch, _adhocTarget]) {
        id value = dict[@"default"];
        if ([value isKindOfClass:[NSNumber class]]) {
            if ([(NSNumber *)value boolValue]) {
                _defaultLocation = dict;
                break;
            }
        }
    }
    _hasDefault = _defaultLocation != nil;
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

@end
