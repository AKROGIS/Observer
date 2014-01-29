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

@end

@implementation ProtocolFeatureAllowedLocations

- (id)initWithLocations:(NSArray *)locations
{
    if (self = [super init]) {
        _locations = locations;
    }
    return self;
}

#pragma mark - fields for angle distance measuring

- (BOOL)definesAngleDistanceMeasures
{
    return self.angleDistanceLocation[@"angle baseline"] != nil;
}

- (BOOL)requireAngleDistance
{
    return [self.angleDistanceLocation[@"requires angle-distance"] boolValue];
}

- (AGSSRUnit)distanceUnits
{
    return [self.angleDistanceLocation[@"distance units"] unsignedIntegerValue];
}

- (double) angleBaseline
{
    return [self.angleDistanceLocation[@"angle baseline"] doubleValue];
}


@synthesize angleDistanceLocation = _angleDistanceLocation;

- (NSDictionary *)angleDistanceLocation
{
    if (!_angleDistanceLocation) {
        _angleDistanceLocation = nil;
        for (id item in self.locations) {
            if ([self dictionary:self.angleDistanceLocation hasValues:@[@"ad", @"angledistance", @"angle-distance"] forKey:@"type"]) {
                _angleDistanceLocation = (NSDictionary *)item;
                break;
            }
        }
    }
    return _angleDistanceLocation;
}

@synthesize angleDirection = _angleDirection;

- (AngleDirection) angleDirection
{
    if (!_angleDirection) {
        _angleDirection = AngleDirectionClockwise; //Default
        if ([self dictionary:self.angleDistanceLocation hasValues:@[@"ccw", @"counterclockwise", @"counter-clockwise"] forKey:@"direction"]) {
            _angleDirection = AngleDirectionCounterClockwise;
        }
    }
    return _angleDirection;
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
