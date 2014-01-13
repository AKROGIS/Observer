//
//  ObserverMapViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ObserverModel.h"

@interface ObserverMapViewController : UIViewController <CLLocationManagerDelegate, AGSLayerDelegate, AGSMapViewLayerDelegate, AGSMapViewTouchDelegate, AGSCalloutDelegate, UIPopoverControllerDelegate, UIAlertViewDelegate>

// To assist AppDelegate in opening urls from mail/web
- (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;

// To assist AppDelegate in saving/closing the survey data
- (void)closeSurvey;
- (void)saveSurvey;

@end
