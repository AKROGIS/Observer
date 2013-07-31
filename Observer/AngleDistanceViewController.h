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

@interface AngleDistanceViewController : UIViewController

@property (weak, nonatomic) UIPopoverController *popover;

@property (strong, nonatomic) AGSPoint *gpsPoint;
@property (nonatomic) double course;
@property (nonatomic, readonly) BOOL isCanceled;
@property (strong, nonatomic, readonly) AGSPoint *observationPoint;

@property (nonatomic) double angle;
@property (nonatomic) double distance;
@property (nonatomic) SurveyProtocol *protocol;
@property (nonatomic) double referenceAngle;
@property (nonatomic) AGSSRUnit distanceUnits;
@property (nonatomic) AngleDirection angleDirection;

@end
