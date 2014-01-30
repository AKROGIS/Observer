//
//  AngleDistanceSettingsTableViewController.m
//  Observer
//
//  Created by Regan Sarwas on 7/29/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AngleDistanceSettingsTableViewController.h"
#import "Settings.h"

@interface AngleDistanceSettingsTableViewController ()

@property (weak, nonatomic) IBOutlet UITableViewCell *clockwiseTVC;
@property (weak, nonatomic) IBOutlet UITableViewCell *counterclockwiseTVC;
@property (weak, nonatomic) IBOutlet UITableViewCell *deadAheadZeroTVC;
@property (weak, nonatomic) IBOutlet UITableViewCell *deadAhead90TVC;
@property (weak, nonatomic) IBOutlet UITableViewCell *deadAhead180TVC;
@property (weak, nonatomic) IBOutlet UITableViewCell *metersTVC;
@property (weak, nonatomic) IBOutlet UITableViewCell *feetTVC;
@property (weak, nonatomic) IBOutlet UITableViewCell *yardsTVC;

@end

@implementation AngleDistanceSettingsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self settingsDidChange:nil];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];
}

- (void) viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    [super viewDidDisappear:animated];
}

- (void) didMoveToParentViewController:(UIViewController *)parent
{
    //called with parent == nil when we are removed from a view controller (i.e. popped from the nav controller)
    if (!parent)
        if (self.completionBlock)
            self.completionBlock(self);
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:
            [self selectAngleDirection:indexPath.row];
            break;
        case 1:
            [self selectAngleBaseline:indexPath.row];
            break;
        case 2:
            [self selectDistanceUnits:indexPath.row];
            break;
    }
}

#pragma mark - Public API

- (void) setFeature:(ProtocolFeature *)feature
{
    _feature = feature;
    [self settingsDidChange:nil];
}


#pragma mark - private Methods

- (void) settingsDidChange:(NSNotification *)notification
{
    if (self.feature)
    {
        [self selectSettingsWithDistanceUnits:self.feature.allowedLocations.distanceUnits
                                angleBaseline:self.feature.allowedLocations.angleBaseline
                               angleDirection:self.feature.allowedLocations.angleDirection];
    }
    else
    {
        [self selectSettingsWithDistanceUnits:[Settings manager].distanceUnitsForSightings
                                angleBaseline:[Settings manager].angleDistanceDeadAhead
                               angleDirection:[Settings manager].angleDistanceAngleDirection];
    }    
}

- (void) selectSettingsWithDistanceUnits:(AGSSRUnit) distanceUnits
                           angleBaseline:(double)angleBaseline
                          angleDirection: (AngleDirection)angleDirection
{
    self.metersTVC.accessoryType = distanceUnits == AGSSRUnitMeter ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.feetTVC.accessoryType = distanceUnits == AGSSRUnitFoot ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.yardsTVC.accessoryType = distanceUnits == AGSSRUnitInternationalYard ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    self.clockwiseTVC.accessoryType = angleDirection == AngleDirectionClockwise ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.counterclockwiseTVC.accessoryType = angleDirection == AngleDirectionCounterClockwise ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    self.deadAheadZeroTVC.accessoryType = abs(angleBaseline - 0.0) < 1.0 ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.deadAhead90TVC.accessoryType = abs(angleBaseline - 90.0) < 1.0 ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.deadAhead180TVC.accessoryType = abs(angleBaseline - 180.0) < 1.0 ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (void) selectAngleDirection:(NSInteger)row
{
    switch (row) {
        case 0:
            if (self.clockwiseTVC.accessoryType == UITableViewCellAccessoryNone)
            {
                [self updateAngleDirection:AngleDirectionClockwise];
                [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] animated:YES];
            }
            self.clockwiseTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.counterclockwiseTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 1:
            if (self.counterclockwiseTVC.accessoryType == UITableViewCellAccessoryNone)
                [self updateAngleDirection:AngleDirectionCounterClockwise];
            self.counterclockwiseTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.clockwiseTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
    }
}

- (void) selectAngleBaseline:(NSInteger)row
{
    switch (row) {
        case 0:
            if (self.deadAheadZeroTVC.accessoryType == UITableViewCellAccessoryNone)
                [self updateAngleBaseline:0.0];
            self.deadAheadZeroTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.deadAhead90TVC.accessoryType = UITableViewCellAccessoryNone;
            self.deadAhead180TVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 1:
            if (self.deadAhead90TVC.accessoryType == UITableViewCellAccessoryNone)
                [self updateAngleBaseline:90.0];
            self.deadAhead90TVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.deadAheadZeroTVC.accessoryType = UITableViewCellAccessoryNone;
            self.deadAhead180TVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 2:
            if (self.deadAhead180TVC.accessoryType == UITableViewCellAccessoryNone)
                [self updateAngleBaseline:180.0];
            self.deadAhead180TVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.deadAhead90TVC.accessoryType = UITableViewCellAccessoryNone;
            self.deadAheadZeroTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
    }
}

- (void) selectDistanceUnits:(NSInteger)row
{
    switch (row) {
        case 0:
            if (self.metersTVC.accessoryType == UITableViewCellAccessoryNone)
                [self updateDistanceUnits:AGSSRUnitMeter];
            self.metersTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.feetTVC.accessoryType = UITableViewCellAccessoryNone;
            self.yardsTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 1:
            if (self.feetTVC.accessoryType == UITableViewCellAccessoryNone)
                [self updateDistanceUnits:AGSSRUnitFoot];
            self.feetTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.metersTVC.accessoryType = UITableViewCellAccessoryNone;
            self.yardsTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 2:
            if (self.yardsTVC.accessoryType == UITableViewCellAccessoryNone)
                [self updateDistanceUnits:AGSSRUnitInternationalYard];
            self.yardsTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.feetTVC.accessoryType = UITableViewCellAccessoryNone;
            self.metersTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
    }
}

- (void) updateAngleDirection: (AngleDirection)angleDirection
{
    if (!self.feature)
        [Settings manager].angleDistanceAngleDirection = angleDirection;
}

- (void) updateAngleBaseline:(double)baseline
{
    if (!self.feature)
        [Settings manager].angleDistanceDeadAhead = baseline;
}

- (void) updateDistanceUnits:(AGSSRUnit)units
{
    if (!self.feature)
        [Settings manager].distanceUnitsForSightings = units;
}

@end
