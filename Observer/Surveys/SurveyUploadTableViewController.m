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
#import "AKRLog.h"

#define kOKButtonText              NSLocalizedString(@"OK", @"OK button text")

@interface SurveyUploadTableViewController ()
{
    BOOL _mineToClose;
}
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *syncActivityIndicator;
@end

@implementation SurveyUploadTableViewController

-(void)dealloc
{
    //FIXME: #177 This VC is owned by a nav controller, which might not dealloc this VC until after the same survey is passed to and opened by the mainVC.  This is probably a race condition that need to be investigated
    //FIXME: #177 Some export tasks happen on a background thread which may not be complete when this VC is deallocated.  This is probably bad and should be investigated.
    if (_mineToClose) {
        NSString *title = self.survey.title;
        [self.survey closeDocumentWithCompletionHandler:^(BOOL success) {
            if (!success) {
                AKRLog(@"Error - Failed to close survey %@ in Export VC", title);
                // Continue anyway...
            }
            AKRLog(@"Closed survey %@ in Export VC", title);
        }];
    }
}

- (void)setSurvey:(Survey *)survey
{
    if (survey.isReady) {
        _survey = survey;
        self.title = survey.title;
        self.navigationController.title = survey.title;
        _mineToClose = NO;
    } else {
        AKRLog(@"Opening survey %@ for Export VC", survey.title);
        [survey openDocumentWithCompletionHandler:^(BOOL success) {
            if (success) {
                self->_survey = survey;
                self.title = survey.title;
                self.navigationController.title = survey.title;
                self->_mineToClose = YES;
            } else {
                AKRLog(@"Error - Failed to open survey %@ in Export VC", survey.title);
                self->_mineToClose = NO;
            }
        }];
    }
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
        [self alert:@"Send Error" message:error.localizedDescription];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.syncActivityIndicator stopAnimating];
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            if (error) {
                [self alert:@"Sync Failed" message:error.localizedDescription];
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
        });
    }];
}

- (void)shareSurvey
{
    [self.syncActivityIndicator startAnimating];
    NSError *error = nil;
    BOOL exportSuccess = [self.survey exportToDiskWithForce:NO error:&error];
    [self.syncActivityIndicator stopAnimating];
    if (exportSuccess) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Unable to zip up the survey.\n%@", error.localizedDescription];
            [self alert:nil message:msg];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                           message:@"Do you want to replace the existing export file?"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *abortAction = [UIAlertAction actionWithTitle:@"No"
                                                                 style:UIAlertActionStyleCancel
                                                               handler:nil];
            UIAlertAction *replaceAction = [UIAlertAction actionWithTitle:@"Yes"
                                                                   style:UIAlertActionStyleDestructive
                                                                 handler:^(UIAlertAction * action){
                                                                     [self replaceExportedSurvey];
                                                                 }];
            [alert addAction:abortAction];
            [alert addAction:replaceAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

-(void)replaceExportedSurvey
{
    NSError *error;
    if ([self.survey exportToDiskWithForce:YES error:&error]) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        NSString *msg = @"Unable to create export file.";
        if (error) {
            msg = [NSString stringWithFormat:@"%@\n%@", msg, error.localizedDescription];
        }
        [self alert:nil message:msg];
    }

}

- (void)mailSurvey
{
    if (![MFMailComposeViewController canSendMail]) {
        [self alert:nil message:@"This device is not configured to send mail"];
        return;
    }

    [self.syncActivityIndicator startAnimating];
    NSError *error = nil;
    NSData *attachmentData = [self.survey exportToNSDataError:&error];
    [self.syncActivityIndicator stopAnimating];
    if (!attachmentData) {
        NSString *msg = @"Unable to create an email-able export of the survey.";
        if (error) {
            msg = [NSString stringWithFormat:@"%@\n%@", msg, error.localizedDescription];
        }
        [self alert:nil message:msg];
    } else {
        MFMailComposeViewController *mailVC = [[MFMailComposeViewController alloc] init];
        NSString *subject = [NSString stringWithFormat:@"Park Observer Survey Data"];
        NSString *body = [NSString stringWithFormat:@"Survey data collected for %@.",self.survey.title];
        [mailVC setSubject:subject];
        [mailVC setMessageBody:body isHTML:NO];
        NSString *attachmentName = self.survey.exportFileName;
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
        [self alert:nil message:@"This device is not configured to send mail"];
        return;
    }
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
    NSString *csvName = @"TrackLogs.csv"; //TODO: #129 get this from the survey protocol
    [mailVC addAttachmentData:data mimeType:@"text/csv" fileName:csvName];
    if (includeGps) {
        data = [[self.survey csvForGpsPointsSince:nil] dataUsingEncoding:NSUTF8StringEncoding];
        csvName = @"GpsPoints.csv"; //TODO: #129 get this from the survey protocol
        [mailVC addAttachmentData:data mimeType:@"text/csv" fileName:csvName];
    }
    mailVC.mailComposeDelegate = self;
    [self presentViewController:mailVC animated:YES completion:nil];
}

- (void) alert:(NSString *)title message:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:kOKButtonText style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
