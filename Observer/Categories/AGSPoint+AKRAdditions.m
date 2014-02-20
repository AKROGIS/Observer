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
    //FIXME: if point is geographic temporatily project it to do angle distance, then project back
    
    //distance will be nan if units and spatialreference.units are not similar (i.e. both linear, or both angular)
    //that is, you cannot use meters with geographic points, or degrees with projected points.
    distance = [self.spatialReference convertValue:distance fromUnit:units];
    //angle is clockwise from North, convert to math angle: counterclockwise from East = 0
    angle = 90.0 - angle;
    angle = angle * M_PI / 180.0; //make it radians
    double deltaX = isnan(distance) ? 0 : distance * cos(angle);
    double deltaY = isnan(distance) ? 0 : distance * sin(angle);
    return [AGSPoint pointWithX:self.x + deltaX y:self.y + deltaY spatialReference:self.spatialReference];
}

@end
