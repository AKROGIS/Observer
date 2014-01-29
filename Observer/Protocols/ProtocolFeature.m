//
//  ProtocolFeature.m
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolFeature.h"

@implementation ProtocolFeature

- (id)initWithJSON:(id)json
{
    if (self = [super init]) {
        if ([json isKindOfClass:[NSDictionary class]]) {
            _json = [json copy];
        }
    }
    return self;
}

@synthesize allowedLocations = _allowedLocations;

- (ProtocolFeatureAllowedLocations *)allowedLocations
{
    if (!_allowedLocations) {
        _allowedLocations = [[ProtocolFeatureAllowedLocations alloc] initWithLocations:self.json[@"location"]];
    }
    return _allowedLocations;
}


@end
