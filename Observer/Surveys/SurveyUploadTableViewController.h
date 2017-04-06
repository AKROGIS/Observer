//
//  SurveyUploadTableViewController.h
//  Observer
//
//  Created by Regan Sarwas on 5/27/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "Survey.h"

@interface SurveyUploadTableViewController : UITableViewController <MFMailComposeViewControllerDelegate>

@property (strong, nonatomic) Survey *survey;

@end
