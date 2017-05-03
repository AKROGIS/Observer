//
//  SurveySelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SurveyCollection.h"
#import "Survey.h"

@interface SurveySelectViewController : UITableViewController <UITextFieldDelegate>

// The VC model
@property (nonatomic, strong) SurveyCollection *items;

// A block to execute when a survey is selected.
// This will be called even if the user re-selects the current survey
// This will NOT be called if the user deletes the current survey.
@property (nonatomic, copy) void (^surveySelectedAction)(Survey *newSurvey);

// A block to execute when a survey property (i.e. name) is changed
@property (nonatomic, copy) void (^surveyUpdatedAction)(Survey *survey);

// A block to execute when a survey is deleted
@property (nonatomic, copy) void (^surveyDeletedAction)(Survey *survey);

@end
