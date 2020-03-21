//
//  AutoPanStateMachine.m
//  Observer
//
//  Created by Regan Sarwas on 1/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "AutoPanStateMachine.h"
#import "Settings.h"
#import "AKRLog.h"

@interface AutoPanStateMachine ()

@property (nonatomic, readwrite) MapAutoPanState state;
@property (nonatomic) double priorSpeed;
@property (nonatomic) double maxSpeedForBearing;

@end

@implementation AutoPanStateMachine

- (instancetype)init
{
    self = [super init];
    if (self) {
        _priorSpeed = 0;
        _maxSpeedForBearing = MINIMUM_NAVIGATION_SPEED;
        _state = [Settings manager].autoPanMode;
        //map rotation is not persisted - it defaults to zero.  Assume it is zero, and correct saved state to match;
        //I can check this assumption when I get the mapView proterty is set, and make corrections if necessary;
        if (_state == kAutoPanNoAutoRotate) {
            _state = kAutoPanNoAutoRotateNorthUp;
        }
        if (_state == kNoAutoPanNoAutoRotate) {
            _state = kNoAutoPanNoAutoRotateNorthUp;
        }
    }
    return self;
}

#pragma mark - public actions

- (void)userPannedMap
{
    //When the user pans the map, the mapView will automatically turn off autopan in the mapView,
    //but we must update the state we control.
    AutoPanButton *autoPanModeButton = self.autoPanModeButton;
    switch (self.state) {
        case kNoAutoPanNoAutoRotate:
        case kNoAutoPanNoAutoRotateNorthUp:
            break;
        case kAutoPanAutoRotateByBearing:
        case kAutoPanAutoRotateByHeading:
        case kAutoPanNoAutoRotate:
            self.state = kNoAutoPanNoAutoRotate;
            [autoPanModeButton turnOff];
            break;
        case kAutoPanNoAutoRotateNorthUp:
            self.state = kNoAutoPanNoAutoRotateNorthUp;
            [autoPanModeButton turnOff];
            break;
    }
}

- (void)userRotatedMap
{
    //When the user rotates the map, the mapView will automatically turn off autorotate (but not autopan) in the mapView,
    //but we must update the state we control.
    //The mapViewController takes care of rotating the compassRoseButton
    AutoPanButton *autoPanModeButton = self.autoPanModeButton;
    AGSMapView *mapView = self.mapView;
    switch (self.state) {
        case kNoAutoPanNoAutoRotate:
        case kAutoPanNoAutoRotate:
            break;
        case kAutoPanAutoRotateByBearing:
        case kAutoPanAutoRotateByHeading:
            self.state = kAutoPanNoAutoRotate;
            [autoPanModeButton turnOnWithoutRotate];
            mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeRecenter;
            break;
        case kAutoPanNoAutoRotateNorthUp:
            self.state = kAutoPanNoAutoRotate;
            [self showCompassRoseButton];
            break;
        case kNoAutoPanNoAutoRotateNorthUp:
            self.state = kNoAutoPanNoAutoRotate;
            [self showCompassRoseButton];
            break;
    }
}

- (void)userClickedAutoPanButton
{
    AutoPanButton *autoPanModeButton = self.autoPanModeButton;
    AGSMapView *mapView = self.mapView;
    switch (self.state) {
        case kNoAutoPanNoAutoRotateNorthUp:
            self.state = kAutoPanNoAutoRotateNorthUp;
            [autoPanModeButton turnOnWithoutRotate];
            mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeRecenter;
            break;
        case kNoAutoPanNoAutoRotate:
            self.state = kAutoPanNoAutoRotate;
            [autoPanModeButton turnOnWithoutRotate];
            mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeRecenter;
            break;
        case kAutoPanNoAutoRotateNorthUp:
            [self showCompassRoseButton];
            [self selectRotationStyleBasedOnSpeed];
            [autoPanModeButton turnOnWithRotate];
            break;
        case kAutoPanNoAutoRotate:
            [self selectRotationStyleBasedOnSpeed];
            [autoPanModeButton turnOnWithRotate];
            break;
        case kAutoPanAutoRotateByBearing:
        case kAutoPanAutoRotateByHeading:
            self.state = kNoAutoPanNoAutoRotate;
            mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
            [autoPanModeButton turnOff];
            break;
    }
}

