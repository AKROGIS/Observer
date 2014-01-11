//
//  AutoPanStateMachine.m
//  Observer
//
//  Created by Regan Sarwas on 1/9/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "AutoPanStateMachine.h"
#import "Settings.h"

@interface AutoPanStateMachine ()

@property (nonatomic, readwrite) MapAutoPanState state;
@property (nonatomic) double priorSpeed;
@property (nonatomic) double maxSpeedForBearing;

@end

@implementation AutoPanStateMachine

- (id)init
{
    if (self = [super init]) {
        _priorSpeed = 0;
        _maxSpeedForBearing = MINIMUM_NAVIGATION_SPEED;
        _state = [Settings manager].autoPanMode;
        //called on mapview initialization, so map rotation is 0 by default
        if (_state == kAutoPanNoAutoRotate)
            _state = kAutoPanNoAutoRotateNorthUp;
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
    switch (self.state) {
        case kNoAutoPanNoAutoRotate:
        case kNoAutoPanNoAutoRotateNorthUp:
            break;
        case kAutoPanAutoRotateByBearing:
        case kAutoPanAutoRotateByHeading:
        case kAutoPanNoAutoRotate:
            self.state = kNoAutoPanNoAutoRotate;
            [self.autoPanModeButton turnOff];
            break;
        case kAutoPanNoAutoRotateNorthUp:
            self.state = kNoAutoPanNoAutoRotateNorthUp;
            [self.autoPanModeButton turnOff];
            break;
        default:
            NSLog(@"Unexpected MapAutoPanState (%d) in AutoPanStateMachine.userPannedMap", self.state);
            break;
    }
}

- (void)userRotatedMap
{
    //When the user rotates the map, the mapView will automatically turn off autorotate (but not autopan) in the mapView,
    //but we must update the state we control.
    //The mapViewController takes care of rotating the compassRoseButton
    switch (self.state) {
        case kNoAutoPanNoAutoRotate:
        case kAutoPanNoAutoRotate:
            break;
        case kAutoPanAutoRotateByBearing:
        case kAutoPanAutoRotateByHeading:
            self.state = kAutoPanNoAutoRotate;
            [self.autoPanModeButton turnOnWithoutRotate];
            self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
            break;
        case kAutoPanNoAutoRotateNorthUp:
            self.state = kAutoPanNoAutoRotate;
            [self showCompassRoseButton];
            break;
        case kNoAutoPanNoAutoRotateNorthUp:
            self.state = kNoAutoPanNoAutoRotate;
            [self showCompassRoseButton];
            break;
        default:
            NSLog(@"Unexpected MapAutoPanState (%d) in AutoPanStateMachine.userRotatedMap", self.state);
            break;
    }
}

- (void)userClickedAutoPanButton
{
    switch (self.state) {
        case kNoAutoPanNoAutoRotateNorthUp:
            self.state = kAutoPanNoAutoRotateNorthUp;
            [self.autoPanModeButton turnOnWithoutRotate];
            self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
            break;
        case kNoAutoPanNoAutoRotate:
            self.state = kAutoPanNoAutoRotate;
            [self.autoPanModeButton turnOnWithoutRotate];
            self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
            break;
        case kAutoPanNoAutoRotateNorthUp:
            [self showCompassRoseButton];
            [self selectRotationStyleBasedOnSpeed];
            [self.autoPanModeButton turnOnWithRotate];
            break;
        case kAutoPanNoAutoRotate:
            [self selectRotationStyleBasedOnSpeed];
            [self.autoPanModeButton turnOnWithRotate];
            break;
        case kAutoPanAutoRotateByBearing:
        case kAutoPanAutoRotateByHeading:
            self.state = kNoAutoPanNoAutoRotate;
            self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
            [self.autoPanModeButton turnOff];
            break;
        default:
            NSLog(@"Unexpected MapAutoPanState (%d) in AutoPanStateMachine.userClickedAutoPanButton", self.state);
            break;
    }
}

- (void)userClickedCompassRoseButton
{
    switch (self.state) {
        case kNoAutoPanNoAutoRotateNorthUp:
        case kAutoPanNoAutoRotateNorthUp:
            break;
        case kNoAutoPanNoAutoRotate:
            self.state = kNoAutoPanNoAutoRotateNorthUp;
            self.mapView.rotationAngle = 0;
            [self hideCompassRoseButton];
            break;
        case kAutoPanNoAutoRotate:
            self.state = kAutoPanNoAutoRotateNorthUp;
            self.mapView.rotationAngle = 0;
            [self hideCompassRoseButton];
            break;
        case kAutoPanAutoRotateByBearing:
        case kAutoPanAutoRotateByHeading:
            self.state = kAutoPanNoAutoRotateNorthUp;
            self.mapView.rotationAngle = 0;
            [self hideCompassRoseButton];
            [self.autoPanModeButton turnOnWithoutRotate];
            break;
        default:
            NSLog(@"Unexpected MapAutoPanState (%d) in AutoPanStateMachine.userClickedCompassRoseButton", self.state);
            break;
    }
}

- (void)speedUpdate:(double)newSpeed
{
    switch (self.state) {
        case kNoAutoPanNoAutoRotateNorthUp:
        case kNoAutoPanNoAutoRotate:
        case kAutoPanNoAutoRotateNorthUp:
        case kAutoPanNoAutoRotate:
            break;
        case kAutoPanAutoRotateByBearing:
            if (self.maxSpeedForBearing < newSpeed) {
                self.state = kAutoPanAutoRotateByHeading;
                //NSLog(@"AutoPan switch Bearing -> Heading, speed %f",newSpeed);
                self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeNavigation;
            }
            break;
        case kAutoPanAutoRotateByHeading:
            if (newSpeed <= self.maxSpeedForBearing) {
                self.state = kAutoPanAutoRotateByBearing;
                //NSLog(@"AutoPan switch Heading -> Bearing, speed %f",newSpeed);
                self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
            }
            break;
        default:
            NSLog(@"Unexpected MapAutoPanState (%d) in AutoPanStateMachine.speedUpdate", self.state);
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
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
    } else if (self.state == kAutoPanAutoRotateByBearing) {
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
    } else if (self.state == kAutoPanAutoRotateByHeading) {
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeNavigation;
    } else {
        mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
    }
    //NSLog(@"Initialize autopan state with autopan mode %d", mapView.locationDisplay.autoPanMode);
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
    //NSLog(@"hide compass rose");
    CATransition *animation = [CATransition animation];
    animation.type = kCATransitionFade;
    animation.duration = 0.4;
    [self.compassRoseButton.layer addAnimation:animation forKey:nil];
    self.compassRoseButton.hidden = YES;
}

- (void)showCompassRoseButton
{
    //NSLog(@"show compass rose");
    CATransition *animation = [CATransition animation];
    animation.type = kCATransitionFade;
    animation.duration = 0.4;
    [self.compassRoseButton.layer addAnimation:animation forKey:nil];
    self.compassRoseButton.hidden = NO;
}

- (void)selectRotationStyleBasedOnSpeed
{
    if (self.maxSpeedForBearing < self.priorSpeed) {
        self.state = kAutoPanAutoRotateByHeading;
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeNavigation;
    } else {
        self.state = kAutoPanAutoRotateByBearing;
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
    }
}

@end
