//
//  ProtocolFeatureAllowedLocations.m
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolFeatureAllowedLocations.h"

@interface ProtocolFeatureAllowedLocations()

@property (strong, nonatomic, readonly) NSDictionary *angleDistance;
@property (strong, nonatomic, readonly) NSDictionary *mapTouch;
@property (strong, nonatomic, readonly) NSDictionary *mapTarget;
@property (strong, nonatomic, readonly) NSDictionary *gpsLocation;

@end

@implementation ProtocolFeatureAllowedLocations

#pragma mark - Class Methods

+ (NSArray *)stringsForLocations:(WaysToLocateFeature)locationMethods
{
    NSMutableArray *strings = [NSMutableArray new];
    if (locationMethods & LocateFeatureWithGPS) {
        [strings addObject:NSLocalizedString(@"At GPS Location", @"Locations are at the current GPS position")];
    }
    if (locationMethods & LocateFeatureWithMapTarget) {
        [strings addObject:NSLocalizedString(@"At Target Location", @"Locations are at the target on the map")];
    }
    if (locationMethods & LocateFeatureWithAngleDistance) {
        [strings addObject:NSLocalizedString(@"Angle & Distance", @"Locations are based on an Angle and Distance from the current location")];
    }
    if (locationMethods & LocateFeatureWithMapTouch) {
        [strings addObject:NSLocalizedString(@"At Touch Location", @"Locations are at the touch on the map")];
    }
    return [strings copy];
}

+ (WaysToLocateFeature)locationMethodForName:(NSString *)name
{
    if ([name isEqualToString:NSLocalizedString(@"At GPS Location", @"Locations are at the current GPS position")]) {
        return LocateFeatureWithGPS;
    }
    if ([name isEqualToString:NSLocalizedString(@"At Target Location", @"Locations are at the target on the map")]) {
        return LocateFeatureWithMapTarget;
    }
    if ([name isEqualToString:NSLocalizedString(@"Angle & Distance", @"Locations are based on an Angle and Distance from the current location")]) {
        return LocateFeatureWithAngleDistance;
    }
    if ([name isEqualToString:NSLocalizedString(@"At Touch Location", @"Locations are at the touch on the map")]) {
        return LocateFeatureWithMapTouch;
    }
    return LocateFeatureUndefined;
}




#pragma mark - Initialization

