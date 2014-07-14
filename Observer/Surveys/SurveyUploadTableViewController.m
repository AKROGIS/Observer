//
//  SurveyUploadTableViewController.m
//  Observer
//
//  Created by Regan Sarwas on 5/27/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "SurveyUploadTableViewController.h"
#import "Survey+CsvExport.h"
#import "Survey+ZipExport.h"

#define kAlertViewReplaceSurvey    1
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
            [self shareSurvey];
            break;
        case 2:
            [self mailSurvey];
            break;
        case 3:
            [self mailCsvSmall];
            break;
        case 4:
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
        [[[UIAlertView alloc] initWithTitle:@"Send Error" message:error.localizedDescription delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            if (result == MFMailComposeResultSent) {
                [self.navigationController popViewControllerAnimated:YES];
            }
        }];
    }
}




#pragma mark - Delegate Methods: UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag) {
        case kAlertViewReplaceSurvey: {
            //0 = NO - do not replace; 1=YES - replace existing survey
            if (buttonIndex == 1) {
                NSError *error;
                if ([self.survey exportToDiskWithForce:YES error:&error]) {
                    [self.navigationController popViewControllerAnimated:YES];
                } else {
                    NSString *msg = @"Unable to create export file.";
                    if (error) {
                        msg = [NSString stringWithFormat:@"%@.\n%@", msg, error.localizedDescription];
                    }
                    [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
                }
            }
            break;
        }
        default:
            AKRLog(@"Oh No!, Alert View delegate called for an unknown alert view (tag = %d",alertView.tag);
            break;
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

- (void)shareSurvey
{
    NSError *error = nil;
    if ([self.survey exportToDiskWithForce:NO error:&error]) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Unable to zip up the survey.\n%@", error.localizedDescription];
            [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        } else {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:@"Do you want to replace the existing export file?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
            alertView.tag = kAlertViewReplaceSurvey;
            [alertView show];
        }
    }
}

- (void)mailSurvey
{
    if (![MFMailComposeViewController canSendMail]) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"This device is not configured to send mail" delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        return;
    }
    NSError *error = nil;
    NSData *attachmentData = [self.survey exportToNSDataError:&error];
    if (!attachmentData) {
        NSString *msg = @"Unable to create an email-able export of the survey.";
        if (error) {
            msg = [NSString stringWithFormat:@"%@.\n%@", msg, error.localizedDescription];
        }
        [[[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
    } else {
        MFMailComposeViewController *mailVC = [[MFMailComposeViewController alloc] init];
        NSString *subject = [NSString stringWithFormat:@"Park Observer Survey Data"];
        NSString *body = [NSString stringWithFormat:@"Survey data collected for %@.",self.survey.title];
        [mailVC setSubject:subject];
        [mailVC setMessageBody:body isHTML:NO];
        NSString *attachmentName = [self.survey getExportFileName];
        [mailVC addAttachmentData:attachmentData mimeType:@"application/octet-stream" fileName:attachmentName];
        mailVC.mailComposeDelegate = self;
        [self presentViewController:mailVC animated:YES completion:nil];
    }
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
