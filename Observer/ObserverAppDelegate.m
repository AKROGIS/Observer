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
#import "SurveyCollection.h"
#import "MapCollection.h"
#import "ProtocolCollection.h"
#import <Crashlytics/Crashlytics.h>
#import <ArcGIS/ArcGIS.h>

#define kAppDistributionPlist      @"https://akrgis.nps.gov/observer/Park_Observer.plist"
#define kOKButtonText              NSLocalizedString(@"OK", @"OK button text")


@interface ObserverAppDelegate()

@property (nonatomic,strong) ObserverMapViewController *observerMapViewController;
@property (nonatomic,strong) SProtocol *protocolForSurveyCreation;

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
        NSLog(@"Error using client ID : %@",[error localizedDescription]);
    }

    Map *savedMap = [[Map alloc] initWithCachedPropertiesURL:[Settings manager].activeMapPropertiesURL];
    if (savedMap) {
        self.observerMapViewController.map = savedMap;
    }
    Survey *savedSurvey = [[Survey alloc] initWithURL:[Settings manager].activeSurveyURL];
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
    [self checkForUpdates];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    AKRLog(@"Terminating App.  Synchronizing User Defaults");
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // Called when this app is asked to open a resource (url) by a different app
    // The url is a local file resource (typically in Documents/Inbox), and can only
    //   be a file type that I have registered interest in (app configuration plist)
    // The user will expect a short delay to open the file
    AKRLog(@"%@ asked me to open %@", sourceApplication, url);

    //The url may contain a resource (e.g. a tile package) that we already have in the documents directory.
    //  This is unlikely, and while we could try to determine equality and return the existing resource if
    //  the new resource is a duplicate, there is a chance for false positives, which would frustrate the user.
    //  It is better to just do what the user asked - They can then determine equality and remove the duplicate.

    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *newUrl = [documentsDirectory URLByAppendingPathComponent:url.lastPathComponent];
    newUrl = [newUrl URLByUniquingPath];
    NSError *error = nil;
    [[NSFileManager defaultManager] copyItemAtURL:url toURL:newUrl error:&error];
    if (error) {
        [self alert:url.lastPathComponent message:@"Unable to open file."];
        return NO;
    }

    if ([SurveyCollection collectsURL:newUrl]) {
        Survey *newSurvey = [[Survey alloc] initWithArchive:newUrl];
        [[NSFileManager defaultManager] removeItemAtURL:newUrl error:nil];
        if ([newSurvey isValid]) {
            self.observerMapViewController.survey = newSurvey;
            return YES;
        } else {
            [self alert:url.lastPathComponent message:@"Not a Valid Survey."];
            return NO;
        }
    }
    if ([MapCollection collectsURL:url]) {
        // TODO: Put up a modal, asking for details on the tile cache, i.e. name, author, date, description
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
        if ([newProtocol isValid]) {
            [self.observerMapViewController newProtocolAvailable:newProtocol];
            self.protocolForSurveyCreation = newProtocol;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"New Protocol"
                                                                           message:@"Do you want to open a new survey file with this protocol?"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *waitAction = [UIAlertAction actionWithTitle:@"Maybe Later"
                                                                 style:UIAlertActionStyleCancel
                                                               handler:nil];
            UIAlertAction *openAction = [UIAlertAction actionWithTitle:@"Yes"
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action){
                                                                   Survey *newSurvey = [[Survey alloc] initWithProtocol:self.protocolForSurveyCreation];
                                                                   if ([newSurvey isValid]) {
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

- (void)checkForUpdates
{
    [self checkForUpdateWithCallback:^(BOOL found) {
        if (found) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"New Version Waiting"
                                                                           message:@"Are you ready to upgrade?"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *waitAction = [UIAlertAction actionWithTitle:@"No"
                                                                 style:UIAlertActionStyleCancel
                                                               handler:nil];
            UIAlertAction *openAction = [UIAlertAction actionWithTitle:@"Yes"
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action){
                                                                   NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"itms-services://?action=download-manifest&url=%@",kAppDistributionPlist]];
                                                                   [[UIApplication sharedApplication] openURL:url];
                                                               }];
            [alert addAction:waitAction];
            [alert addAction:openAction];
            [self presentAlert:alert];
        }
    }];
}

- (void)checkForUpdateWithCallback:(void (^)(BOOL found))callback
{
    if (!callback)
        return;

    BOOL updateAvailable = NO;
    NSDictionary *updateDictionary = [NSDictionary dictionaryWithContentsOfURL:
                                      [NSURL URLWithString:kAppDistributionPlist]];

    if(updateDictionary)
    {
        NSArray *items = [updateDictionary objectForKey:@"items"];
        NSDictionary *itemDict = [items lastObject];

        NSDictionary *metaData = [itemDict objectForKey:@"metadata"];
        NSString *newversion = [metaData valueForKey:@"bundle-version"];
        NSString *currentversion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];

        updateAvailable = [newversion compare:currentversion options:NSNumericSearch] == NSOrderedDescending;
    }
    callback(updateAvailable);
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
    id rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    if([rootViewController isKindOfClass:[UINavigationController class]])
    {
        rootViewController = ((UINavigationController *)rootViewController).viewControllers.firstObject;
    }
    if([rootViewController isKindOfClass:[UITabBarController class]])
    {
        rootViewController = ((UITabBarController *)rootViewController).selectedViewController;
    }
    [rootViewController presentViewController:alert animated:YES completion:nil];
}

@end
