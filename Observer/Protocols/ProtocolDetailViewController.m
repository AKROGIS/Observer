//
//  ProtocolDetailViewController.m
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "ProtocolDetailViewController.h"

#define TEXTMARGINS 60  //2*30pts

@interface ProtocolDetailViewController ()
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;

@end

@implementation ProtocolDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.nameLabel.preferredMaxLayoutWidth = self.preferredContentSize.width - TEXTMARGINS;
    self.nameLabel.text = self.protocol.version != nil ? [NSString stringWithFormat:@"%@, v. %@", self.protocol.title, self.protocol.version] : self.protocol.title;
    self.dateLabel.text = self.protocol.dateString;
    self.descriptionLabel.preferredMaxLayoutWidth = self.preferredContentSize.width - TEXTMARGINS;
    self.descriptionLabel.text = self.protocol.isLocal ? self.protocol.details : @"Download the protocol for more details.";
}

@end
