//
//  GpsPointTableViewController.h
//  Observer
//
//  Created by Regan Sarwas on 4/28/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GpsPoint.h"
#import "AdhocLocation.h"

@interface GpsPointTableViewController : UITableViewController

@property (nonatomic, strong) GpsPoint *gpsPoint;
@property (nonatomic, strong) AdhocLocation *adhocLocation;

@end
