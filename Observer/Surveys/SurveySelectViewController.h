//
//  SurveySelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ProtocolCollection.h"
#import "SurveyCollection.h"
#import "SurveyDetailViewController.h"

@interface SurveySelectViewController : UITableViewController <UIAlertViewDelegate, UITextFieldDelegate>

// The list of items to present in the table view
// TODO: should I make the collection the datasource delegate?
@property (nonatomic, weak) SurveyCollection *items;

// The popover (maybe nil) that this view controller is presented in
@property (nonatomic, weak) UIPopoverController *popover;

// A method to call when the popover is dismissed
@property (copy) void (^popoverDismissedCallback)(void);

@end
