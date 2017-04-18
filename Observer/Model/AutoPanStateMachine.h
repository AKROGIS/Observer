//
//  AutoPanStateMachine.h
//  Observer
//
//  Created by Regan Sarwas on 1/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <ArcGIS/ArcGIS.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AutoPanButton.h"

#define MINIMUM_NAVIGATION_SPEED 1.0  //speed in meters per second (1mps = 2.2mph) at which to switch map orientation from compass heading to course direction

typedef NS_ENUM(NSUInteger, MapAutoPanState) {
    kNoAutoPanNoAutoRotateNorthUp = 0,
    kNoAutoPanNoAutoRotate        = 1,
    kAutoPanNoAutoRotateNorthUp   = 2,
    kAutoPanNoAutoRotate          = 3,
    kAutoPanAutoRotateByHeading   = 4,
    kAutoPanAutoRotateByBearing   = 5,
};

@interface AutoPanStateMachine : NSObject

//state
@property (nonatomic, readonly) MapAutoPanState state;

//actions
- (void)userPannedMap;
- (void)userRotatedMap;
- (void)userClickedAutoPanButton;
- (void)userClickedCompassRoseButton;
- (void)speedUpdate:(double)newSpeed;

//outlets
@property (weak, nonatomic) AutoPanButton *autoPanModeButton;
@property (weak, nonatomic) UIButton *compassRoseButton;
@property (weak, nonatomic) AGSMapView *mapView;

@end
