//
//  AutoPanButton.m
//  Observer
//
//  Created by Regan Sarwas on 1/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "AutoPanButton.h"

@implementation AutoPanButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)turnOff
{
    //TODO: replace text with cool images/highlighting
    self.titleLabel.text = @"Off";
    self.imageView.image = nil;
}

- (void)turnOnWithoutRotate
{
    self.titleLabel.text = @"On";
    self.imageView.image = nil;
}

- (void)turnOnWitRotate
{
    self.titleLabel.text = @"OnR";
    self.imageView.image = nil;
}

@end
