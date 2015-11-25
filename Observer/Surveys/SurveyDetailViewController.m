//
//  SurveyDetailViewController.m
//  Observer
//
//  Created by Regan Sarwas on 11/13/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyDetailViewController.h"
#import "NSIndexPath+unsignedAccessors.h"
#import "SProtocol.h"
#import "AKRFormatter.h"
#import "ProtocolDetailViewController.h"
#import "GpsPointTableViewController.h"

@implementation SurveyDetailViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Show Protocol Detail"]) {
        ((ProtocolDetailViewController *)segue.destinationViewController).protocol = self.survey.protocol;
        [[segue destinationViewController] setPreferredContentSize:self.preferredContentSize];
    }
//    if ([[segue identifier] isEqualToString:@"Show GpsPoint Detail"]) {
//        ((GpsPointTableViewController *)segue.destinationViewController).gpsPoint = self.???;
//        [[segue destinationViewController] setPreferredContentSize:self.preferredContentSize];
//    }
}

- (void) dealloc
{
    self.survey = nil;
}

- (void)setSurvey:(Survey *)survey
{
    if (_survey) {
        [_survey closeDocumentWithCompletionHandler:nil];
    }
    _survey = nil;
    [survey openDocumentWithCompletionHandler:^(BOOL success) {
        if (success) {
            self->_survey = survey;
            [self.tableView reloadData];
        }
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.survey ? 7 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.survey ? self.survey.title : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    if (indexPath.row == 6) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"SurveyDetailProtocolDetailsCell" forIndexPath:indexPath];
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"SurveyDetailCell" forIndexPath:indexPath];
        //cell.accessoryType = UITableViewCellAccessoryNone;
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Observations";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)self.survey.observationCount];
                break;
            case 1:
                cell.textLabel.text = @"Tracks";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)self.survey.segmentCount];
                break;
            case 2:
                cell.textLabel.text = @"Gps Points";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)self.survey.gpsCount];
                break;
            case 3:
                cell.textLabel.text = @"..Since Sync";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)self.survey.gpsCountSinceSync];
                break;
            case 4:
                cell.textLabel.text = @"First Point";
                cell.detailTextLabel.text = [AKRFormatter descriptiveStringFromDate:self.survey.firstGpsDate];
//                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 5:
                cell.textLabel.text = @"last Point";
                cell.detailTextLabel.text = [AKRFormatter descriptiveStringFromDate:self.survey.lastGpsDate];
//                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            default:
                break;
        }
    }
    return cell;
}

@end
