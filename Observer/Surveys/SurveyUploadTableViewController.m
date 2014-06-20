//
//  SurveyUploadTableViewController.m
//  Observer
//
//  Created by Regan Sarwas on 5/27/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "SurveyUploadTableViewController.h"
#import "Survey+CsvExport.h"

#define kOKButtonText              NSLocalizedString(@"OK", @"OK button text")

@interface SurveyUploadTableViewController ()

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *syncActivityIndicator;
@end

@implementation SurveyUploadTableViewController

- (void)setSurvey:(Survey *)survey
{
    _survey = survey;
    self.title = survey.title;
    self.navigationController.title = survey.title;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.row) {
        case 0:
            [self syncSurvey];
            break;
        case 1:
            [self mailSurvey];
            break;
        case 2:
            [self mailCsvSmall];
            break;
        case 3:
            [self mailCsvLarge];
            break;
        default:
            break;
    }
}





#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    if (error) {
        [[[UIAlertView alloc] initWithTitle:@"Send Error" message:error.localizedDescription delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil] show];
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            if (result == MFMailComposeResultSent) {
                [self.navigationController popViewControllerAnimated:YES];
            }
        }];
    }
}





#pragma mark - private methods

- (void)syncSurvey
{
    [self.syncActivityIndicator startAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self.survey syncWithCompletionHandler:^(NSError *error) {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Sync Failed" message:error.localizedDescription delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        }
        [self.syncActivityIndicator stopAnimating];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }];
}

- (void)mailSurvey
{
    [[[UIAlertView alloc] initWithTitle:nil message:@"Feature not implemented yet." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
    return;
}

- (void)mailCsvSmall
{
    [self mailCsvIncludeGps:NO];
}

- (void)mailCsvLarge
{
    [self mailCsvIncludeGps:YES];
}

- (void)mailCsvIncludeGps:(BOOL)includeGps
{
    if (![MFMailComposeViewController canSendMail]) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"This device is not configured to send mail" delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        return;
    }
    [self.survey openDocumentWithCompletionHandler:^(BOOL success) {
        //do any other background work;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                MFMailComposeViewController *mailVC = [[MFMailComposeViewController alloc] init];
                NSString *subject = [NSString stringWithFormat:@"Park Observer Data"];
                NSString *body = [NSString stringWithFormat:@"CSV data collected for %@.",self.survey.title];
                [mailVC setSubject:subject];
                [mailVC setMessageBody:body isHTML:NO];
                NSDictionary *features = [self.survey csvForFeaturesSince:nil];
                for (NSString *featureName in features){
                    NSData *data = [features[featureName] dataUsingEncoding:NSUTF8StringEncoding];
                    NSString *fileName = [NSString stringWithFormat:@"%@.csv",featureName];
                    [mailVC addAttachmentData:data mimeType:@"text/csv" fileName:fileName];
                }
                NSData *data = [[self.survey csvForTrackLogsSince:nil] dataUsingEncoding:NSUTF8StringEncoding];
                [mailVC addAttachmentData:data mimeType:@"text/csv" fileName:@"track_log_summary.csv"];
                if (includeGps) {
                    data = [[self.survey csvForGpsPointsSince:nil] dataUsingEncoding:NSUTF8StringEncoding];
                    [mailVC addAttachmentData:data mimeType:@"text/csv" fileName:@"all_gps_points.csv"];
                }
                mailVC.mailComposeDelegate = self;
                [self presentViewController:mailVC animated:YES completion:nil];
                [self.survey closeDocumentWithCompletionHandler:nil];
            } else {
                [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to open the survey." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
            }
        });
    }];
}

@end