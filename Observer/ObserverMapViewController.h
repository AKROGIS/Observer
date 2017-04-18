//
//  ObserverMapViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import "Survey.h"
#import "Map.h"

@interface ObserverMapViewController : UIViewController <CLLocationManagerDelegate, AGSLayerDelegate, AGSMapViewLayerDelegate, AGSMapViewTouchDelegate, AGSCalloutDelegate, LocationPresenter, UIPopoverPresentationControllerDelegate>

//Model
@property (strong, nonatomic) Survey *survey;
@property (strong, nonatomic) Map *map;

@end
