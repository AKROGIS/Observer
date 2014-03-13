//
//  UIPopoverController+Presenting.m
//  Observer
//
//  Created by Regan Sarwas on 3/12/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "UIPopoverController+Presenting.h"
#import "AGSMapView+AKRAdditions.h"

@implementation UIPopoverController (Presenting)

- (void)presentPopoverFromMapPoint:(AGSPoint *)mapPoint inMapView:(AGSMapView *)mapView permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated
{
    CGPoint screenPoint = [mapView nearestScreenPoint:mapPoint];
    CGRect rect = CGRectMake(screenPoint.x, screenPoint.y, 1, 1);
    [self presentPopoverFromRect:rect inView:mapView permittedArrowDirections:arrowDirections animated:animated];
}


@end
