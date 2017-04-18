//
//  SurveyTableViewCell.m
//  Observer
//
//  Created by Regan Sarwas on 11/7/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyTableViewCell.h"

@implementation SurveyTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void) setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    UITextField *titleTextField = self.titleTextField;
    [UIView animateWithDuration:0.1 animations:^{
        //TODO: #41 does not turn off in all cases
        if (editing && !self.showingDeleteConfirmation) {
            titleTextField.enabled = YES;
            titleTextField.borderStyle = UITextBorderStyleRoundedRect;
        } else {
            titleTextField.enabled = NO;
            titleTextField.borderStyle = UITextBorderStyleNone;
        }
    }];
}

//TODO: #41 turn off textField editing when transitioning from delete to delete confirmation and back on in reverse
//- (void)willTransitionToState:(UITableViewCellStateMask)state
//{    [super willTransitionToState:state];}


@end
