//
//  RadioStyleTableViewCell.m
//  Observer
//
//  Created by Regan Sarwas on 7/30/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "RadioStyleTableViewCell.h"
#import "AKRLog.h"

@interface RadioStyleTableViewCell ()

@property (strong, nonatomic) UIColor *buttonBlue;

@end


@implementation RadioStyleTableViewCell

static UIColor *_buttonBlue;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
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
        _buttonBlue = [UIColor colorWithRed:(CGFloat)0.1960784346 green:(CGFloat)0.3098039329 blue:(CGFloat)0.521568656 alpha:1.0]; //From the story board file for a default button
        //AKRLog(@"Set Blue = %@", _buttonBlue);
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
