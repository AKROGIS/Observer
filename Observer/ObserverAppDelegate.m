//
//  ObserverAppDelegate.m
//  Observer
//
//  Created by Regan Sarwas on 7/2/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "ObserverAppDelegate.h"
#import "ObserverMapViewController.h"
#import "Settings.h"
#import "SurveyCollection.h"
#import "MapCollection.h"
#import "ProtocolCollection.h"

#define kAlertViewNewProtocol      1


@interface ObserverAppDelegate()

@property (nonatomic,strong) ObserverMapViewController *observerMapViewController;

@end

@implementation ObserverAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    Map *savedMap = [[Map alloc] initWithLocalTileCache:[[Settings manager] selectedMap]];
    if (savedMap.isValid) {
        self.observerMapViewController.map = savedMap;
    }
    Survey *savedSurvey = [[Survey alloc] initWithURL:[[Settings manager] selectedSurvey]];
    if (savedSurvey.isValid) {
        self.observerMapViewController.survey = savedSurvey;
    }
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
    AKRLog(@"Entering Background.  Synchronizing User Defaults");
    [[NSUserDefaults standardUserDefaults] synchronize];
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
    AKRLog(@"Terminating App.  Synchronizing User Defaults");
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // Called when this app is asked to open a resourse (at url) by a different app
    // The user will expect a short delay to open the file
    AKRLog(@"%@ asked me to open %@", sourceApplication, url);
    if ([SurveyCollection collectsURL:url]) {
        Survey *newSurvey = [[SurveyCollection sharedCollection] openURL:url];
        self.observerMapViewController.survey = newSurvey;
        return YES;
    }
    if ([MapCollection collectsURL:url]) {
        //FIXME: this URL may contain a map we already have, what should we do?
        Map *newMap = [[MapCollection sharedCollection] openURL:url];
        self.observerMapViewController.map = newMap;
        return YES;
    }
    if ([ProtocolCollection collectsURL:url]) {
        SProtocol *newProtocol = [[ProtocolCollection sharedCollection] openURL:url];
        [self.observerMapViewController updateSelectProtocolViewControllerWithNewProtocol:newProtocol];
        return YES;
    }
    return NO;
}

- (ObserverMapViewController *)observerMapViewController
{
    UIViewController *vc;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        vc = self.window.rootViewController;
    } else {
        UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
        vc = [nav.viewControllers  firstObject];;
    }
    if ([vc isKindOfClass:[ObserverMapViewController class]]) {
        return (ObserverMapViewController *)vc;
    }
    return nil;
}


//#pragma mark - Delegate Methods: UIAlertViewDelegate
//
//- (void)AddSurvey
//{
//    ProtocolCollection *protocols = [ProtocolCollection sharedCollection];
//    [protocols openWithCompletionHandler:^(BOOL openSuccess) {
//        SProtocol *protocol = [protocols openURL:url];
//        dispatch_async(dispatch_get_main_queue(), ^{
//            if (openSuccess && protocol.isValid) {
//                self.protocolForSurveyCreation = protocol;
//                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"New Protocol" message:@"Do you want to open a new survey file with this protocol?" delegate:self cancelButtonTitle:@"Maybe Later" otherButtonTitles:@"Yes", nil];
//                alertView.tag = kAlertViewNewProtocol;
//                [alertView show];
//                // handle response in UIAlertView delegate method
//            } else {
//                [[[UIAlertView alloc] initWithTitle:@"Protocol Problem" message:@"Can't open/read the protocol file" delegate:nil cancelButtonTitle:kOKButtonText otherButtonTitles:nil] show];
//            }
//        });
//    }];
//}
//
//- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
//{
//    switch (alertView.tag) {
//        case kAlertViewNewProtocol: {
//            if (buttonIndex == 1) {  //Yes to create/open a new survey
//                if (self.surveysPopoverController) {
//                    UIViewController *vc = self.surveysPopoverController.contentViewController;
//                    if ([vc isKindOfClass:[UINavigationController class]]) {
//                        vc = ((UINavigationController *)vc).visibleViewController;
//                    }
//                    if ([vc isKindOfClass:[SurveySelectViewController class]]) {
//                        //This method will put up its own alert if it cannot create the survey
//                        [(SurveySelectViewController *)vc newSurveyWithProtocol:self.protocolForSurveyCreation];
//                        //since the survey select view is up, let the user decide which survey they want to select
//                        return;
//                    }
//                }
//                //TODO: The survey VC's tableview is not refreshed if the protocol VC is displayed
//                NSUInteger indexOfNewSurvey = [self.surveys newSurveyWithProtocol:self.protocolForSurveyCreation];
//                if (indexOfNewSurvey != NSNotFound) {
//                    [self closeSurvey:self.survey withConcurrentOpen:YES];
//                    [self.surveys setSelectedSurvey:indexOfNewSurvey];
//                    [self openSurvey];
//                } else {
//                    [[[UIAlertView alloc] initWithTitle:@"Survey Problem" message:@"Can't create a survey with this protocol" delegate:nil cancelButtonTitle:kOKButtonText otherButtonTitles:nil] show];
//                }
//            }
//            break;
//        }
//        default:
//            AKRLog(@"Oh No!, Alert View delegate called for an unknown alert view (tag = %d",alertView.tag);
//            break;
//    }
//}

@end
