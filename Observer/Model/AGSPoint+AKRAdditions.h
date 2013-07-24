//
//  AGSPoint+AKRAdditions.h
//  Observer
//
//  Created by Regan Sarwas on 7/24/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>

@interface AGSPoint (AKRAdditions)

/**  Creates a new immutable point based on the offset from the reciever.
 the SR of the reciever and the units must be compatible (i.e. both linear or both angular)
 an identical point will be returned if the point has no SR, or SR and units do not match.
 @param angle the angle (in clockwise degrees with North = 0) to the new point from the receiver.
 @param distance the distance the new point is located from the reciver
 @param units the units of the distance measurement.
 @return A new autoreleased point geometry object.
 */
-(AGSPoint *)pointWithAngle:(double)angle distance:(double)distance units:(AGSSRUnit)units;

@end
