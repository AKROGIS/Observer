//
//  MapDetailViewController.h
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Map.h"

@interface MapDetailViewController : UIViewController <CLLocationManagerDelegate>

@property (strong, nonatomic) Map *map;

@end
