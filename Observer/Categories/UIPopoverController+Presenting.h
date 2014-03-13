//
//  UIPopoverController+Presenting.h
//  Observer
//
//  Created by Regan Sarwas on 3/12/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIPopoverController (Presenting)

- (void)presentPopoverFromMapPoint:(AGSPoint *)mapPoint inMapView:(AGSMapView *)mapView permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated;

@end
