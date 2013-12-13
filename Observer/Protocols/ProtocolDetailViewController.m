//
//  ProtocolDetailViewController.m
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "ProtocolDetailViewController.h"

@interface ProtocolDetailViewController ()
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;

@end

@implementation ProtocolDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    //FIXME: Remove this magic number, but keep the autolayout height of uilabel with 0 lines
    self.nameLabel.preferredMaxLayoutWidth = 320;
    self.nameLabel.text = self.protocol.version ? [NSString stringWithFormat:@"%@, v. %@", self.protocol.title, self.protocol.version] : self.protocol.title;
    self.dateLabel.text = self.protocol.dateString;
    //FIXME: Remove this magic number, but keep the autolayout height of uilabel with 0 lines
    self.descriptionLabel.preferredMaxLayoutWidth = 320;
    self.descriptionLabel.text = self.protocol.isLocal ? self.protocol.details : @"Download the protocol for more details.";
}

@end
