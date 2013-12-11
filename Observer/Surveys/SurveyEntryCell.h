//
//  SurveyEntryCell.h
//  Observer
//
//  Created by Regan Sarwas on 11/7/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SurveyEntryCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UITextField *titleTextField;
@property (weak, nonatomic) IBOutlet UILabel *detailsLabel;

@end
