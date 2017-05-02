//
//  AKRDirectionIndicatorView.m
//  Observer
//
//  Created by Regan Sarwas on 12/12/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AKRDirectionIndicatorView.h"

@implementation AKRDirectionIndicatorView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setAzimuth:(double)azimuth
{
    if (fabs(azimuth - _azimuth) < 0.02)
        return;
    double oldAzimuth = _azimuth;
    _azimuth = azimuth;
    if (2.0 < (fabs(azimuth - oldAzimuth))) {
        [self setNeedsDisplay];
    }
}

- (void)setAzimuthUnknown:(BOOL)azimuthUnknown
{
    if (_azimuthUnknown != azimuthUnknown) {
        _azimuthUnknown = azimuthUnknown;
        [self setNeedsDisplay];
    }
}

-(void)drawRect:(CGRect)rect
{
    if (!self.azimuthUnknown) {
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        //Set color
        [[UIColor darkGrayColor] set];

        //Get angle for rotating coordinate system
        double radians = -1 * self.azimuth * M_PI / 180.0; //radians
        
        //create a rotated coordinate system with origin in center and +y up
        CGFloat width = self.bounds.size.width;
        CGFloat height = self.bounds.size.height;
        CGFloat two = 2.0;
        CGContextTranslateCTM(context, width/two, height/two);
        CGContextScaleCTM(context, 1, -1);
        CGContextRotateCTM(context, (CGFloat)radians); //angle in radians with + = CCW
        
        //Draw arrow straight up in a 20x20 grid
        CGContextSetLineWidth(context, 2);
        CGContextMoveToPoint(context, 0,-8);
        CGContextAddLineToPoint(context, 0, 7);
        CGContextMoveToPoint(context, 4, 3);
        CGContextAddLineToPoint(context, -0.5, 8);
        CGContextMoveToPoint(context, -4, 3);
        CGContextAddLineToPoint(context, 0.5, 8);
        CGContextDrawPath(context, kCGPathStroke);
    }
}

@end
