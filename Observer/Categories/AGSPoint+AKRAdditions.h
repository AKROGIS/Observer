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
 If the point has no or an unsupported SR, then nil will be returned
 If the distance is in angular units, then nil will be returned
 If the point is in a geographic point, then the point is projected to Web Mercator
 to apply the angle/Distance offset, before being converted back.  This will yield an
 approximate solution. No testing has been done to determine the accuracy.
 @param angle the angle (in clockwise degrees with North = 0) to the new point from the receiver.
 @param distance the distance the new point is located from the reciver
 @param units the units of the distance measurement.
 @return A new autoreleased point geometry object.
 */
-(AGSPoint *)pointWithAngle:(double)angle distance:(double)distance units:(AGSSRUnit)units;

@end
