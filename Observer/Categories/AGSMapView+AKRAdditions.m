//
//  AGSMapView+AKRAdditions.m
//  Observer
//
//  Created by Regan Sarwas on 2/27/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "AGSMapView+AKRAdditions.h"

@implementation AGSMapView (AKRAdditions)

- (BOOL)isProjected
{
    return self.map.loadStatus == AGSLoadStatusLoaded && self.spatialReference.isProjected;
}

- (BOOL)isAutoRotating
{
    return self.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeCompassNavigation ||
    self.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeNavigation;
}

- (AGSPoint *)mapAnchor
{
    AGSViewpoint *viewpoint = [self currentViewpointWithType:AGSViewpointTypeCenterAndScale];
    return (AGSPoint *)viewpoint.targetGeometry;
}

@end
