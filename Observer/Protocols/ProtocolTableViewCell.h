//
//  ProtocolTableViewCell.h
//  Observer
//
//  Created by Regan Sarwas on 11/21/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

//FIXME - It would be nice to use the space not used by a hidden download image for a long title or subtitle.

#import <UIKit/UIKit.h>

@interface ProtocolTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UIImageView *downloadImageView;
@end
