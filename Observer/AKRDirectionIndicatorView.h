//
//  AKRDirectionIndicatorView.h
//  Observer
//
//  Created by Regan Sarwas on 12/12/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>

// Draws an arrow in a 20x20 view that is rotated by the angle in azimuth.  if the azimuthUnknown, then nothing is drawn.

@interface AKRDirectionIndicatorView : UIView

//azimuth is an angle in degrees with 0 = north, and + = clockwise
@property (nonatomic) double azimuth;
@property (nonatomic) BOOL azimuthUnknown;

@end