- (void)userClickedCompassRoseButton
{
    AutoPanButton *autoPanModeButton = self.autoPanModeButton;
    AGSMapView *mapView = self.mapView;
    switch (self.state) {
        case kNoAutoPanNoAutoRotateNorthUp:
        case kAutoPanNoAutoRotateNorthUp:
            break;
        case kNoAutoPanNoAutoRotate:
            self.state = kNoAutoPanNoAutoRotateNorthUp;
            [mapView setViewpointRotation:0.0 completion:nil];
            [self hideCompassRoseButton];
            break;
        case kAutoPanNoAutoRotate:
            self.state = kAutoPanNoAutoRotateNorthUp;
            [mapView setViewpointRotation:0.0 completion:nil];
            [self hideCompassRoseButton];
            break;
        case kAutoPanAutoRotateByBearing:
        case kAutoPanAutoRotateByHeading:
            self.state = kAutoPanNoAutoRotateNorthUp;
            [mapView setViewpointRotation:0.0 completion:nil];
            [self hideCompassRoseButton];
            [autoPanModeButton turnOnWithoutRotate];
            mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeRecenter;
            break;
    }
}

- (void)speedUpdate:(double)newSpeed
{
    AGSMapView *mapView = self.mapView;
    switch (self.state) {
        case kNoAutoPanNoAutoRotateNorthUp:
        case kNoAutoPanNoAutoRotate:
        case kAutoPanNoAutoRotateNorthUp:
        case kAutoPanNoAutoRotate:
            break;
        case kAutoPanAutoRotateByBearing:
            if (self.maxSpeedForBearing < newSpeed) {
                self.state = kAutoPanAutoRotateByHeading;
                mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeNavigation;
            }
            break;
        case kAutoPanAutoRotateByHeading:
            if (newSpeed <= self.maxSpeedForBearing) {
                self.state = kAutoPanAutoRotateByBearing;
                mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
            }
            break;
    }
    self.priorSpeed = newSpeed;
}



#pragma mark - private methods

- (void)setState:(MapAutoPanState)state
{
    if (state != _state) {
        [Settings manager].autoPanMode = state;
        _state = state;
    }
}

- (void)setAutoPanModeButton:(AutoPanButton *)autoPanModeButton
{
    _autoPanModeButton = autoPanModeButton;
    if (self.state == kAutoPanNoAutoRotate || self.state == kAutoPanNoAutoRotateNorthUp) {
        [autoPanModeButton turnOnWithoutRotate];
    } else if (self.state == kAutoPanAutoRotateByBearing || self.state == kAutoPanAutoRotateByHeading) {
        [autoPanModeButton turnOnWithRotate];
    } else {
        [autoPanModeButton turnOff];
    }
}

- (void)setMapView:(AGSMapView *)mapView
{
    _mapView = mapView;
    if (self.state == kAutoPanNoAutoRotate || self.state == kAutoPanNoAutoRotateNorthUp) {
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeRecenter;
    } else if (self.state == kAutoPanAutoRotateByBearing) {
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
    } else if (self.state == kAutoPanAutoRotateByHeading) {
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeNavigation;
    } else {
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
    }
    //Initilaizer assumed a mapView rotation of zero; correct if that assumption was wrong; convert to an int, so we do not compare floats
    int rotation = (int)mapView.rotation;
    if (rotation != 0) {
        if (_state == kAutoPanNoAutoRotateNorthUp) {
            _state = kAutoPanNoAutoRotate;
        }
        if (_state == kNoAutoPanNoAutoRotateNorthUp) {
            _state = kNoAutoPanNoAutoRotate;
        }
        [self showCompassRoseButton];
    }
}

- (void)setCompassRoseButton:(UIButton *)compassRoseButton
{
    _compassRoseButton = compassRoseButton;
    if (self.state == kNoAutoPanNoAutoRotateNorthUp || self.state == kAutoPanNoAutoRotateNorthUp) {
        [self hideCompassRoseButton];
    } else {
        [self showCompassRoseButton];
    }
}

- (void)hideCompassRoseButton
{
    //AKRLog(@"hide compass rose");
    UIButton *compassRoseButton = self.compassRoseButton;
    CATransition *animation = [CATransition animation];
    animation.type = kCATransitionFade;
    animation.duration = 0.4;
    [compassRoseButton.layer addAnimation:animation forKey:nil];
    compassRoseButton.hidden = YES;
}

- (void)showCompassRoseButton
{
    //AKRLog(@"show compass rose");
    UIButton *compassRoseButton = self.compassRoseButton;
    CATransition *animation = [CATransition animation];
    animation.type = kCATransitionFade;
    animation.duration = 0.4;
    [compassRoseButton.layer addAnimation:animation forKey:nil];
    compassRoseButton.hidden = NO;
}

- (void)selectRotationStyleBasedOnSpeed
{
    AGSMapView *mapView = self.mapView;
    if (self.maxSpeedForBearing < self.priorSpeed) {
        self.state = kAutoPanAutoRotateByHeading;
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeNavigation;
    } else {
        self.state = kAutoPanAutoRotateByBearing;
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
    }
}

@end
