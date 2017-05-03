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
#import "NSURL+unique.h"
#import "MapCollection.h"
#import "ProtocolCollection.h"
#import "AKRLog.h"
#import <Crashlytics/Crashlytics.h>
#import <ArcGIS/ArcGIS.h>

#define kOKButtonText              NSLocalizedString(@"OK", @"OK button text")


@interface ObserverAppDelegate()

@property (strong, nonatomic, readwrite) SurveyCollection *surveys;
@property (nonatomic,strong) ObserverMapViewController *observerMapViewController;

@end

@implementation ObserverAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //Activate the Crash reporting system
    [Crashlytics startWithAPIKey:@"48e51797d0250122096db58d369feab2cac2da33"];

    // Activate a Basic ArcGIS License - Set the client ID
    NSError *error;
    NSString* clientID = @"jgGIvIn2VCK8q3FX";
    [AGSRuntimeEnvironment setClientID:clientID error:&error];
    if(error){
        // We had a problem using our client ID - Map will display "For developer use only"
        NSLog(@"Error using client ID : %@",error.localizedDescription);
    }
    AKRLog(@"** Start loading Map");
    Map *savedMap = [[Map alloc] initWithCachedPropertiesName:[Settings manager].activeMapPropertiesName];
    if (savedMap) {
        self.observerMapViewController.map = savedMap;
    }
    AKRLog(@"** Start loading Surveys");
    self.surveys = [SurveyCollection sharedCollection];
    [self.surveys openWithCompletionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.observerMapViewController.surveys = self.surveys;
            AKRLog(@"** Surveys Loaded %lu", (unsigned long)self.surveys.numberOfSurveys);
            Survey *savedSurvey = [self.surveys surveyWithURL:[Survey urlFromCachedName:[Settings manager].activeSurveyName]];
            AKRLog(@"** Survey found %@ (%d)", savedSurvey, savedSurvey.isValid);
            if (savedSurvey.isValid) {
                self.observerMapViewController.survey = savedSurvey;
                AKRLog(@"** Surveys Loaded");
            }
        });
    }];
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
    AKRLog(@"Entering Background.  Synchronizing User Defaults, dismissing popovers/alerts");
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.observerMapViewController dismissViewControllerAnimated:YES completion:nil];
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

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    // Asks the delegate to open a resource specified by a URL, and provides a dictionary of launch options.
    // The URL resource to open. This resource can be a network resource or a file. For information about the Apple-registered URL schemes, see Apple URL Scheme Reference.
    // This will only be called for URLs that match the UTIs that your app registers to receive.
    // If this is a file provided by email or Safari, The file is moved to a unique name in the App's Documents folder before this method is called.
    AKRLog(@"Asked to open %@", url);
    return [self open:url];
}




#pragma mark - Private properties/methods

- (ObserverMapViewController *)observerMapViewController
{

    if (!_observerMapViewController) {
        id rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
        if([rootViewController isKindOfClass:[UINavigationController class]])
        {
            rootViewController = ((UINavigationController *)rootViewController).viewControllers.firstObject;
        }
        if([rootViewController isKindOfClass:[UITabBarController class]])
        {
            rootViewController = ((UITabBarController *)rootViewController).selectedViewController;
        }
        // In a more generic function we would want to check UISplitViewController and other custom Container ViewControllers
        // Fail early if my main (non-container VC) is not what I expect
        _observerMapViewController = (ObserverMapViewController *)rootViewController;
    }
    return _observerMapViewController;
}

- (BOOL)open:(NSURL *)url
{
    //The url may contain a resource (e.g. a tile package) that we already have in the documents directory.
    //  This is unlikely, and while we could try to determine equality and return the existing resource if
    //  the new resource is a duplicate, there is a chance for false positives, which would frustrate the user.
    //  It is better to just do what the user asked - They can then determine equality and remove the duplicate.

    NSString *name = url.lastPathComponent;
    if (name == nil) {
        return NO;
    }
    NSURL *documentsDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *newUrl = [documentsDirectory URLByAppendingPathComponent:name];
    newUrl = newUrl.URLByUniquingPath;
    NSError *error = nil;
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:newUrl error:&error];
    if (error) {
        [self alert:url.lastPathComponent message:@"Unable to open file."];
        return NO;
    }

    if ([SurveyCollection collectsURL:newUrl]) {
        Survey *newSurvey = [[Survey alloc] initWithURL:newUrl];
        [[NSFileManager defaultManager] removeItemAtURL:newUrl error:nil];
        if (newSurvey.valid) {
            self.observerMapViewController.survey = newSurvey;
            return YES;
        } else {
            [self alert:url.lastPathComponent message:@"Not a Valid Survey."];
            return NO;
        }
    }
    if ([MapCollection collectsURL:url]) {
        //TODO: #92 Put up a modal, asking for details on the tile cache, i.e. name, author, date, description
        //       explain the importance of the attributes in identifying the map for reference for non-gps points
        //       maybe get the defaults from the esriinfo.xml file in the zipped tpk
        //       Map *newMap = [[Map alloc] initWithTileCacheURL:newUrl name:name author:author date:date description:description;
        Map *newMap = [[Map alloc] initWithTileCacheURL:newUrl];
        if (newMap) {
            self.observerMapViewController.map = newMap;
            return YES;
        } else {
            [self alert:url.lastPathComponent message:@"Not a Valid Map."];
            return NO;
        }
    }
    if ([ProtocolCollection collectsURL:url]) {
        SProtocol *newProtocol = [[SProtocol alloc] initWithURL:newUrl];
        if (newProtocol.valid) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"New Protocol"
                                                                           message:@"Do you want to open a new survey file with this protocol?"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *waitAction = [UIAlertAction actionWithTitle:@"Maybe Later"
                                                                 style:UIAlertActionStyleCancel
                                                               handler:nil];
            UIAlertAction *openAction = [UIAlertAction actionWithTitle:@"Yes"
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action){
                                                                   Survey *newSurvey = [[Survey alloc] initWithProtocol:newProtocol];
                                                                   if (newSurvey.valid) {
                                                                       self.observerMapViewController.survey = newSurvey;
                                                                   } else {
                                                                       [self alert:nil message:@"Unable to create new survey."];
                                                                   }
                                                               }];
            [alert addAction:waitAction];
            [alert addAction:openAction];
            [self presentAlert:alert];
            return YES;
        } else {
            [self alert:url.lastPathComponent message:@"Not a Valid Survey Protocol"];
            return NO;
        }
    }
    AKRLog(@"Oh No!, Unhandled file type %@", url.lastPathComponent);
    return NO;
}




#pragma mark - Alert Helpers

- (void) alert:(NSString *)title message:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:kOKButtonText style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentAlert:alert];
}

- (void)presentAlert:(UIAlertController *)alert
{
    // self is not a UIVeiwController, so we need to find the root view controller and ask it to display the Alert
    [self.observerMapViewController presentViewController:alert animated:YES completion:nil];
}

@end
