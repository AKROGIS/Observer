//
//  AutoPanButton.h
//  Observer
//
//  Created by Regan Sarwas on 1/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AutoPanButton : UIBarButtonItem

- (void)turnOff;
- (void)turnOnWithoutRotate;
- (void)turnOnWithRotate;

@end
