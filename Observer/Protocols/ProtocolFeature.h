//
//  ProtocolFeature.h
//  Observer
//
//  Created by Regan Sarwas on 1/29/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ProtocolFeatureAllowedLocations.h"

@interface ProtocolFeature : NSObject

//locations is not copied, because it (and its contents are immuttable
- (id)initWithJSON:(id)json;
- (id) init __attribute__((unavailable("Must use initWithJSON: instead.")));

@property (strong, nonatomic, readonly) NSDictionary *json;

// What kind of locations are allowed by this feature
@property (strong, nonatomic, readonly) ProtocolFeatureAllowedLocations *allowedLocations;

@end
