//
//  ProtocolFeatureSymbology.m
//  Observer
//
//  Created by Regan Sarwas on 1/30/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolFeatureSymbology.h"

@implementation ProtocolFeatureSymbology

- (id)initWithSymbologyJSON:(id)json
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
    //FIXME: implement
}


@end
