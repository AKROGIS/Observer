//
//  ObserverAppDelegate.h
//  Observer
//
//  Created by Regan Sarwas on 7/2/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SurveyCollection.h"

@interface ObserverAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic, readonly) SurveyCollection *surveys;

@end
