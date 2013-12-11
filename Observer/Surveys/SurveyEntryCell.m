//
//  SurveyEntryCell.m
//  Observer
//
//  Created by Regan Sarwas on 11/7/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyEntryCell.h"

@implementation SurveyEntryCell

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
    [UIView animateWithDuration:0.1 animations:^{
        //FIXME: does not turn off in all cases
        if (editing && !self.showingDeleteConfirmation) {
            self.titleTextField.enabled = YES;
            self.titleTextField.borderStyle = UITextBorderStyleRoundedRect;
        } else {
            self.titleTextField.enabled = NO;
            self.titleTextField.borderStyle = UITextBorderStyleNone;
        }
    }];
}

//TODO: turn off textField editing when transitioning from delete to delete confirmation and back on in reverse
//- (void)willTransitionToState:(UITableViewCellStateMask)state
//{    [super willTransitionToState:state];}


@end
