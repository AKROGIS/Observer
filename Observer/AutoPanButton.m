//
//  AutoPanButton.m
//  Observer
//
//  Created by Regan Sarwas on 1/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "AutoPanButton.h"

@implementation AutoPanButton

- (void)turnOff
{
    //TODO: replace text with cool images/highlighting
    self.title = @"Off";
    self.image = nil;
}

- (void)turnOnWithoutRotate
{
    self.title = @"On";
    self.image = nil;
}

- (void)turnOnWitRotate
{
    self.title = @"OnR";
    self.image = nil;
}

@end
