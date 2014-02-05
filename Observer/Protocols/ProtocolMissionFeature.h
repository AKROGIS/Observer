//
//  ProtocolMissionFeature.h
//  Observer
//
//  Created by Regan Sarwas on 2/4/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "ProtocolFeature.h"

@interface ProtocolMissionFeature : ProtocolFeature

- (id)initWithJSON:(id)json;

// How should these features be drawn on the map
@property (strong, nonatomic, readonly) ProtocolFeatureSymbology *observingymbology;
@property (strong, nonatomic, readonly) ProtocolFeatureSymbology *notObservingymbology;

@end
