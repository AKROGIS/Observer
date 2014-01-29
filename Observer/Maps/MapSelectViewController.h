//
//  MapSelectViewController.h
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MapDetailViewController.h"
#import "MapCollection.h"

@interface MapSelectViewController : UITableViewController <CollectionChanged>

@property (strong, nonatomic) MapDetailViewController *detailViewController;
@property (strong, nonatomic) MapCollection *items;
@property (strong, nonatomic) UIPopoverController *popover;
@property (copy, nonatomic) void (^rowSelectedCallback)(NSIndexPath *indexPath);

@end
