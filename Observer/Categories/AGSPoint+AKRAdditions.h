//
//  AGSPoint+AKRAdditions.h
//  Observer
//
//  Created by Regan Sarwas on 7/24/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <CoreLocation/CoreLocation.h>

@interface AGSPoint (AKRAdditions)

+ (AGSPoint *)pointFromLocation:(CLLocationCoordinate2D)location spatialReference:(AGSSpatialReference*)spatialReference;

@end
