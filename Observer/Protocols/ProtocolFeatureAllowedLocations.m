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

@end

@implementation ProtocolFeatureAllowedLocations

- (id)initWithLocations:(NSArray *)locations
{
    if (self = [super init]) {
        _locations = locations;
        [self loadLocationsProperties];
    }
    return self;
}

//lazy loading properties doesn't work well when the properties may have a valid zero value
- (void)loadLocationsProperties
{
    //gpsLocation
    for (id item in self.locations) {
        if ([self dictionary:item hasValues:@[@"gps", @"gpslocation", @"gps-location"] forKey:@"type"]) {
            _includesGps = YES;
            _gpsLocation = (NSDictionary *)item;
            break;
        }
    }
    
    //angleDistanceLocation
    for (id item in self.locations) {
        if ([self dictionary:item hasValues:@[@"ad", @"angledistance", @"angle-distance"] forKey:@"type"]) {
            _includesAngleDistance = YES;
            _angleDistanceLocation = (NSDictionary *)item;
            break;
        }
    }
    
    //adhocTouch
    for (id item in self.locations) {
        if ([self dictionary:item hasValues:@[@"touch", @"adhoctouch", @"adhoc-touch"] forKey:@"type"]) {
            _includesAdhocTouch = YES;
            _adhocTouch = (NSDictionary *)item;
            break;
        }
    }
    
    //adhocTarget
    for (id item in self.locations) {
        if ([self dictionary:item hasValues:@[@"target", @"adhoctarget", @"adhoc-target"] forKey:@"type"]) {
            _includesAdhocTarget = YES;
            _adhocTarget = (NSDictionary *)item;
            break;
        }
    }
    
    //distanceUnits
    NSString *key = [self keyForDictionary:self.angleDistanceLocation possibleKeys:@[@"units", @"distanceunits", @"distance-units"]];
    if (key) {
        id value = self.angleDistanceLocation[key];
        if ([value isKindOfClass:[NSNumber class]]) {
            _definesDistanceUnits = YES;
            _distanceUnits = [(NSNumber *)value unsignedIntegerValue];
        }
    }
    //angleBaseline
    key = [self keyForDictionary:self.angleDistanceLocation possibleKeys:@[@"baseline", @"anglebaseline", @"angle-baseline", @"baselineangle", @"baseline-angle"]];
    if (key) {
        id value = self.angleDistanceLocation[key];
        if ([value isKindOfClass:[NSNumber class]]) {
            _definesAngleBaseline = YES;
            _angleBaseline = [(NSNumber *)value  doubleValue];
        }
    }
    //angleDirection
    key = [self keyForDictionary:self.angleDistanceLocation possibleKeys:@[@"direction", @"angledirection", @"angle-direction"]];
    if (key) {
        if ([self dictionary:self.angleDistanceLocation hasValues:@[@"cw", @"clockwise"] forKey:key]) {
            _definesAngleDirection = YES;
            _angleDirection = AngleDirectionClockwise;
        } else {
            if ([self dictionary:self.angleDistanceLocation hasValues:@[@"ccw", @"counterclockwise", @"counter-clockwise"] forKey:key]) {
                _definesAngleDirection = YES;
                _angleDirection = AngleDirectionCounterClockwise;
            }
        }
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

@end
