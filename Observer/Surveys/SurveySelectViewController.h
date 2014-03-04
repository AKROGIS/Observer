//
//  SurveySelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SurveyDetailViewController.h"

@interface SurveySelectViewController : UITableViewController <UIAlertViewDelegate, UITextFieldDelegate>

// The popover (maybe nil) that this view controller is presented in
@property (nonatomic, strong) UIPopoverController *popover;

// A method to call when the user selects a survey
// this will be called even if the user re-selects the currently selected survey
// This sill NOT be called if the user changes the currenly selected survey to nil by deleting the current survey.
// The presenter should check for this case when the view controller is dismissed.
@property (nonatomic, copy) void (^surveySelectedCallback)(Survey *newSurvey);

// A method to call when the name of the selected survey changes
@property (nonatomic, copy) void (^selectedSurveyChangedName)(void);

// A method to call when a survey is deleted
@property (nonatomic, copy) void (^surveyDeleted)(Survey *survey);

// Create a new survey and add it to the tableview.
// presents an alert view if the survey cannot be created
- (void) newSurveyWithProtocol:(SProtocol *)protocol;

//Add the survey to the table view if it isn't there already
- (void) addSurvey:(Survey *)survey;

@end
