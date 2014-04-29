//
//  GpsPointTableViewController.m
//  Observer
//
//  Created by Regan Sarwas on 4/28/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "GpsPointTableViewController.h"
#import "GpsPoint.h"
#import "AKRFormatter.h"


@interface GpsPointTableViewController ()

@end

@implementation GpsPointTableViewController

- (void) setGpsPoint:(GpsPoint *)gpsPoint
{
    _gpsPoint = gpsPoint;
    [self.tableView reloadData];
}

- (void) setAdhocLocation:(AdhocLocation *)adhocLocation
{
    _adhocLocation = adhocLocation;
    [self.tableView reloadData];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return (self.gpsPoint) ? 7 : 0;
        case 1:
            return self.adhocLocation ? 3 : 0;
        default:
            break;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            return self.gpsPoint ? @"Gps Location" : nil;
        case 1:
            return self.adhocLocation ? (self.gpsPoint ? @"Original Map Location" : @"Map Location") : nil;
        default:
            break;
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GpsPointCell" forIndexPath:indexPath];
    
    switch (indexPath.section) {
        case 0:
        {
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"Time";
                    cell.detailTextLabel.text = [AKRFormatter longDateFromString:self.gpsPoint.timestamp];
                    break;
                case 1:
                    cell.textLabel.text = @"Latitude";
                    cell.detailTextLabel.text = self.gpsPoint.horizontalAccuracy < 0
                    ? @"Unknown"
                    : [NSString stringWithFormat:@"%g°",self.gpsPoint.latitude] ;
                    break;
                case 2:
                    cell.textLabel.text = @"Longitude";
                    cell.detailTextLabel.text = self.gpsPoint.horizontalAccuracy < 0
                    ? @"Unknown"
                    : [NSString stringWithFormat:@"%g°",self.gpsPoint.longitude] ;
                    break;
                case 3:
                    cell.textLabel.text = @"Error";
                    cell.detailTextLabel.text = self.gpsPoint.horizontalAccuracy < 0
                    ? @"Unknown"
                    : [NSString stringWithFormat:@"%g meter radius",self.gpsPoint.horizontalAccuracy] ;
                    break;
                case 4:
                    cell.textLabel.text = @"Altitude";
                    cell.detailTextLabel.text = self.gpsPoint.verticalAccuracy < 0
                    ? @"Unknown"
                    : [NSString stringWithFormat:@"%g\u00B1%g meters ",self.gpsPoint.altitude,self.gpsPoint.verticalAccuracy] ;
                    break;
                case 5:
                    cell.textLabel.text = @"Speed";
                    cell.detailTextLabel.text = self.gpsPoint.speed < 0
                    ? @"Unknown"
                    : [NSString stringWithFormat:@"%g meters/second",self.gpsPoint.speed];
                    break;
                case 6:
                    cell.textLabel.text = @"Course ";
                    cell.detailTextLabel.text = self.gpsPoint.course < 0
                    ? @"Unknown"
                    : [NSString stringWithFormat:@"%g° (N = 0°, E=90°)",self.gpsPoint.course];
                    break;
                default:
                    break;
            }
            break;
        }
        case 1:
        {
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"Time";
                    cell.detailTextLabel.text = [AKRFormatter longDateFromString:self.adhocLocation.timestamp];
                    break;
                case 1:
                    cell.textLabel.text = @"Latitude";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%g°",self.adhocLocation.latitude];
                    break;
                case 2:
                    cell.textLabel.text = @"Longitude";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%g°",self.adhocLocation.longitude];
                    break;
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }

    return cell;
}

@end
