//
//  ProtocolMissionFeature.m
//  Observer
//
//  Created by Regan Sarwas on 2/4/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolMissionFeature.h"

@implementation ProtocolMissionFeature

- (id)initWithJSON:(id)json
{
    if (self = [super initWithJSON:json]) {
        if ([json isKindOfClass:[NSDictionary class]]) {
            [self defineMissionReadonlyProperties:json];
        }
    }
    return self;
}

// lazy loading doesn't work well when some of the properties may have a valid zero value
// so I just load it all up once when initialized
- (void)defineMissionReadonlyProperties:(NSDictionary *)json
{
    _observingymbology = [[ProtocolFeatureSymbology alloc] initWithSymbologyJSON:json[@"on-symbology"]];
    _notObservingymbology = [[ProtocolFeatureSymbology alloc] initWithSymbologyJSON:json[@"off-symbology"]];
}

@end
