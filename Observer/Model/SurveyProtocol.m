//
//  SurveyProtocol.m
//  Observer
//
//  Created by Regan Sarwas on 7/29/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyProtocol.h"
#import <CoreData/CoreData.h>
#import "ProtocolManagedDocument.h"
#import "ObserverMapViewController.h" // for delegate methods (FIXME define protocol)

#define FILE_NAME @"res_protocol_name_version"

@interface SurveyProtocol ()

@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) UIManagedDocument *document;
@property (nonatomic) BOOL busy;

@end

@implementation SurveyProtocol




//lazy instantiation

- (NSURL *)url
{
    if (!_url)
    {
        NSURL *documentsDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
        _url = [documentsDirectory URLByAppendingPathComponent:FILE_NAME];
    }
    return _url;
}

- (void) setBusy:(BOOL)busy
{
    _busy = busy;
    if ([self.delegate respondsToSelector:@selector(setBusy2:)]) {
        [self.delegate setBusy:busy];
    }
}


#pragma mark - Private Methods

- (void) openModel
{
    // let the user know we are working
    self.busy = YES;
    
    //Async Loader, wait for documentIsOpen, documentOpenFailed, or documentCreateFailed
    [self openDocument];
}

- (void) saveModel
{
    //this will call a background thread to do the actual work, so it does not block
    [self.document.managedObjectContext save:nil];
}

- (void) closeModel
{
    // let the user know we are working
    self.busy = YES;
    
    //Async Closer, wait for documentIsClosed, documentSaveFailed, or documentCloseFailed
    [self closeDocument];
}

//Async Loader, wait for documentIsOpen, documentOpenFailed, or documentCreateFailed
- (void) openDocument
{
    self.document = [[ProtocolManagedDocument alloc] initWithFileURL:self.url];
    BOOL documentExists = [[NSFileManager defaultManager] fileExistsAtPath:[self.url path]];
    if (documentExists) {
        [self.document openWithCompletionHandler:^ (BOOL success) {
            if (success)
                [self documentIsOpen];
            else
                [self documentOpenFailed];
        }];
    }
    else
    {
        [self.document saveToURL:self.url forSaveOperation:UIDocumentSaveForCreating completionHandler:^ (BOOL success) {
            if (success)
                [self documentIsOpen];
            else
                [self documentCreateFailed];
        }];
    }
}

//Async Closer, wait for documentIsClosed, documentSaveFailed, or documentCloseFailed
- (void) closeDocument
{
    if (self.document) {
        [self.document saveToURL:self.url forSaveOperation:UIDocumentSaveForOverwriting completionHandler:^ (BOOL success) {
            if (success)
                [self.document closeWithCompletionHandler:^(BOOL success) {
                    if (success)
                        [self documentIsClosed];
                    else
                        [self documentCloseFailed];
                }];
            else
                [self documentSaveFailed];
        }];
    }
}

- (void) documentIsOpen
{
    NSString *error;
    switch (self.document.documentState) {
        case UIDocumentStateNormal:
            if ([self.delegate respondsToSelector:@selector(setContext:)]) {
                [self.delegate setContext:self.document.managedObjectContext];
            }
            error = nil;
            break;
        case UIDocumentStateClosed:
            error = @"Document is closed";
            break;
        case UIDocumentStateEditingDisabled:
            error = @"Document editing is disabled";
            break;
        case UIDocumentStateInConflict:
            error = @"Document is in conflict";
            break;
        case UIDocumentStateSavingError:
            error = @"Document has an error saving state";
            break;
        default:
            error = @"Document has an unexpected state";
    }
    self.busy = NO;
    if (error)
        [self fatalAbort:error];
}

- (void) documentIsClosed
{
    self.busy = NO;
}

- (void) documentOpenFailed
{
    self.busy = NO;
    [self fatalAbort:[NSString stringWithFormat:@"Document open failed for url %@", self.url]];
}

- (void) documentCreateFailed
{
    self.busy = NO;
    [self fatalAbort:[NSString stringWithFormat:@"Document creation failed for url %@", self.url]];
}

- (void) documentSaveFailed
{
    self.busy = NO;
    [self fatalAbort:[NSString stringWithFormat:@"Document save failed for url %@", self.url]];
}

- (void) documentCloseFailed
{
    self.busy = NO;
    [self fatalAbort:[NSString stringWithFormat:@"Document close failed for url %@", self.url]];
}

- (void) fatalAbort:(NSString *)message
{
    [[[UIAlertView alloc] initWithTitle:@"Fatal Error" message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
    //FIXME - provide better error handling
    // give user information about how to report the error
    // email log to developer
    // close the app
}

@end
