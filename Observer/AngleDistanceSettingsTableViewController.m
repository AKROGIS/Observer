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

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self settingsDidChange:nil];
}

- (void) viewDidAppear:(BOOL)animated {
    NSLog(@"View Did Appear");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];
    [super viewDidAppear:animated];
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

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.protocol && self.protocol.definesAngleDistanceMeasures)
        return;  //deny ability to change settings

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

#pragma mark - private Methods

- (void) settingsDidChange:(NSNotification *)notification
{
    NSLog(@"settingsDidChange:%@", notification);
    
    if (self.protocol && self.protocol.definesAngleDistanceMeasures)
    {
        [self selectSettingsWithDistanceUnits:self.protocol.distanceUnits
                                angleBaseline:self.protocol.angleBaseline
                               angleDirection:self.protocol.angleDirection];
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
                [Settings manager].angleDistanceAngleDirection = AngleDirectionClockwise;
                [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] animated:YES];
            }
            self.clockwiseTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.counterclockwiseTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 1:
            if (self.counterclockwiseTVC.accessoryType == UITableViewCellAccessoryNone)
                [Settings manager].angleDistanceAngleDirection = AngleDirectionCounterClockwise;
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
                [Settings manager].angleDistanceDeadAhead = 0.0;
            self.deadAheadZeroTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.deadAhead90TVC.accessoryType = UITableViewCellAccessoryNone;
            self.deadAhead180TVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 1:
            if (self.deadAhead90TVC.accessoryType == UITableViewCellAccessoryNone)
                [Settings manager].angleDistanceDeadAhead = 90.0;
            self.deadAhead90TVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.deadAheadZeroTVC.accessoryType = UITableViewCellAccessoryNone;
            self.deadAhead180TVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 2:
            if (self.deadAhead180TVC.accessoryType == UITableViewCellAccessoryNone)
                [Settings manager].angleDistanceDeadAhead = 180.0;
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
                [Settings manager].distanceUnitsForSightings = AGSSRUnitMeter;
            self.metersTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.feetTVC.accessoryType = UITableViewCellAccessoryNone;
            self.yardsTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 1:
            if (self.feetTVC.accessoryType == UITableViewCellAccessoryNone)
                [Settings manager].distanceUnitsForSightings = AGSSRUnitFoot;
            self.feetTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.metersTVC.accessoryType = UITableViewCellAccessoryNone;
            self.yardsTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
        case 2:
            if (self.yardsTVC.accessoryType == UITableViewCellAccessoryNone)
                [Settings manager].distanceUnitsForSightings = AGSSRUnitInternationalYard;
            self.yardsTVC.accessoryType = UITableViewCellAccessoryCheckmark;
            self.feetTVC.accessoryType = UITableViewCellAccessoryNone;
            self.metersTVC.accessoryType = UITableViewCellAccessoryNone;
            break;
    }
}


@end
