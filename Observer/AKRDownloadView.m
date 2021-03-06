//
//  AKRDownloadView.m
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 Regan Sarwas. All rights reserved.
//

#import "AKRDownloadView.h"

@implementation AKRDownloadView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        _percentComplete = 0.0;
    }
    return self;
}

- (void)setPercentComplete:(double)percentComplete
{
    if (fabs(percentComplete - _percentComplete) < 0.02)
        return;
    if (percentComplete < 0.0) {
        _percentComplete = 0.0;
    } else if (1.0 < percentComplete) {
        _percentComplete = 1.0;
    } else {
        _percentComplete = percentComplete;
    }
    [self setNeedsDisplay];
}

- (void)setDownloading:(BOOL)downloading
{
    if (downloading != _downloading) {
        _downloading = downloading;
        self.percentComplete = 0.0;
        [self setNeedsDisplay];
    }
}

-(void)drawRect:(CGRect)rect
{
    if (self.downloading) {
        CGContextRef context = UIGraphicsGetCurrentContext();

        //Set color
        [self.tintColor set];
 
        CGFloat width = self.bounds.size.width;
        CGFloat height = self.bounds.size.height;
        CGFloat two = 2.0;
        CGContextTranslateCTM(context, width/two, height/two);

        //Inner Square
        CGContextMoveToPoint(context, -4,-4);
        CGContextAddLineToPoint(context, 4, -4);
        CGContextAddLineToPoint(context, 4, 4);
        CGContextAddLineToPoint(context, -4, 4);
        CGContextClosePath(context);
        CGContextDrawPath(context, kCGPathFill);

        //Small outer circle
        CGContextSetLineWidth(context, 1);
        CGContextBeginPath(context);
        CGContextAddArc(context, 0, 0, 14, 0, (CGFloat)(2*M_PI), YES); //x,y,r,start angle,end,CW
        CGContextClosePath(context);
        CGContextDrawPath(context, kCGPathStroke);

        //Small outer circle
        CGContextSetLineWidth(context, 3);
        CGContextBeginPath(context);
        CGContextAddArc(context, 0, 0, 12, (CGFloat)-M_PI_2, (CGFloat)(-M_PI_2 + (2*M_PI)*self.percentComplete), NO); //x,y,r,start angle,end,CW
        CGContextDrawPath(context, kCGPathStroke);
    }
}

@end
