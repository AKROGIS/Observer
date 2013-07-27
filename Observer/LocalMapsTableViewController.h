//
//  LocalMapsTableViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseMapManager.h"

@interface LocalMapsTableViewController : UITableViewController

//model
@property (strong, nonatomic) BaseMapManager *maps;
@property (weak, nonatomic) UIPopoverController *popover;

@end
