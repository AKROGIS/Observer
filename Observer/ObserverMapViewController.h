//
//  ObserverMapViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ObserverModel.h"

@interface ObserverMapViewController : UIViewController <CLLocationManagerDelegate, AGSLayerDelegate, AGSMapViewLayerDelegate, AGSMapViewTouchDelegate, AGSCalloutDelegate, LocationPresenter>

//Model
@property (strong, nonatomic) Survey *survey;
@property (strong, nonatomic) Map *map;

@end
