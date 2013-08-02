//
//  AngleDistanceViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ArcGIS/ArcGIS.h>
#import "SurveyProtocol.h"
#import "Enumerations.h"

@class AngleDistanceViewController;

typedef void(^CompletionBlock)(AngleDistanceViewController *sender);

@interface AngleDistanceViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) UIPopoverController *popover;

@property (strong, nonatomic) CompletionBlock completionBlock;

@property (strong, nonatomic) AGSPoint *gpsPoint;
@property (nonatomic) double course;
@property (strong, nonatomic, readonly) AGSPoint *observationPoint;
@property (nonatomic, readonly) double angle;
@property (nonatomic, readonly) double distance;

@property (nonatomic) SurveyProtocol *protocol;
@property (nonatomic) double referenceAngle;
@property (nonatomic) AGSSRUnit distanceUnits;
@property (nonatomic) AngleDirection angleDirection;

@end
