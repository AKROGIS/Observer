//
//  AngleDistanceViewController.m
//  Observer
//
//  Created by Regan Sarwas on 7/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AngleDistanceViewController.h"
#import "AGSPoint+AKRAdditions.h"
#import "Settings.h"
#import "AngleDistanceSettingsTableViewController.h"

@interface AngleDistanceViewController ()

@property (weak, nonatomic) IBOutlet UILabel *warningLabel;
@property (weak, nonatomic) IBOutlet UILabel *detailsLabel;
@property (weak, nonatomic) IBOutlet UIButton *basisButton;

@end

@implementation AngleDistanceViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.course = -1;
        self.angle = [Settings manager].angleDistanceLastAngle;
        self.distance = [Settings manager].angleDistanceLastDistance;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self hideControls];
}

- (void) viewWillAppear:(BOOL)animated
{
    [self settingsDidChange:nil];
    self.contentSizeForViewInPopover = CGSizeMake(320,250.0);
    self.navigationController.contentSizeForViewInPopover = self.contentSizeForViewInPopover;
    [super viewWillAppear:animated];
}

- (void) viewDidAppear:(BOOL)animated {
    NSLog(@"View Did Appear");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];
    [super viewDidAppear:animated];
    [self.popover setPopoverContentSize:self.contentSizeForViewInPopover animated:YES];
}

- (void) viewDidDisappear:(BOOL)animated
{
    NSLog(@"View Did Disappear");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"PushAngleDistanceSettings"]) {
        AngleDistanceSettingsTableViewController *vc = (AngleDistanceSettingsTableViewController *)segue.destinationViewController;
        vc.protocol = self.protocol;
    }
}

#pragma mark - Public Properties

- (void) setCourse:(double)course
{
    if (_course == course)
        return;
    _course = course;
    [self hideControls];
}

- (void) setProtocol:(SurveyProtocol *)protocol
{
    _protocol = protocol;
    [self settingsDidChange:nil];
    [self hideControls];
}

- (AGSPoint *)observationPoint
{
    double course = self.course < 0 ? 0 : self.course;
    double angle  = course + self.angle - self.referenceAngle;
    return [self.gpsPoint pointWithAngle:angle distance:self.distance units:self.distanceUnits];   
}


#pragma mark - Private Methods

- (void) hideControls
{
    self.warningLabel.hidden = self.course < 0;
    self.basisButton.hidden = (self.protocol && self.protocol.definesAngleDistanceMeasures);
}

- (void) settingsDidChange:(NSNotification *)notification
{
    if (self.protocol && self.protocol.definesAngleDistanceMeasures)
    {
        self.distanceUnits = self.protocol.distanceUnits;
        self.referenceAngle = self.protocol.angleBaseline;
        self.angleDirection = self.protocol.angleDirection;
    }
    else
    {
        self.distanceUnits = [Settings manager].distanceUnitsForSightings;
        self.referenceAngle = [Settings manager].angleDistanceDeadAhead;
        self.angleDirection = [Settings manager].angleDistanceAngleDirection;
    }
    [self updateLabel];
}

- (void) updateLabel
{
    self.detailsLabel.text = [NSString stringWithFormat:@"Angle increases %@ with %@ equal to %u degrees%@.  Distance is in %@.",
                              self.angleDirection == 0 ? @"clockwise" : @"counter-clockwise",
                              self.course < 0 ? @"true north" : @"dead ahead",
                              (int)self.referenceAngle,
                              self.course < 0 ? @" (heading is unavailable)" : @"",
                              self.distanceUnits == AGSSRUnitMeter ? @"meters" :
                              self.distanceUnits == AGSSRUnitFoot ? @"feet" :
                              self.distanceUnits == AGSSRUnitInternationalYard ? @"yards" : @"unknown units"
                              ];
    [self.detailsLabel sizeToFit];
}

@end
