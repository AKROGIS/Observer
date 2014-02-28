//
//  AGSMapView+AKRAdditions.m
//  Observer
//
//  Created by Regan Sarwas on 2/27/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "AGSMapView+AKRAdditions.h"

@implementation AGSMapView (AKRAdditions)

- (void)zoomOutUntilVisible:(AGSPoint *)point animated:(BOOL)animated
{
    if (!self.visibleArea.spatialReference || !point.spatialReference) {
        return;
    }
    if (![self.spatialReference isEqualToSpatialReference:point.spatialReference]) {
        return;
    }
    if ([self.visibleArea containsPoint:point]) {
        return;
    }
    AGSGeometryEngine *ge = [AGSGeometryEngine defaultGeometryEngine];
    AGSGeometry *buffer = [ge bufferGeometry:point byDistance:0.1]; //TODO: pick a better buffer (needs to work with geographic)
    AGSGeometry *newExtent = [ge unionGeometries:@[self.visibleArea, buffer]];
    [self zoomToGeometry:newExtent withPadding:40 animated:animated];
    [self centerAtPoint:point animated:animated];
}

@end
