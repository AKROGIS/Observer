//
//  MapDetailViewController.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "MapDetailViewController.h"
#import "NSDate+Formatting.h"

@interface MapDetailViewController ()

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *authorLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;

@end

@implementation MapDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    //TODO: turn on location services; have it update location label with major changes
    //FIXME: Autolayout bug? - title height in landscape is set by title height in portrait
    self.nameLabel.text = self.map.title;
    self.authorLabel.text = self.map.author;
    self.dateLabel.text = [self.map.date stringWithMediumDateFormat];
    self.sizeLabel.text = [NSString stringWithFormat:@"%@ on %@\n%@", self.map.byteSizeString, (self.map.isLocal ? @"device" : @"server"), self.map.arealSizeString];
    self.locationLabel.text = @"Waiting for current location...";
    //FIXME: AutoLayout issue - details not taking all available space in popover
    self.descriptionLabel.text = self.map.description;
    self.thumbnailImageView.image = self.map.thumbnail;
}

@end
