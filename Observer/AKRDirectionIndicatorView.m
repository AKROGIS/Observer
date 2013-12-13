//
//  AKRDirectionIndicatorView.m
//  Observer
//
//  Created by Regan Sarwas on 12/12/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AKRDirectionIndicatorView.h"

@implementation AKRDirectionIndicatorView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

float mod(float a, float N)
{
    return a - N*floor(a/N);
} //return in range [0, N)

- (void)setAzimuth:(float)azimuth
{
    if (fabs(azimuth - _azimuth) < 0.02)
        return;
    float oldAzimuth = _azimuth;
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
        //CGContextSetRGBStrokeColor(context, 0.3, 0.3, 0.3, 1.0); //rgba (0..1)

        //Get angle for rotating coordinate system
        //float a = mod(self.azimuth, 360.0); // => [0,360.0)
        float a = -1 * self.azimuth * M_PI / 180.0; //radians
        
        //create a rotated coordinate system with origin in center and +y up
        CGFloat width = self.bounds.size.width;
        CGFloat height = self.bounds.size.height;
        CGContextTranslateCTM(context, width/2.0, height/2.0);
        CGContextScaleCTM(context, 1, -1);
        CGContextRotateCTM(context, a); //angle in radians with + = CCW
        
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
