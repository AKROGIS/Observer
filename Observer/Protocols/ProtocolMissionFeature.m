//
//  ProtocolMissionFeature.m
//  Observer
//
//  Created by Regan Sarwas on 2/4/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolMissionFeature.h"

@implementation ProtocolMissionFeature

- (id)initWithJSON:(id)json version:(NSInteger) version
{
    if (self = [super initWithJSON:json version:version]) {
        if ([json isKindOfClass:[NSDictionary class]]) {
            switch (version) {
                case 1:
                    [self defineMissionReadonlyProperties:json version:version];
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
- (void)defineMissionReadonlyProperties:(NSDictionary *)json version:(NSInteger)version
{
    _observingymbology = [[ProtocolFeatureSymbology alloc] initWithSymbologyJSON:json[@"on-symbology"] version:version];
    _notObservingymbology = [[ProtocolFeatureSymbology alloc] initWithSymbologyJSON:json[@"off-symbology"] version:version];
}

@end
