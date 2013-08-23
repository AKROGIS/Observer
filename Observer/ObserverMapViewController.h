//
//  ObserverMapViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ObserverModel.h"

@interface ObserverMapViewController : UIViewController <UIPopoverControllerDelegate, CLLocationManagerDelegate, AGSMapViewLayerDelegate, AGSMapViewTouchDelegate, AGSMapViewCalloutDelegate, AGSLayerDelegate, UIAlertViewDelegate>

@property (nonatomic) BOOL busy;
@property (nonatomic,weak) NSManagedObjectContext *context;


- (void) closeModel;

- (void) saveModel;

@end
