//
//  ProtocolSelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/20/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ProtocolDetailViewController.h"
#import "ProtocolCollection.h"

@interface ProtocolSelectViewController : UITableViewController <CollectionChanged>

@property (strong, nonatomic) ProtocolDetailViewController *detailViewController;
@property (nonatomic, weak) ProtocolCollection *items;
@property (nonatomic, weak) UIPopoverController *popover;
@property (copy) void (^rowSelectedCallback)(NSIndexPath *indexPath);

@end
