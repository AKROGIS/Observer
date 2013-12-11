//
//  MapTableViewCell.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AKRDownloadView.h"

@interface MapTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitle1Label;
@property (weak, nonatomic) IBOutlet UILabel *subtitle2Label;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet AKRDownloadView *downloadView;
@property (weak, nonatomic) IBOutlet UIImageView *downloadImageView;
@end
