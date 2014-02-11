//
//  SurveySelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SurveyCollection.h"
#import "SurveyDetailViewController.h"

@interface SurveySelectViewController : UITableViewController <UIAlertViewDelegate, UITextFieldDelegate>

// The list of items to present in the table view
// TODO: should I make the collection the datasource delegate?
@property (nonatomic, strong) SurveyCollection *items;

// The popover (maybe nil) that this view controller is presented in
@property (nonatomic, strong) UIPopoverController *popover;

// A method to call when the selected survey changes
@property (nonatomic, copy) void (^selectedSurveyChanged)(Survey *oldSurvey, Survey *newSurvey);

// A method to call when the name of the selected survey changes
@property (nonatomic, copy) void (^selectedSurveyChangedName)(void);

// A method to call when the popover will programatically dismiss itself
// (programatically dismissal does not call the UIPopoverContoller Delegate dismissed method)
@property (nonatomic, copy) void (^popoverDismissed)(void);

// Create a new survey and add it to the tableview.
// presents an alert view if the survey cannot be created
- (void) newSurveyWithProtocol:(SProtocol *)protocol;

@end
