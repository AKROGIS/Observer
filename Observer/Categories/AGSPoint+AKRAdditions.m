//
//  AGSPoint+AKRAdditions.m
//  Observer
//
//  Created by Regan Sarwas on 7/24/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AGSPoint+AKRAdditions.h"

@implementation AGSPoint (AKRAdditions)

+ (AGSPoint *)pointFromLocation:(CLLocationCoordinate2D)location spatialReference:(AGSSpatialReference*)spatialReference
{
    AGSPoint *point = [AGSPoint pointWithCLLocationCoordinate2D:location];
    point = (AGSPoint *)[AGSGeometryEngine projectGeometry:point toSpatialReference:spatialReference];
    return point;
}

@end
