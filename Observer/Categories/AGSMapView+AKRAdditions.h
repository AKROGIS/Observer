//
//  AGSMapView+AKRAdditions.h
//  Observer
//
//  Created by Regan Sarwas on 2/27/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>

@interface AGSMapView (AKRAdditions)

- (void)zoomOutUntilVisible:(AGSPoint *)point animated:(BOOL)animated;

@end
