//
//  ProtocolMissionFeature.h
//  Observer
//
//  Created by Regan Sarwas on 2/4/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <UIKit/UIKit.h>
#import "ProtocolFeature.h"

@interface ProtocolMissionFeature : ProtocolFeature

- (id)initWithJSON:(id)json version:(NSInteger) version;

// How should these mission features be drawn on the map
@property (strong, nonatomic, readonly) AGSRenderer *lineRendererObserving;
@property (strong, nonatomic, readonly) AGSRenderer *lineRendererNotObserving;
//@property (strong, nonatomic, readonly) AGSRenderer *pointRenderer;
@property (strong, nonatomic, readonly) AGSRenderer *pointRendererGps;

@end
