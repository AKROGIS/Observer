//
//  AngleDistanceSettingsTableViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/29/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SurveyProtocol.h"

@interface AngleDistanceSettingsTableViewController : UITableViewController

//a method to call when this VC is removed from the parent VC
@property (strong, nonatomic) void(^completionBlock)(AngleDistanceSettingsTableViewController *);

//Model - if provided, reads and writes are from/to the model, otherwise from/to NSDefaults
// the properties of the protocol are not observed, if they are changed externally,
// this property should be reset to update the UI.
@property (nonatomic,strong) SurveyProtocol *protocol;

@end
