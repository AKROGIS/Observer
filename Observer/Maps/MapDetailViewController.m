//
//  MapDetailViewController.m
//  Observer
//
//  Created by Regan Sarwas on 12/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "MapDetailViewController.h"
#import "NSDate+Formatting.h"
#import "AKRDirectionIndicatorView.h"

@interface MapDetailViewController () {
    CLLocationManager *_locationManager;
}

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *authorLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet AKRDirectionIndicatorView *directionIndicatorView;

@end

@implementation MapDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    //FIXME: Autolayout bug? - title height in landscape is set by title height in portrait
    self.nameLabel.text = self.map.title;
    self.authorLabel.text = self.map.author;
    self.dateLabel.text = [self.map.date stringWithMediumDateFormat];
    self.sizeLabel.text = [NSString stringWithFormat:@"%@ on %@\n%@", self.map.byteSizeString, (self.map.isLocal ? @"device" : @"server"), self.map.arealSizeString];
    [self setLocationText];
    //FIXME: AutoLayout issue - details not taking all available space in popover
    self.descriptionLabel.text = self.map.description;
    self.thumbnailImageView.image = self.map.thumbnail;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [_locationManager stopMonitoringSignificantLocationChanges];
    _locationManager.delegate = nil;
}

- (void)setLocationText
{
    //NSLog(@"locationServicesEnabled: %d",[CLLocationManager locationServicesEnabled]);
    //NSLog(@"locationServicesAuthorized: %d",[CLLocationManager authorizationStatus]);
    if (![CLLocationManager locationServicesEnabled]) {
        self.locationLabel.text = @"Location unavailable";
        return;
    }
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        //ask for permission by trying
        _locationManager = [CLLocationManager new];
        _locationManager.delegate = self;
        [_locationManager startMonitoringSignificantLocationChanges];
    }
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized)
    {
        self.locationLabel.text = @"Location not authorized";
        return;
    }
    if (!_locationManager) {
        _locationManager = [CLLocationManager new];
        _locationManager.delegate = self;
        [_locationManager startMonitoringSignificantLocationChanges];
    }
    self.locationLabel.text = @"Waiting for current location ...";
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized)
    {
        self.locationLabel.text = @"Waiting for current location ...";
        [_locationManager startMonitoringSignificantLocationChanges];
    } else {
        self.locationLabel.text = @"Location not authorized";
        if (_locationManager) {
            [_locationManager stopMonitoringSignificantLocationChanges];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    AKRAngleDistance *angleDistance = [self.map angleDistanceFromLocation:[locations lastObject]];
    NSString *distanceString = [self distanceStringFromKilometers:angleDistance.kilometers];
    self.locationLabel.text = distanceString;
    self.directionIndicatorView.azimuth = angleDistance.azimuth;
    self.directionIndicatorView.azimuthUnknown = angleDistance.kilometers <= 0;
}

#pragma mark - formatting

+ (NSString *)formatLength:(double)length
{
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSNumberFormatter new];
        formatter.maximumSignificantDigits = 4;
    });
    return [formatter stringFromNumber:[NSNumber numberWithDouble:length]];
}

- (NSString *)distanceStringFromKilometers:(double)kilometers
{
    if (kilometers < 0) {
        return @"Unknown";
    }
    if (kilometers == 0) {
        return @"On map!";
    }
    //TODO: query settings for a metric/SI preference
    if (YES) {
        return [NSString stringWithFormat:@"%@ km", [MapDetailViewController formatLength:kilometers]];
    } else {
        double miles = kilometers * 0.621371;
        return [NSString stringWithFormat:@"%@ mi", [MapDetailViewController formatLength:miles]];
    }
}

- (NSString *)directionStringFromAzimuth:(double)rawAzimuth
{
    double azimuth = rawAzimuth < 0 ? 360+rawAzimuth : rawAzimuth;
    if (azimuth < 0)
        return @"Unknown";
    if (azimuth < 30)
        return @"N";
    if (azimuth < 60)
        return @"NE";
    if (azimuth < 120)
        return @"E";
    if (azimuth < 150)
        return @"SE";
    if (azimuth < 210)
        return @"S";
    if (azimuth < 240)
        return @"SW";
    if (azimuth < 300)
        return @"W";
    if (azimuth < 330)
        return @"NW";
    if (azimuth <= 360)
        return @"N";
    return @"Unknown";
}


@end
