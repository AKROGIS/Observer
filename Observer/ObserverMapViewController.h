//
//  ObserverMapViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ObserverModel.h"

@interface ObserverMapViewController : UIViewController <UIPopoverControllerDelegate, CLLocationManagerDelegate, AGSMapViewLayerDelegate, AGSMapViewTouchDelegate, AGSCalloutDelegate, AGSLayerDelegate, UIAlertViewDelegate>

@property (nonatomic) BOOL busy;
@property (nonatomic,weak) NSManagedObjectContext *context;

//To assist App delegate in opening urls from mail/web
- (BOOL) openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;

- (void) openModel;

- (void) closeModel;

- (void) saveModel;

@end