- (id)initWithLocationsJSON:(id)json version:(NSInteger) version
{
    if (self = [super init]) {
        if ([json isKindOfClass:[NSArray class]]) {
            switch (version) {
                case 1:
                case 2:
                    [self defineReadonlyProperties:(NSArray *)json];
                    break;
                default:
                    AKRLog(@"Unsupported version (%ld) of the NPS-Protocol-Specification", (long)version);
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
    for (id item in json) {
        //gpsLocation
        if ([self dictionary:item hasValues:@[@"gps", @"gpslocation", @"gps-location"] forKey:@"type"]) {
            if (![self dictionary:item hasKey:@"allow" withValue:[NSNumber numberWithBool:NO]]) {
                _gpsLocation = (NSDictionary *)item;
            }
            continue;
        }
        //angleDistanceLocation
        if ([self dictionary:item hasValues:@[@"ad", @"angledistance", @"angle-distance"] forKey:@"type"]) {
            if (![self dictionary:item hasKey:@"allow" withValue:[NSNumber numberWithBool:NO]]) {
                _angleDistance = (NSDictionary *)item;
            }
            continue;
        }
        //mapTouch
        if ([self dictionary:item hasValues:@[@"touch", @"maptouch", @"map-touch", @"adhoctouch", @"adhoc-touch"] forKey:@"type"]) {
            if (![self dictionary:item hasKey:@"allow" withValue:[NSNumber numberWithBool:NO]]) {
                _mapTouch = (NSDictionary *)item;
            }
            continue;
        }
        //mapTarget
        if ([self dictionary:item hasValues:@[@"target", @"maptarget", @"map-target", @"adhoctarget", @"adhoc-target"] forKey:@"type"]) {
            if (![self dictionary:item hasKey:@"allow" withValue:[NSNumber numberWithBool:NO]]) {
                _mapTarget = (NSDictionary *)item;
            }
            continue;
        }
    }
    
    if (_angleDistance) {
        //default Angle/Distance parameters
        _distanceUnits = AGSSRUnitMeter;
        _angleBaseline = 0.0;
        _angleDirection = AngleDirectionClockwise;

        //distanceUnits
        NSString *key = [self keyForDictionary:_angleDistance possibleKeys:@[@"units", @"distanceunits", @"distance-units"]];
        if (key) {
            id value = _angleDistance[key];
            if ([value isKindOfClass:[NSString class]]) {
                NSString *units = (NSString *)value;
                if ([@[@"feet", @"foot"] containsObject:[units lowercaseString]]) {
                    _distanceUnits = AGSSRUnitFoot;
                    _definesAngleDistance = YES;
                }
                if ([@[@"yard", @"yards"] containsObject:[units lowercaseString]]) {
                    _distanceUnits = AGSSRUnitFoot;
                    _definesAngleDistance = YES;
                }
                if ([@[@"meter", @"metre", @"metres", @"meters"] containsObject:[units lowercaseString]]) {
                    _distanceUnits = AGSSRUnitMeter;
                    _definesAngleDistance = YES;
                }
            }
        }
        //angleBaseline
        key = [self keyForDictionary:_angleDistance possibleKeys:@[@"deadAhead", @"baseline", @"anglebaseline", @"angle-baseline", @"baselineangle", @"baseline-angle"]];
        if (key) {
            id value = _angleDistance[key];
            if ([value isKindOfClass:[NSNumber class]]) {
                _definesAngleDistance = YES;
                _angleBaseline = [(NSNumber *)value  doubleValue];
            }
        }
        //angleDirection
        key = [self keyForDictionary:_angleDistance possibleKeys:@[@"direction", @"angledirection", @"angle-direction"]];
        if (key) {
            if ([self dictionary:_angleDistance hasValues:@[@"cw", @"clockwise"] forKey:key]) {
                _definesAngleDistance = YES;
                _angleDirection = AngleDirectionClockwise;
            } else {
                if ([self dictionary:_angleDistance hasValues:@[@"ccw", @"counterclockwise", @"counter-clockwise"] forKey:key]) {
                    _definesAngleDistance = YES;
                    _angleDirection = AngleDirectionCounterClockwise;
                }
            }
        }
    }
}




#pragma mark - Calculated Properties

- (NSUInteger)countOfNonTouchChoices
{
    NSUInteger counter = 0;
    if (_gpsLocation && self.hasGPS) counter++;
    if (_mapTarget && self.hasMap) counter++;
    if (_angleDistance  && self.hasGPS && self.mapIsProjected) counter++;
    return counter;
}

- (NSUInteger)countOfTouchChoices
{
    NSUInteger counter = 0;
    if (_mapTouch && self.hasMap) counter++;
    return counter;
}

- (WaysToLocateFeature)nonTouchChoices
{
    WaysToLocateFeature bitmask = LocateFeatureUndefined;
    if (_gpsLocation && self.hasGPS) bitmask |= LocateFeatureWithGPS;
    if (_mapTarget && self.hasMap) bitmask |= LocateFeatureWithMapTarget;
    if (_angleDistance  && self.hasGPS && self.mapIsProjected) bitmask |= LocateFeatureWithAngleDistance;
    return bitmask;
}

- (WaysToLocateFeature)touchChoices
{
    WaysToLocateFeature bitmask = LocateFeatureUndefined;
    if (_mapTouch && self.hasMap) bitmask |= LocateFeatureWithMapTouch;
    return bitmask;
}

- (WaysToLocateFeature)defaultNonTouchChoice
{
    if (self.hasGPS && [self dictionary:_gpsLocation hasKey:@"default" withValue:[NSNumber numberWithBool:YES]]) {
        return LocateFeatureWithGPS;
    }
    if (self.hasMap && [self dictionary:_mapTarget hasKey:@"default" withValue:[NSNumber numberWithBool:YES]]) {
        return LocateFeatureWithMapTarget;
    }
    if (self.hasGPS && self.mapIsProjected && [self dictionary:_angleDistance hasKey:@"default" withValue:[NSNumber numberWithBool:YES]]) {
        return LocateFeatureWithAngleDistance;
    }
    return LocateFeatureUndefined;
}

- (WaysToLocateFeature)initialNonTouchChoice
{
    if (_gpsLocation && self.hasGPS) {
        return LocateFeatureWithGPS;
    }
    if (_mapTarget && self.hasMap) {
        return LocateFeatureWithMapTarget;
    }
    if (_angleDistance && self.hasGPS && self.mapIsProjected) {
        return LocateFeatureWithAngleDistance;
    }
    return LocateFeatureUndefined;
}

- (BOOL)allowsAngleDistanceLocations
{
    return _angleDistance != nil;
}

- (BOOL)allowsMapLocations
{
    return (_mapTarget != nil) || (_mapTouch != nil);
}

#pragma mark - Helper methods

- (BOOL)hasGPS
{
    //default is YES, if there is no location presenter, or it doesn't implement the optional method
    id<LocationPresenter> locationPresenter = self.locationPresenter;
    BOOL noResponse = !locationPresenter || ![locationPresenter respondsToSelector:@selector(hasGPS)];
    return (noResponse || locationPresenter.hasGPS);
}

- (BOOL)hasMap
{
    //default is YES if there is no location presenter, or it doesn't implement the optional method
    id<LocationPresenter> locationPresenter = self.locationPresenter;
    BOOL noResponse = !locationPresenter || ![locationPresenter respondsToSelector:@selector(hasMap)];
    return (noResponse || locationPresenter.hasMap);
}

- (BOOL)mapIsProjected
{
    //default is YES, if there is no location presenter, or it doesn't implement the optional method
    id<LocationPresenter> locationPresenter = self.locationPresenter;
    BOOL noResponse = !locationPresenter || ![locationPresenter respondsToSelector:@selector(mapIsProjected)];
    return (noResponse || locationPresenter.mapIsProjected);
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

//Returns YES if the possibleDict is a NSDictionary with the key and the key has the given value
- (BOOL) dictionary:(id)possibleDict hasKey:(NSString *)key withValue:(id)value
{
    if ([possibleDict isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)possibleDict;
        return [value isEqual:dict[key]];
    }
    return NO;
}

@end
