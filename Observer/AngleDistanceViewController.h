//
//  AngleDistanceViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocationAngleDistance.h"

@interface AngleDistanceViewController : UIViewController <UITextFieldDelegate>

//Model - Required.
// The properties of the model are not observed, if they are changed externally
// while this VC is visible, this property should be reset to update the UI.
@property (nonatomic, strong) LocationAngleDistance *location;


//if this VC is in a popover, it will resize and dismiss the popover when appropriate
@property (weak, nonatomic) UIPopoverController *popover;
//a method to call when the VC is done.  Not called if the user cancels or quits the VC
@property (strong, nonatomic) void(^completionBlock)(AngleDistanceViewController *);
//a method to call when the VC is cancelled.  Not called if the user cancels or quits the VC
@property (strong, nonatomic) void(^cancellationBlock)(AngleDistanceViewController *);

@end
