//
//  ObserverAppDelegate.m
//  Observer
//
//  Created by Regan Sarwas on 7/2/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "ObserverAppDelegate.h"
#import "ObserverMapViewController.h"
#import <CoreData/CoreData.h>
#import "ProtocolManagedDocument.h"

#define FILE_NAME @"res_core_data"


@interface ObserverAppDelegate()

@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) UIManagedDocument *document;
@property (weak, nonatomic) ObserverMapViewController *masterVC;
@property (nonatomic) BOOL busy;

@end

@implementation ObserverAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [self openModel];
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self saveModel];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self closeModel];
}



//lazy instantiation

- (ObserverMapViewController *)masterVC
{
    if (!_masterVC)
    {
        UINavigationController *rvc = (UINavigationController *)self.window.rootViewController;
        _masterVC = (ObserverMapViewController *)rvc.viewControllers[0];
    }
    return _masterVC;
}

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
    if ([self.masterVC respondsToSelector:@selector(setBusy:)]) {
        [self.masterVC setBusy:busy];
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
            self.masterVC.context = self.document.managedObjectContext;
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
