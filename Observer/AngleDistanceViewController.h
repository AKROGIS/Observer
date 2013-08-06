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

@interface AngleDistanceViewController : UIViewController <UITextFieldDelegate>

//Inputs

//The point of reference for the angle/distance measurements - Required
@property (strong, nonatomic) AGSPoint *gpsPoint;
//the course (or heading) for dead ahead (positive = clockwise, with 0 = north) - Required
@property (nonatomic) NSNumber *deadAhead;
//the protocol may specify how angle/distance measurements are to be taken
@property (nonatomic, strong) SurveyProtocol *protocol;
//the default angle provided by the caller - a nullable double
@property (nonatomic, strong) NSNumber *defaultAngle;
//the default distance provided by the caller - a nullable positive double
@property (nonatomic, strong) NSNumber *defaultDistance;

//Outputs

//the current angle provided by the user - a nullable double
- (NSNumber *) angle;
//the current distance provided by the user - a nullable positive double
- (NSNumber *) distance;
//the new observation point, requires non-null gpsPoint, deadAhead, distance, angle,
- (AGSPoint *) observationPoint;

//Optional control objects

//if this VC is in a popover, it will resize and dismiss the popover when appropriate
@property (weak, nonatomic) UIPopoverController *popover;
//a method to call when the VC is done.  Not called if the user cancels or quits the VC
@property (strong, nonatomic) void(^completionBlock)(AngleDistanceViewController *);

@end
