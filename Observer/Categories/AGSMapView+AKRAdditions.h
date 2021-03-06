//
//  AGSMapView+AKRAdditions.h
//  Observer
//
//  Created by Regan Sarwas on 2/27/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>

@interface AGSMapView (AKRAdditions)

- (CGPoint)nearestScreenPoint :(AGSPoint *)point;

- (void)clearGraphicsLayers;

@property (nonatomic, getter=isProjected, readonly) BOOL projected;

@property (nonatomic, getter=isAutoRotating, readonly) BOOL autoRotating;

@end
