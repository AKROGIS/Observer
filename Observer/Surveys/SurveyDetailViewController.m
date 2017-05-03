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
#import "AKRLog.h"

@interface SurveyDetailViewController ()
{
    NSUInteger _observationCount;
    NSUInteger _segmentCount;
    NSUInteger _gpsCount;
    NSUInteger _gpsCountSinceSync;
    NSDate *_firstGpsDate;
    NSDate *_lastGpsDate;
}
@end

@implementation SurveyDetailViewController

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"Show Protocol Detail"]) {
        ((ProtocolDetailViewController *)segue.destinationViewController).protocol = self.survey.protocol;
        segue.destinationViewController.preferredContentSize = self.preferredContentSize;
    }
//    if ([[segue identifier] isEqualToString:@"Show GpsPoint Detail"]) {
//        ((GpsPointTableViewController *)segue.destinationViewController).gpsPoint = self.???;
//        [[segue destinationViewController] setPreferredContentSize:self.preferredContentSize];
//    }
}

- (void)setSurvey:(Survey *)survey
{
    _survey = survey;
    if (survey.isReady)
    {
        //this survey was opened by someone else, don't mess with it;
        [self cacheSurveyProperties];
        [self.tableView reloadData];
        return;
    }
    //Open the survey document
    //AKRLog(@"Opening survey %@ for Details VC", survey.title);
    [survey openDocumentWithCompletionHandler:^(BOOL success) {
        if (!success) {
            AKRLog(@"Error - Failed to open survey %@ in Details VC", survey.title);
            return;
        }
        //Get the survey properties
        [self cacheSurveyProperties];
        //Update the table
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
}

- (void)cacheSurveyProperties
{
    _observationCount = self.survey.observationCount;
    _segmentCount = self.survey.segmentCount;
    _gpsCount = self.survey.gpsCount;
    _gpsCountSinceSync = self.survey.gpsCountSinceSync;
    _firstGpsDate = self.survey.firstGpsDate;
    _lastGpsDate = self.survey.lastGpsDate;
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
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)_observationCount];
                break;
            case 1:
                cell.textLabel.text = @"Tracks";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)_segmentCount];
                break;
            case 2:
                cell.textLabel.text = @"Gps Points";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)_gpsCount];
                break;
            case 3:
                cell.textLabel.text = @"..Since Sync";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu",(unsigned long)_gpsCountSinceSync];
                break;
            case 4:
                cell.textLabel.text = @"First Point";
                cell.detailTextLabel.text = [AKRFormatter descriptiveStringFromDate:_firstGpsDate];
//                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 5:
                cell.textLabel.text = @"last Point";
                cell.detailTextLabel.text = [AKRFormatter descriptiveStringFromDate:_lastGpsDate];
//                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            default:
                break;
        }
    }
    return cell;
}

@end
