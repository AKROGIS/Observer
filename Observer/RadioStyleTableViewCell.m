//
//  RadioStyleTableViewCell.m
//  Observer
//
//  Created by Regan Sarwas on 7/30/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "RadioStyleTableViewCell.h"

@interface RadioStyleTableViewCell ()

@property (strong, nonatomic) UIColor *buttonBlue;

@end


@implementation RadioStyleTableViewCell
UIColor *_buttonBlue;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (UIColor *)buttonBlue
{
    if (!_buttonBlue) {
        //_buttonBlue = [[[UIButton alloc] init] titleColorForState: UIControlStateNormal];
        _buttonBlue = [UIColor colorWithRed:0.19607843459999999 green:0.30980393290000002 blue:0.52156865600000002 alpha:1.0]; //From the story board file for a default button
        NSLog(@"Set Blue = %@", _buttonBlue);
    }
    return _buttonBlue;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    //self.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.textLabel.textColor = selected ? self.buttonBlue : [UIColor blackColor];
    //[UIView animateWithDuration:0.3f animations:^{yourLabel.alpha = 0.f;}];
    /*
    if (selected)
    {
        [UIView animateWithDuration:0.3f animations:^{
            //self.textLabel.alpha = 0.3f;
            //self.textLabel.textColor = [UIColor blackColor];
            self.backgroundColor = [UIColor whiteColor];
        }];
    }
     */
    // Configure the view for the selected state
}

@end
