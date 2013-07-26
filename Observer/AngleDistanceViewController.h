//
//  AngleDistanceViewController.h
//  Observer
//
//  Created by Regan Sarwas on 7/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ArcGIS/ArcGIS.h>

@interface AngleDistanceViewController : UIViewController <UIPickerViewDelegate, UIPickerViewDataSource>

@property (strong, nonatomic) AGSPoint *gpsPoint;
@property (nonatomic) double course;
@property (nonatomic, readonly) BOOL isCanceled;
@property (strong, nonatomic, readonly) AGSPoint *observationPoint;

@property (nonatomic) double angle;
@property (nonatomic) double referenceAngle;
@property (nonatomic) double distance;
@property (nonatomic) AGSSRUnit distanceUnits;

@end
