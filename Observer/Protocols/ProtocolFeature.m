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
            [self defineReadonlyProperties:json];
        }
    }
    return self;
}

// lazy loading doesn't work well when some of the properties may have a valid zero value
// so I just load it all up once when initialized
- (void)defineReadonlyProperties:(NSDictionary *)json
{
    _allowedLocations = [[ProtocolFeatureAllowedLocations alloc] initWithLocationsJSON:json[@"locations"]];
    _symbology = [[ProtocolFeatureSymbology alloc] initWithSymbologyJSON:json[@"symbology"]];
    _attributes = [self buildAttributeArrayWithJSON:json[@"attributes"]];
    id dialog = json[@"dialog"];
    if ([dialog isKindOfClass:[NSDictionary class]]) {
        _dialogJSON = (NSDictionary *)dialog;
    }
}

- (NSArray *)buildAttributeArrayWithJSON:(id)json
{
    if ([json isKindOfClass:[NSArray class]]) {
        //FIXME: implement
        return nil;
    }
    return nil;
}

@end
