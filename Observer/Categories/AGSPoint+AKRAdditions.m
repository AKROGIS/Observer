//
//  AGSPoint+AKRAdditions.m
//  Observer
//
//  Created by Regan Sarwas on 7/24/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AGSPoint+AKRAdditions.h"

@implementation AGSPoint (AKRAdditions)

-(AGSPoint *)pointWithAngle:(double)angle distance:(double)distance units:(AGSSRUnit)units
{
    if (!self.spatialReference.isSupported) {
        return nil;
    }
    if (9100 < units && units < 9200) {
        //These are the angular units, which we do not support
        return nil;
    }

    AGSPoint *point;
    if (self.spatialReference.inLinearUnits) {
        point = self;
    } else {
        AGSSpatialReference *webMercator = [[AGSSpatialReference alloc] initWithWKID:3857]; //Web Mercator
        point =  (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:self toSpatialReference:webMercator];
    }

    double myDistance = [point.spatialReference convertValue:distance fromUnit:units];
    //angle is clockwise from North, convert to math angle: counterclockwise from East = 0
    angle = 90.0 - angle;
    angle = angle * M_PI / 180.0; //make it radians
    double deltaX = isnan(myDistance) ? 0 : myDistance * cos(angle);
    double deltaY = isnan(myDistance) ? 0 : myDistance * sin(angle);
    AGSPoint *newPoint = [AGSPoint pointWithX:point.x + deltaX y:point.y + deltaY spatialReference:point.spatialReference];

    if (self.spatialReference.inLinearUnits) {
        return newPoint;
    } else {
        return (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:newPoint toSpatialReference:self.spatialReference];
    }
}

@end
