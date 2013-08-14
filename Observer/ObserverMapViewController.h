//
//  ObserverMapViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ObserverMapViewController : UIViewController <UIPopoverControllerDelegate, CLLocationManagerDelegate, AGSMapViewLayerDelegate, AGSMapViewTouchDelegate, AGSMapViewCalloutDelegate, AGSLayerDelegate>

@property (nonatomic) BOOL busy;
@property (nonatomic,weak) NSManagedObjectContext *context;

@end
