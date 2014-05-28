//
//  ObserverMapViewController.m
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

/*
 Note that I only use esri's LocationDisplay for the graphic display, and the autopan features.
 I use Apple's CLLocationManager for all the Gps information.
 This is because the LocationDisplay does not provide a delegate or any messages when locations change,
 and the location information is insufficent (missing timestamp, accuracy and altitude).
 The LocationDisplay does have a nice feature of providing the current location in map coordinates.
 I am not using that due to the potential for getting different locations when calling the two
 different objects.  Therefore all my locations will come from CLLocationManager, and be converted
 to map coordinates by me.

 All features are saved in wgs84, and converted to the projection of the base map (mapview) when
 instantiated as graphics.  If the basemap changes, then the graphics layers are discared and
 recreated from the saved features.
 */


//Sub ViewControllers
#import "ObserverMapViewController.h"
#import "AngleDistanceViewController.h"
#import "SurveySelectViewController.h"
#import "ProtocolSelectViewController.h"
#import "MapSelectViewController.h"
#import "AttributeViewController.h"
#import "FeatureSelectorTableViewController.h"
#import "UIPopoverController+Presenting.h"
#import "GpsPointTableViewController.h"

//Views
#import "AutoPanButton.h"
#import "AddFeatureBarButtonItem.h"
#import "AGSMapView+AKRAdditions.h"

//Support Model Objects
#import "AutoPanStateMachine.h"
#import "Survey+CsvExport.h"

//Support sub-system
#import "QuickDialog.h"

//Constants and Magic Numbers/Strings
#define kActionSheetSelectLocation 1
#define kActionSheetSelectFeature  2

#define kOKButtonText              NSLocalizedString(@"OK", @"OK button text")
#define kCancelButtonText          NSLocalizedString(@"Cancel", @"Cancel button text")



@interface ObserverMapViewController () {
    CGFloat _initialRotationOfViewAtGestureStart;
}

//Views
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UIView *noMapView;
@property (weak, nonatomic) IBOutlet UIButton *compassRoseButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *mapLoadingIndicator;

@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectMapButton;
@property (weak, nonatomic) IBOutlet AutoPanButton *panButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectSurveyButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *startStopRecordingBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *startStopObservingBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editEnvironmentBarButton;

@property (strong, nonatomic) NSMutableArray *addFeatureBarButtonItems;  //NSArray of AddFeatureBarButtonItem

//Support
@property (nonatomic) int  busyCount;
@property (nonatomic) BOOL locationServicesAvailable;
@property (nonatomic) BOOL userWantsLocationUpdates;
@property (nonatomic) BOOL userWantsHeadingUpdates;
@property (nonatomic) BOOL gpsFailed;

@property (strong, nonatomic) AutoPanStateMachine *autoPanController;
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) id<AGSFeature> movingGraphic;  //maintain state between AGSMapViewTouchDelegate calls
@property (strong, nonatomic) Observation *movingObservation;  //maintain state between AGSMapViewTouchDelegate calls
@property (strong, nonatomic) MissionProperty *movingMissionProperty;  //maintain state between AGSMapViewTouchDelegate calls

//Used to save state for delegate callbacks (alertview, actionsheet and segue)
@property (strong, nonatomic) ProtocolFeature *currentProtocolFeature;
@property (strong, nonatomic) SProtocol *protocolForSurveyCreation;
@property (strong, nonatomic) AGSPoint *mapPointAtAddSelectedFeature;  //maintain state for UIActionSheetDelegate callback

//Must maintain a reference to popover controllers, otherwise they are GC'd after they are presented
@property (strong, nonatomic) UIPopoverController *angleDistancePopoverController;
@property (strong, nonatomic) UIPopoverController *mapsPopoverController;
@property (strong, nonatomic) UIPopoverController *surveysPopoverController;
@property (strong, nonatomic) UIPopoverController *featureSelectorPopoverController;
@property (strong, nonatomic) UIPopoverController *reviewAttributePopoverController;
@property (strong, nonatomic) UIPopoverController *editAttributePopoverController;

@property (strong, nonatomic) AGSPoint *popoverMapPoint;  //maintain popover location while rotating device (did/willRotateToInterfaceOrientation:)

//TODO: do I need this UINavigationController?
@property (strong, nonatomic) UINavigationController *modalAttributeCollector;

@end



@implementation ObserverMapViewController

#pragma mark - Super class overrides

- (void)viewDidLoad
{
    //AKRLog(@"Main view controller view did load");
    [super viewDidLoad];
    [self configureMapView];
    [self configureGpsButton];
    [self configureObservationButtons];
    [self openMap];
    [self openSurvey];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"Select Survey"])
    {
        if (self.surveysPopoverController) {
            [self.surveysPopoverController dismissPopoverAnimated:YES];
            self.surveysPopoverController = nil;
            return NO;
        }
    }
    if ([identifier isEqualToString:@"Select Map"])
    {
        if (self.mapsPopoverController) {
            [self.mapsPopoverController dismissPopoverAnimated:YES];
            self.mapsPopoverController = nil;
            return NO;
        }
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    UIViewController *vc1 = [segue destinationViewController];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UINavigationController *nav = [segue destinationViewController];
        vc1 = [nav.viewControllers firstObject];
    }
    if ([segue.identifier isEqualToString:@"Select Survey"]){
        SurveySelectViewController *vc = (SurveySelectViewController *)vc1;
        vc.title = segue.identifier;
        vc.surveySelectedAction = ^(Survey *survey){
            //Dismiss the VC before assigning to self.survey, to avoid re-adding the survey to the VC
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                [self.surveysPopoverController dismissPopoverAnimated:YES];
                self.surveysPopoverController = nil;
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
            self.survey = survey;
        };
        vc.surveyUpdatedAction = ^(Survey *survey){
            if ([survey isEqualToSurvey:self.survey]) {
                [self updateTitleBar];
            }
        };
        vc.surveyDeletedAction = ^(Survey *survey){
            if ([survey isEqualToSurvey:self.survey]) {
                self.survey = nil;
            };
        };
        if ([segue isKindOfClass:[UIStoryboardPopoverSegue class]]) {
            self.surveysPopoverController = ((UIStoryboardPopoverSegue *)segue).popoverController;
            self.surveysPopoverController.delegate = self;
        }
        return;
    }

    if ([segue.identifier isEqualToString:@"Select Map"]) {
        MapSelectViewController *vc = (MapSelectViewController *)vc1;
        vc.title = segue.identifier;
        vc.mapSelectedAction = ^(Map *map){
            //Dismiss the VC before assigning to self.map, to avoid re-adding the map to the VC
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                [self.mapsPopoverController dismissPopoverAnimated:YES];
                self.mapsPopoverController = nil;
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
            self.map = map;
        };
        vc.mapDeletedAction = ^(Map *map){
            if ([map isEqualToMap:map]) {
                self.map = nil;
            };
        };
        if ([segue isKindOfClass:[UIStoryboardPopoverSegue class]]) {
            self.mapsPopoverController = ((UIStoryboardPopoverSegue *)segue).popoverController;
            self.mapsPopoverController.delegate = self;
        }
        return;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.mapView.locationDisplay.interfaceOrientation = toInterfaceOrientation;
    //popovers not presented from a UIBarButtonItem must close and reopen in the new orientation
    [self.editAttributePopoverController dismissPopoverAnimated:NO];
    [self.reviewAttributePopoverController dismissPopoverAnimated:NO];
    [self.featureSelectorPopoverController dismissPopoverAnimated:NO];
    [self.angleDistancePopoverController dismissPopoverAnimated:NO];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    //re-present popovers not presented from a UIBarButtonItem in the new orientation
    [self.editAttributePopoverController presentPopoverFromMapPoint:self.popoverMapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
    [self.reviewAttributePopoverController presentPopoverFromMapPoint:self.popoverMapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
    [self.featureSelectorPopoverController presentPopoverFromMapPoint:self.popoverMapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
    [self.angleDistancePopoverController presentPopoverFromMapPoint:self.popoverMapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
}




#pragma mark - IBActions

// I'm doing the rotation myself, instead of using self.mapView.allowRotationByPinching = YES
// because I need to sync it with the compass rose,
// but the real problem was the mapView was missing some gestures, and capturing some I didn't get
- (IBAction)rotateMap:(UIRotationGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self.autoPanController userRotatedMap];
        _initialRotationOfViewAtGestureStart = atan2f(self.compassRoseButton.transform.b, self.compassRoseButton.transform.a);
    }
    CGFloat radians = _initialRotationOfViewAtGestureStart + sender.rotation;
    CGFloat degrees = (CGFloat)(radians * (180 / M_PI));
    self.compassRoseButton.transform = CGAffineTransformMakeRotation(radians);
    [self.mapView setRotationAngle:-1*degrees];
}

- (IBAction)panMap:(UIPanGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        //AKRLog(@"User started Pan");
        // Map panning is done internally by ArcGIS, and the map view will turn off autopanning when the user pans.
        // However, I need to know when the user manually pans, so I can update the UI controls
        // mapView has no delegate messages for panning and the notifications provided does not distinguish between auto v. manual pans.
        //user panning will turn off the autopan mode, so I need to update the toolbar button.
        [self.autoPanController userPannedMap];
        [self startStopLocationServicesForPanMode];
    }
}

- (IBAction)resetNorth:(UIButton *)sender {
    [self.autoPanController userClickedCompassRoseButton];
    [self startStopLocationServicesForPanMode];
    [self.mapView setRotationAngle:0 animated:YES];
    self.compassRoseButton.transform = CGAffineTransformMakeRotation(0);
}

- (IBAction)togglePanMode:(UIBarButtonItem *)sender {
    [self.autoPanController userClickedAutoPanButton];
    [self startStopLocationServicesForPanMode];
    [self rotateNorthArrow];
}


- (IBAction)startRecording:(UIBarButtonItem *)sender
{
    if (self.survey.isRecording) {
        return;
    }
    if(![self.survey startRecording]) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to start recording.  GPS may not be ready." delegate:nil cancelButtonTitle:kOKButtonText otherButtonTitles:nil] show];
        return;
    }
    self.startStopRecordingBarButtonItem = [self setBarButtonAtIndex:5 action:@selector(stopRecording:) ToPlay:NO];
    [self enableControls];
    [self startLocationUpdates];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (IBAction)startObserving:(UIBarButtonItem *)sender
{
    if (self.survey.isObserving || !self.survey.isRecording) {
        return;
    }
    TrackLogSegment *tracklog = [self.survey startObserving];
    [self showTrackLogAttributeEditor:tracklog];
    self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:7 action:@selector(stopObserving:) ToPlay:NO];
    [self enableControls];
}

- (IBAction)changeEnvironment:(UIBarButtonItem *)sender
{
    if (self.survey.isRecording) {
        TrackLogSegment *tracklog = [self.survey startNewTrackLogSegment];
        [self showTrackLogAttributeEditor:tracklog];
    } else {
        MissionProperty *missionProperty = [self.survey createMissionPropertyAtMapLocation:self.mapView.mapAnchor];
        [self showMissionPropertyAttributeEditor:missionProperty];
    }
}




#pragma mark - Actions wired up programatically

- (void)stopRecording:(UIBarButtonItem *)sender
{
    if (!self.survey.isRecording) {
        return;
    }
    [self stopLocationUpdates];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    if (self.survey.isObserving) {
        self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:7 action:@selector(startObserving:) ToPlay:YES];
        [self enableControls];
    }
    [self.survey stopRecording];
    self.startStopRecordingBarButtonItem = [self setBarButtonAtIndex:5 action:@selector(startRecording:) ToPlay:YES];
    [self enableControls];
}

- (void)stopObserving:(UIBarButtonItem *)sender
{
    if (!self.survey.isObserving) {
        return;
    }
    [self.survey stopObserving];
    self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:7 action:@selector(startObserving:) ToPlay:YES];
    [self enableControls];
}

- (void)pleaseAddFeature:(AddFeatureBarButtonItem *)sender
{
    ProtocolFeature *feature = sender.feature;
    [self addFeature:feature withNonTouchLocationMethod:feature.locationMethod];
}

- (void)selectFeatureLocationMethod:(UILongPressGestureRecognizer *)sender
{
    // UILongPressGestureRecognizer is a continuous gesture, I only want to be called once.
    if ( sender.state != UIGestureRecognizerStateBegan ) {
        return;
    }

    //Find the bar button the initiated the long press;
    //Normally I would use the view property of the Gesture, but bar buttons are not UIViews
    AddFeatureBarButtonItem * button = nil;
    for (AddFeatureBarButtonItem *item in self.addFeatureBarButtonItems) {
        if (sender == item.longPress) {
            button = item;
            break;
        }
    }
    if (!button) {
        AKRLog(@"Oh No!  I didn't find the button the belongs to the long press");
    }
    ProtocolFeature *feature = button.feature;
    self.currentProtocolFeature = feature;  //Save the feature for the action sheet delegate callback
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    sheet.tag = kActionSheetSelectLocation;
    for (NSString *title in [ProtocolFeatureAllowedLocations stringsForLocations:feature.allowedLocations.nonTouchChoices]) {
        [sheet addButtonWithTitle:title];
    }
    // Fix for iOS bug.  See https://devforums.apple.com/message/857939#857939
    [sheet addButtonWithTitle:kCancelButtonText];
    sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
    
    [sheet showFromBarButtonItem:button animated:NO];
}




#pragma mark - Public Interface

- (void)setSurvey:(Survey *)survey
{
    if (!survey && !_survey) {  //covers case where survey is nil
        return;
    }
    if ([survey isEqualToSurvey:_survey]) {
        return;
    }
    if ([self closeSurveyWithConcurrentOpen:(survey != nil)]) {
        _survey = survey;
        [Settings manager].activeSurveyURL = survey.url;
        [self openSurvey];
        [self updateSelectSurveyViewControllerWithNewSurvey:survey];
    }
}

- (void)setMap:(Map *)map
{
    if (map == _map) {  //covers case where map is nil
        return;
    }
    if ([map isEqualToMap:_map]) {
        return;
    }
    [self closeMap];
    _map = map;
    [Settings manager].activeMapURL = map.url;
    [self openMap];
    [self updateSelectMapViewControllerWithNewMap:map];
}

- (void)newProtocolAvailable:(SProtocol *)protocol
{
    if (protocol) {
        ProtocolSelectViewController *vc = nil;
        UINavigationController *nav = nil;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            nav = (UINavigationController *)self.surveysPopoverController.contentViewController;
        } else {
            nav = self.navigationController;
        }
        for (UIViewController *vc1 in nav.viewControllers) {
            if ([vc1 isKindOfClass:[ProtocolSelectViewController class]]) {
                vc = (ProtocolSelectViewController *)vc1;
                break;
            }
        }
        [vc addProtocol:protocol];
    }
}




#pragma mark - Public Interface = private support

- (void)updateSelectSurveyViewControllerWithNewSurvey:(Survey *)survey
{
    if (survey) {
        SurveySelectViewController *vc = nil;
        UINavigationController *nav = nil;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            nav = (UINavigationController *)self.surveysPopoverController.contentViewController;
        } else {
            nav = self.navigationController;
        }
        for (UIViewController *vc1 in nav.viewControllers) {
            if ([vc1 isKindOfClass:[SurveySelectViewController class]]) {
                vc = (SurveySelectViewController *)vc1;
                break;
            }
        }
        [vc addSurvey:survey];
    }
}

- (void)updateSelectMapViewControllerWithNewMap:(Map *)map
{
    if (map) {
        MapSelectViewController *vc = nil;
        UINavigationController *nav = nil;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            nav = (UINavigationController *)self.mapsPopoverController.contentViewController;
        } else {
            nav = self.navigationController;
        }
        if ([nav.topViewController isKindOfClass:[MapSelectViewController class]]) {
            vc = (MapSelectViewController *)nav.topViewController;
        }
        [vc addMap:map];
    }
}




#pragma mark - Delegate Methods: CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorized)
    {
        if (!self.locationServicesAvailable) {
            AKRLog(@"Location manager did change status: authorized");
            self.locationServicesAvailable = YES;
            if (self.userWantsHeadingUpdates) {
                [self.locationManager startUpdatingHeading];
            }
            if (self.userWantsLocationUpdates) {
                [self.locationManager startUpdatingLocation];
            }
        }
    } else {
        if (self.locationServicesAvailable) {
            AKRLog(@"Location manager did change status: deauthorized");
            self.locationServicesAvailable = NO;
            if (self.userWantsHeadingUpdates) {
                [self.locationManager stopUpdatingHeading];
            }
            if (self.userWantsLocationUpdates) {
                [self.locationManager stopUpdatingLocation];
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    //AKRLog(@"locationManager: didUpdateLocations:%@",locations);
    if (self.survey.isRecording) {
        for (CLLocation *location in locations) {
            [self.survey addGpsPointAtLocation:location];
        }
    }

    //use the speed of the last location to update the autorotation behavior
    CLLocation *location = [locations lastObject];
    if (0 <= location.speed) {
        [self.autoPanController speedUpdate:location.speed];
    }

    if (self.gpsFailed) {
        self.gpsFailed = NO;
        [self enableControls];
        [[[UIAlertView alloc] initWithTitle:nil message:@"@GPS is back!" delegate:nil cancelButtonTitle:kOKButtonText otherButtonTitles:nil] show];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    //AKRLog(@"locationManager: didUpdateHeading: %f",newHeading.trueHeading);
    [self rotateNorthArrow];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [[[UIAlertView alloc] initWithTitle:@"Location Failure" message:error.localizedDescription delegate:nil cancelButtonTitle:kOKButtonText otherButtonTitles:nil] show];
    self.gpsFailed = YES;
    [self enableControls];
}




#pragma mark - Delegate Methods: AGSLayerDelegate

- (void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error
{
    self.map = nil;
    [self.survey clearMap];
    [self.survey clearMapMapViewSpatialReference];
    [self configureObservationButtons];
    [self decrementBusy];
    [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to load map" delegate:nil cancelButtonTitle:kOKButtonText otherButtonTitles:nil] show];
}




#pragma mark - Delegate Methods: AGSMapViewLayerDelegate (all optional)

- (void)mapViewDidLoad:(AGSMapView*)mapView
{
    //Tells the delegate the map is loaded and ready for use. Fires when the map’s base layer loads.
    AKRLog(@"Basemap has been loaded");
    self.noMapView.hidden = YES;
    [self loadGraphics];
    [self setupGPS];
    [self configureObservationButtons];
    [self decrementBusy];
}

- (BOOL)mapView:(AGSMapView *)mapView shouldHitTestLayer:(AGSLayer *)layer atPoint:(CGPoint)screen mapPoint:(AGSPoint *)mapPoint
{
    //Asks delegate whether to find which graphics in the specified layer intersect the tapped location. Default is YES.
    //This function may or may not be called on the main thread.
    //AKRLog(@"mapView:shouldFindGraphicsInLayer:(%f,%f)=(%@) with graphics Layer:%@", screen.x, screen.y, mapPoint, layer.name);
    return [self.survey isSelectableLayerName:layer.name];
}




#pragma mark - Delegate Methods: AGSMapViewTouchDelegate (all optional)

- (void)mapView:(AGSMapView *)mapView didClickAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mapPoint features:(NSDictionary *)features
{
    //Tells the delegate the map was single-tapped at specified location.
    //features: id<AGSFeature> objects from all hit-testable layers in the map that intersect or contain the location.
    //The dictionary contains layer name (key) : Array of id<AGSFeature> (value)

    //AKRLog(@"mapView:didClickAtPoint:(%f,%f)=(%@) with graphics:%@", screen.x, screen.y, mapPoint, features);

    switch (features.count) {  //Number of layers with selected features
        case 0:
            if (self.survey.isObserving) {
                switch (self.survey.protocol.featuresWithLocateByTouch.count) {
                    case 0:
                        break;
                    case 1:
                        [self addFeature:self.survey.protocol.featuresWithLocateByTouch[0] atMapPoint:mapPoint];
                        break;
                    default:
                        [self presentProtocolFeatureSelector:self.survey.protocol.featuresWithLocateByTouch atPoint:screen mapPoint:mapPoint];
                        break;
                }
            }
            break;
        case 1: {
            NSString *layerName = (NSString *)[features.keyEnumerator nextObject];
            NSArray *featureList = features[layerName];
            if (featureList.count == 1) {  //Number of selected features in layer
                [self presentFeature:featureList[0] fromLayer:layerName atMapPoint:mapPoint];
            } else {
                [self presentAGSFeatureSelector:features atMapPoint:mapPoint];
            }
            break;
        }
        default:
            [self presentAGSFeatureSelector:features atMapPoint:mapPoint];
            break;
    }
}

- (void)mapView:(AGSMapView *)mapView didTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mapPoint features:(NSDictionary *)features
{
    //Ignore if there is no selectable feature (only layers that pass the hit test will be passed to this method)
    //If there are multiple selectable features, tell the user to zoom in an select a single feature
    //if feature is a mission property or an observation with a map location
    //   then remember it for upcoming didMoveTapAndHold and didEndTapAndHold delegate calls
    //if feature is an observation with an angle distance
    //   then flash the gps observation point and open the angle distance dialog on that point (try not to hide observation)
    //   move the feature when the dialog is dismissed.

    AKRLog(@"mapView:didTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", screen.x, screen.y, mapPoint, features);
    self.movingObservation = nil;
    self.movingMissionProperty = nil;
    self.movingGraphic = nil;
    switch (features.count) {  //Number of layers with selected features
        case 0:
            return;
        case 1: {
            NSString *layerName = (NSString *)[features.keyEnumerator nextObject];
            NSArray *featureList = features[layerName];
            switch (featureList.count) {
                case 0:
                    break;
                case 1: {
                    id<AGSFeature> feature = featureList[0];
                    NSDate *timestamp = (NSDate *)[feature safeAttributeForKey:kTimestampKey];
                    NSManagedObject *entity = [self.survey entityOnLayerNamed:layerName atTimestamp:timestamp];
                    self.movingMissionProperty = [self.survey missionPropertyFromEntity:entity];
                    self.movingObservation = [self.survey observationFromEntity:entity];
                    if (self.movingMissionProperty) {
                        //TODO: support moving mission properties
                        [[[UIAlertView alloc] initWithTitle:nil message:@"Can't move mission properties yet." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
                        self.movingMissionProperty = nil;
                    }
                    if (self.movingObservation.angleDistanceLocation) {
                        //TODO: Support moving Angle/Distance located observations
                        [[[UIAlertView alloc] initWithTitle:nil message:@"Can't move angle/distance features yet." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
                        self.movingObservation = nil;
                    }
                    if (self.movingObservation.gpsPoint) {
                        //TODO: support moving GPS located observations
                        [[[UIAlertView alloc] initWithTitle:nil message:@"Can't move GPS located features yet." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
                        self.movingObservation = nil;
                    }
                    if (self.movingMissionProperty || self.movingObservation) {
                        self.movingGraphic = feature;
                    }
                    break;
                }
                default:
                    [[[UIAlertView alloc] initWithTitle:nil message:@"Zoom in to select a single feature." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
                    break;
            }
            break;
        }
        default:
            [[[UIAlertView alloc] initWithTitle:nil message:@"Zoom in to select a single feature." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
            break;
    }
    AKRLog(@"moving %@",self.movingGraphic);
}

- (void)mapView:(AGSMapView *)mapView didMoveTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mapPoint features:(NSDictionary *)features
{
    //AKRLog(@"mapView:didMoveTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", screen.x, screen.y, mapPoint, features);

    //TODO: If the moving feature is based on a GPS point, then snap to the closest GPS point
    if (self.movingGraphic) {
        [self.movingGraphic setGeometry:mapPoint];
    }
}

- (void) mapView:(AGSMapView *)mapView didEndTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mapPoint features:(NSDictionary *)features
{
    AKRLog(@"mapView:didEndTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", screen.x, screen.y, mapPoint, features);

    //Move Adhoc location
    [self.survey updateAdhocLocation:self.movingObservation.adhocLocation withMapPoint:mapPoint];
    if ([self.movingGraphic isKindOfClass:[AGSGraphic class]]) {
        AGSGraphic *graphic = (AGSGraphic *)self.movingGraphic;
        [[graphic layer] removeGraphic:graphic];
        [self.survey drawObservation:self.movingObservation];
    }

    //Move GPS location
    //TODO: If the feature is based on a GPS point, then snap to the closest GPS point

    //Move Mission Property
    //[self.survey updateAdhocLocation:self.movingMissionProperty.adhocLocation withMapPoint:mapPoint];
    //TODO: if this was a mission property, then we need to update the tracklogs.

    self.movingObservation = nil;
    self.movingMissionProperty = nil;
    self.movingGraphic = nil;
}




#pragma mark - Delegate Methods: UIPopoverControllerDelegate

//This is not called if the popover is programatically dismissed.
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (popoverController == self.surveysPopoverController) {
        self.surveysPopoverController = nil;
    }
    if (popoverController == self.angleDistancePopoverController) {
        self.angleDistancePopoverController = nil;
    }
    if (popoverController == self.mapsPopoverController) {
        self.mapsPopoverController = nil;
    }
    if (popoverController == self.reviewAttributePopoverController) {
        self.reviewAttributePopoverController = nil;
    }
    if (popoverController == self.editAttributePopoverController) {
        [self saveAttributes:nil];
        self.editAttributePopoverController = nil;
    }
}




#pragma mark - Delegate Methods: UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag) {
        default:
            AKRLog(@"Oh No!, Alert View delegate called for an unknown alert view (tag = %d",alertView.tag);
            break;
    }
}




#pragma mark - Delegate Methods: UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    AKRLog(@"ActionSheet %d was dismissed with Button %d click", actionSheet.tag, buttonIndex);
    if (buttonIndex < 0) {
        return;
    }
    switch (actionSheet.tag) {
        case kActionSheetSelectLocation: {
            ProtocolFeature *feature = self.currentProtocolFeature;
            NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
            WaysToLocateFeature locationMethod = [ProtocolFeatureAllowedLocations locationMethodForName:buttonTitle];
            feature.preferredLocationMethod = locationMethod;
            [self addFeature:feature withNonTouchLocationMethod:locationMethod];
            break;
        }
        case kActionSheetSelectFeature: {
            NSString *featureName = [actionSheet buttonTitleAtIndex:buttonIndex];
            __block ProtocolFeature *feature = nil;
            [self.survey.protocol.featuresWithLocateByTouch enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ([featureName isEqualToString:((ProtocolFeature *)obj).name]) {
                    *stop = YES;
                    feature = obj;
                }
            }];
            if (feature) {
                [self addFeature:feature atMapPoint:self.mapPointAtAddSelectedFeature];
            } else {
                AKRLog(@"Oh No!, Selected feature not found in survey protocol");
            }
            break;
        }
        default:
            AKRLog(@"Oh No!, Action sheet delegate called for an unknown action sheet (tag = %d",actionSheet.tag);
            break;
    }
}




#pragma mark = Delegate Methods - Location Presenter

- (BOOL)hasGPS
{
    return self.locationServicesAvailable;
}

- (BOOL)hasMap
{
    return self.mapView.loaded;
}

- (BOOL)mapIsProjected
{
    return self.mapView.isProjected;
}




#pragma mark = Delegate Methods - SurveyLocationDelegate

- (CLLocation *)locationOfGPS
{
    return self.locationManager.location;
}




#pragma mark - Private Properties

- (CLLocationManager *)locationManager
{
    if (!_locationManager) {
        self.locationServicesAvailable = NO;
        //create manager and register as a delegate even if service are unavailable to get changes in authorization (via settings)
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;

        if (![CLLocationManager locationServicesEnabled]) {
            AKRLog(@"Location Services Not Enabled");
        } else {
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
                AKRLog(@"Triggering a request for permission to use Location Services.");
                [_locationManager startUpdatingLocation];
                [_locationManager stopUpdatingLocation];
            }
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized)
            {
                self.locationServicesAvailable = YES;
                AKRLog(@"Location Services Available and Authorized");
            } else {
                AKRLog(@"Location Services NOT Authorized");
            }
        }
    }
    return _locationManager;
}

- (BOOL)locationServicesAvailable
{
    //this value is undefined if the there is no locationManager
#ifdef AKR_DEBUG
    //In the simulator, I can have location services, but the location is set to NONE
    //treat NO location as no service available
    BOOL hasLocation = self.locationManager.location.timestamp != nil;
    return !self.locationManager ? NO : _locationServicesAvailable && hasLocation;
#else
    return !self.locationManager ? NO : _locationServicesAvailable;
#endif
}

- (NSMutableArray *)addFeatureBarButtonItems
{
    if (!_addFeatureBarButtonItems) {
        _addFeatureBarButtonItems = [NSMutableArray new];
    }
    return _addFeatureBarButtonItems;
}




#pragma mark - Private - UI configuration

- (void)configureMapView
{
    self.mapView.layerDelegate = self;
    self.mapView.touchDelegate = self;
    self.mapView.callout.delegate = self;
    //the remaining configuration will occur after a layer is loaded
    if (self.map.tileCache) {
        [self.mapView addMapLayer:self.map.tileCache withName:@"tilecache basemap"];
        //adding a layer is async. wait for AGSLayerDelegate layerDidLoad or layerDidFailToLoad to decrementBusy
    }
}

- (void)configureGpsButton
{
    self.autoPanController = [[AutoPanStateMachine alloc] init];
    self.autoPanController.mapView = self.mapView;
    self.autoPanController.compassRoseButton = self.compassRoseButton;
    self.autoPanController.autoPanModeButton = self.panButton;
}

- (void)configureObservationButtons
{
    NSMutableArray *toolbarButtons = [self.toolbar.items mutableCopy];
    //Remove any existing Add Feature buttons
    [toolbarButtons removeObjectsInArray:self.addFeatureBarButtonItems];

    [self.addFeatureBarButtonItems removeAllObjects];
    if (self.survey) {
        for (ProtocolFeature *feature in self.survey.protocol.features) {
            feature.allowedLocations.locationPresenter = self;
            if (feature.allowedLocations.countOfNonTouchChoices > 0) {
                //TODO: feature names may be too long for buttons, use a short name, or an icon
                AddFeatureBarButtonItem *addFeatureButton = [[AddFeatureBarButtonItem alloc] initWithTitle:feature.name style:UIBarButtonItemStylePlain target:self action:@selector(pleaseAddFeature:)];
                addFeatureButton.feature = feature;
                if (feature.allowedLocations.countOfNonTouchChoices > 1) {
                    feature.preferredLocationMethod = feature.allowedLocations.initialNonTouchChoice;
                    //Gesture recognizers have to be attached to a view, BarButtonItems do not have a view until they are added to the toolbar, and even then they are private
                    addFeatureButton.longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(selectFeatureLocationMethod:)];
                }
                [self.addFeatureBarButtonItems addObject:addFeatureButton];
            }
        }
    }
    [toolbarButtons addObjectsFromArray:self.addFeatureBarButtonItems];
    [self.toolbar setItems:toolbarButtons animated:YES];
    [self hookupBarButtonGestures];
}

-(void)hookupBarButtonGestures
{
    //Hack to hookup gesture recognizer to a bar button item.
    //BarButtonItems do not have a view until they have been added to a toolbar
    //A BarButtonItems view will change everytime the toolbar items array is changed.
    //We are using a public method to access a private variable (http://stackoverflow.com/a/9371184/542911)
    for (AddFeatureBarButtonItem *barButton in self.addFeatureBarButtonItems) {
        if (barButton.longPress) {
            [[barButton valueForKey:@"view"] addGestureRecognizer:barButton.longPress];
        }
    }
}

-(void)updateTitleBar
{
    self.selectSurveyButton.title = (self.survey.isReady ? self.survey.title : @"Select Survey");
}

-(void)disableControls
{
    self.selectMapButton.enabled = NO;
    self.selectSurveyButton.enabled = NO;

    self.panButton.enabled = NO;

    self.startStopRecordingBarButtonItem.enabled = NO;
    self.startStopObservingBarButtonItem.enabled = NO;
    self.editEnvironmentBarButton.enabled = NO;
    for (AddFeatureBarButtonItem *item in self.addFeatureBarButtonItems) {
        item.enabled = NO;
    }
}

-(void)enableControls
{
    self.selectMapButton.enabled = YES;
    self.selectSurveyButton.enabled = YES;

    self.panButton.enabled = self.mapView.loaded;

    self.startStopRecordingBarButtonItem.enabled = self.survey.isReady && self.locationServicesAvailable && !self.gpsFailed;
    self.startStopObservingBarButtonItem.enabled = self.survey.isRecording && !self.gpsFailed;
    self.editEnvironmentBarButton.enabled = self.survey.isRecording && self.survey.protocol.missionFeature.attributes.count > 0 && !self.gpsFailed;
    for (AddFeatureBarButtonItem *item in self.addFeatureBarButtonItems) {
        item.enabled = self.survey.isObserving && !self.gpsFailed;
    }
}

- (void)incrementBusy
{
    //AKRLog(@"Start increment busy = %d",self.busyCount);
    if (self.busyCount == 0) {
        [self disableControls];
        [self.mapLoadingIndicator startAnimating];
    }
    self.busyCount++;
    //AKRLog(@"Finished increment busy = %d",self.busyCount);
}

- (void)decrementBusy
{
    //AKRLog(@"Start decrement busy = %d",self.busyCount);
    if (self.busyCount == 0) {
        return;
    }
    if (self.busyCount == 1) {
        [self enableControls];
        [self.mapLoadingIndicator stopAnimating];
        AKRLog(@"Ready to go");
    }
    self.busyCount--;
    //AKRLog(@"Finished decrement busy = %d",self.busyCount);
}




#pragma mark - Private Methods - support for UI actions

- (void)startStopLocationServicesForPanMode
{
    if (self.mapView.isAutoRotating) {
        [self startHeadingUpdates];  //monitor heading to rotate compass rose
        [self startLocationUpdates]; //monitor speed to switch between navigation modes
    } else {
        [self stopHeadingUpdates];
        [self stopLocationUpdates];
    }
}

- (void)rotateNorthArrow
{
    double degrees = self.mapView.rotationAngle;
    //AKRLog(@"Rotating compass icon to %f degrees", degrees);
    //angle in radians with positive being counterclockwise (on iOS)
    double radians = -1*degrees * M_PI / 180.0;
    self.compassRoseButton.transform = CGAffineTransformMakeRotation((CGFloat)radians);
}

//Called by bar buttons with play/pause toggle behavior
- (UIBarButtonItem *)setBarButtonAtIndex:(NSUInteger)index action:(SEL)action ToPlay:(BOOL)play
{
    NSMutableArray *toolbarButtons = [self.toolbar.items mutableCopy];
    UIBarButtonItem *newBarButton;
    if (play) {
        newBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:action];
    } else {
        newBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:action];
    }
    [toolbarButtons removeObjectAtIndex:index];
    [toolbarButtons insertObject:newBarButton atIndex:index];
    [self.toolbar setItems:toolbarButtons animated:YES];
    [self hookupBarButtonGestures];
    return newBarButton;
}




#pragma mark - Private Methods - support for location delegate

- (void)startHeadingUpdates
{
    self.userWantsHeadingUpdates = YES;
    if (self.locationServicesAvailable) {
        //AKRLog(@"Start Updating Heading");
        [self.locationManager startUpdatingHeading];
    }
}

- (void)stopHeadingUpdates
{
    self.userWantsHeadingUpdates = NO;
    if (self.locationServicesAvailable) {
        //AKRLog(@"Stop Updating Heading");
        [self.locationManager stopUpdatingHeading];
    }
}

- (void)startLocationUpdates
{
    self.userWantsLocationUpdates = YES;
    if (self.locationServicesAvailable) {
        //AKRLog(@"Start Updating Location");
        [self.locationManager startUpdatingLocation];
    }
}

- (void)stopLocationUpdates
{
    //I may try to stop for multiple reasons. Only stop if they all want to stop
    if (!self.survey.isRecording && !self.mapView.isAutoRotating) {
        self.userWantsLocationUpdates = NO;
        if (self.locationServicesAvailable) {
            //AKRLog(@"Stop Updating Location");
            [self.locationManager stopUpdatingLocation];
        }
    }
}




#pragma mark - Private Methods - support for map delegate

- (void)closeMap
{
    [self.mapView reset]; //removes all layers, clear SR, envelope, etc.
    [self.survey clearMap];
    [self.survey clearMapMapViewSpatialReference];
    self.noMapView.hidden = NO;
    self.panButton.enabled = NO;
}

- (void)openMap
{
    if (self.map && self.isViewLoaded) {
        if (self.map.tileCache)
        {
            [self incrementBusy];
            self.noMapView.hidden = YES;
            self.panButton.enabled = YES;
            self.map.tileCache.delegate = self;
            AKRLog(@"Loading the basemap %@", self.map);
            [self.mapView addMapLayer:self.map.tileCache withName:@"tilecache basemap"];
            //adding a layer is async. See AGSLayerDelegate layerDidLoad or layerDidFailToLoad for additional action taken when opening a map
        } else {
            [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to open the map." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        }
    }
}

- (void)setupGPS
{
    self.mapView.locationDisplay.navigationPointHeightFactor = 0.5;
    self.mapView.locationDisplay.wanderExtentFactor = 0.0;
    self.mapView.locationDisplay.interfaceOrientation = self.interfaceOrientation;
    [self.mapView.locationDisplay startDataSource];
    [self startStopLocationServicesForPanMode];
}

- (void)loadGraphics
{
    if (!self.survey.isReady || !self.mapView.loaded) {
        AKRLog(@"Loading graphics - can't because %@.", self.survey.isReady ? @"map isn't loaded" : (self.mapView.loaded ? @"survey isn't loaded" : @"map AND survey are null! - how did that happen?"));
        return;
    }
    [self.survey setMap:self.map];
    [self.survey setMapViewSpatialReference:self.mapView.spatialReference];
    [self.survey setLocationDelegate:self];
    [self initializeGraphicsLayer];
    [self.survey loadGraphics];
}

- (void)initializeGraphicsLayer
{
    NSDictionary *graphicsLayers = [self.survey graphicsLayersByName];
    for (NSString *name in graphicsLayers) {
        [self.mapView addMapLayer:graphicsLayers[name] withName:name];
    }
}




#pragma mark - Private Methods - support for data model - Surveys

- (void)openSurvey
{
    if (self.survey && self.isViewLoaded) {
        AKRLog(@"Opening survey document (%@)", self.survey.title);
        [self incrementBusy];
        self.selectSurveyButton.title = @"Loading survey...";
        [self.survey openDocumentWithCompletionHandler:^(BOOL success) {
            //do any other background work;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self loadGraphics];
                    [self.survey logStats];
                    [self configureObservationButtons];
                } else {
                    [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to open the survey." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
                }
                [self updateTitleBar];
                [self decrementBusy];
            });
        }];
    }
}

- (BOOL)closeSurveyWithConcurrentOpen:(BOOL)concurrentOpen
{
    if (self.survey && self.isViewLoaded) {
        Survey *survey = self.survey;  //make a copy, since self.survey may be changed before I finish.
        if (survey.document.documentState == UIDocumentStateNormal) {
            AKRLog(@"Closing survey document (%@)", survey.title);
            [self incrementBusy];  //closing the survey document may block
            self.selectSurveyButton.title = @"Closing survey...";
            if (self.survey.isRecording) {
                [self stopRecording:nil];
            }
            [self.mapView clearGraphicsLayers];
            [survey closeDocumentWithCompletionHandler:^(BOOL success) {
                //this completion handler runs on the main queue;
                if (!success) {
                    //This happens if I deleted the active survey (and there are unsaved changes).  Due to the asyncronity
                    //the delete can happen before the close can finish.  But I don't really care, because it is deleted.
                    [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to close the survey. (Did you just delete it?)" delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
                }
                if (!concurrentOpen) {
                    [self updateTitleBar];
                }
                [self decrementBusy];
            }];
        } else if (survey.document.documentState != UIDocumentStateClosed) {
            AKRLog(@"Survey (%@) is in an abnormal state: %d", survey.title, survey.document.documentState);
            [[[UIAlertView alloc] initWithTitle:nil message:@"Survey is not in a closable state." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
            return NO;
        }
    }
    return YES;
}







//FIXME: Cleanup the following code











#pragma mark - Private Methods - support for creating features

//Called by bar buttons
- (void)addFeature:(ProtocolFeature *)feature withNonTouchLocationMethod:(WaysToLocateFeature)locationMethod
{
    switch (locationMethod) {
        case LocateFeatureWithGPS:
            [self addFeatureAtGps:feature];
            break;
        case LocateFeatureWithMapTarget:
            [self addFeatureAtTarget:feature];
            break;
        case LocateFeatureWithAngleDistance:
            [self addFeatureAtAngleDistance:feature];
            break;
        default:
            AKRLog(@"Location method (%u) specified is not valid",locationMethod);
    }
}

- (void)addFeatureAtGps:(ProtocolFeature *)feature
{
    GpsPoint *gpsPoint = [self.survey addGpsPointAtLocation:self.locationManager.location];
    if (!gpsPoint) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to get GPS point for Feature." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        return;
    }
    Observation *observation = [self.survey createObservation:feature atGpsPoint:gpsPoint];
    if (!observation) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to create feature." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        return;
    }
    AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
    AGSGraphic *graphic = [self.survey drawObservation:observation];
    [self setAttributesForFeatureType:feature entity:observation graphic:graphic defaults:nil atPoint:mapPoint isNew:YES isEditing:YES];
}

- (void)addFeatureAtAngleDistance:(ProtocolFeature *)feature
{
    self.currentProtocolFeature = feature;
    //Find the barbutton item with the feature to attach the popover.
    AddFeatureBarButtonItem *button = nil;
    for (AddFeatureBarButtonItem *item in self.addFeatureBarButtonItems) {
        if (item.feature == feature) {
            button = item;
            break;
        }
    }
    if (button) {
        // It is not possible (AFIK) to set the anchor for a manual popover seque, hence I must do the "segue" with code
        [self performAngleDistanceSequeWithFeature:feature fromButton:button];
    } else {
        AKRLog(@"Oh No! I couldn't find the calling button for the segue");
    }
}

- (void)addFeatureAtTarget:(ProtocolFeature *)feature
{
    Observation *observation = [self.survey createObservation:feature atMapLocation:self.mapView.mapAnchor];
    AGSGraphic *graphic = [self.survey drawObservation:observation];
    [self setAttributesForFeatureType:feature entity:observation graphic:graphic defaults:nil atPoint:self.mapView.mapAnchor isNew:YES isEditing:YES];
}




#pragma mark - Private Methods to Support Feature Selection/Presentation

//called by map touch
- (void)presentProtocolFeatureSelector:(NSArray *)features atPoint:(CGPoint)screenpoint mapPoint:(AGSPoint *)mapPoint
{
    self.mapPointAtAddSelectedFeature = mapPoint;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    sheet.tag = kActionSheetSelectFeature;

    [features enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *name = ((ProtocolFeature *)obj).name;
        [sheet addButtonWithTitle:name];
    }];
    // Fix for iOS bug.  See https://devforums.apple.com/message/857939#857939
    [sheet addButtonWithTitle:kCancelButtonText];
    sheet.cancelButtonIndex = sheet.numberOfButtons - 1;

    CGRect rect = CGRectMake(screenpoint.x, screenpoint.y, 1, 1);
    [sheet showFromRect:rect inView:self.mapView animated:NO];
}

//called by map touch and action sheet
- (void)addFeature:(ProtocolFeature *)feature atMapPoint:(AGSPoint *)mapPoint
{
    Observation *observation = [self.survey createObservation:feature atMapLocation:mapPoint];
    AGSGraphic *graphic = [self.survey drawObservation:observation];
    [self setAttributesForFeatureType:feature entity:observation graphic:graphic defaults:nil atPoint:mapPoint  isNew:YES isEditing:YES];
}

//called by map touch
- (void)presentAGSFeatureSelector:(NSDictionary *)features atMapPoint:(AGSPoint *)mapPoint
{
    FeatureSelectorTableViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"FeatureSelectorTableViewController"];
    vc.features = features;
    vc.featureSelectedCallback = ^(NSString *layerName, id<AGSFeature> graphic) {
        [self presentFeature:graphic fromLayer:layerName atMapPoint:mapPoint];
        //dismiss popover?
    };
    //TODO: reduce popover size
    self.featureSelectorPopoverController = [[UIPopoverController alloc] initWithContentViewController:vc];
    [self.featureSelectorPopoverController presentPopoverFromMapPoint:mapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
    self.popoverMapPoint = mapPoint;
}

//called by map touch and feature selector popover
- (void)presentFeature:(id<AGSFeature>)agsFeature fromLayer:(NSString *)layerName atMapPoint:(AGSPoint *)mapPoint
{
    NSDate *timestamp = (NSDate *)[agsFeature safeAttributeForKey:kTimestampKey];

    AKRLog(@"Presenting feature for layer %@ with timestamp %@", layerName, timestamp);

    //NOTE: entityNamed:atTimestamp: only works with layers that have a gpspoint or an adhoc, so missionProperties and Observations
    //NOTE: gpsPoints do not have a QuickDialog definition; tracklogs would need to use the related missionProperty
    //TODO: expand to work on gpsPoints and tracklog segments
    if (![self.survey isSelectableLayerName:layerName]) {
        AKRLog(@"  Bailing. layer type is not supported");
    }

    //get the feature type from the layername
    ProtocolFeature * feature = [self.survey protocolFeatureFromLayerName:layerName];

    //get entity using the timestamp on the layername and the timestamp on the AGS Feature
    NSManagedObject *entity = [self.survey entityOnLayerNamed:layerName atTimestamp:timestamp];

    if (!feature || !entity) {
        AKRLog(@"  Bailing. Could not find the dialog configuration, and/or the feature");
        return;
    }

    //TODO: When do I implement readonly features
    [self setAttributesForFeatureType:feature entity:entity graphic:(AGSGraphic *)agsFeature defaults:entity atPoint:mapPoint isNew:NO isEditing:YES];
}




#pragma mark - Private Methods - misc support for data model

- (void)showTrackLogAttributeEditor:(TrackLogSegment *)tracklog
{
    NSManagedObject *entity = tracklog.missionProperty;
    NSManagedObject *template = tracklog.missionProperty;
    ProtocolFeature *feature = self.survey.protocol.missionFeature;
    AGSPoint *mapPoint = [tracklog.missionProperty pointOfMissionPropertyWithSpatialReference:self.mapView.spatialReference];
    [self setAttributesForFeatureType:feature entity:entity graphic:nil defaults:template atPoint:mapPoint isNew:YES isEditing:YES];
}

- (void)showMissionPropertyAttributeEditor:(MissionProperty *)missionProperty
{
    NSManagedObject *entity = missionProperty;
    NSManagedObject *template = missionProperty;
    ProtocolFeature *feature = self.survey.protocol.missionFeature;
    AGSPoint *mapPoint = [missionProperty pointOfMissionPropertyWithSpatialReference:self.mapView.spatialReference];
    [self setAttributesForFeatureType:feature entity:entity graphic:nil defaults:template atPoint:mapPoint isNew:YES isEditing:YES];
}


- (void)setAttributesForFeatureType:(ProtocolFeature *)feature entity:(NSManagedObject *)entity graphic:(AGSGraphic *)graphic defaults:(NSManagedObject *)template atPoint:(AGSPoint *)mapPoint isNew:(BOOL)isNew isEditing:(BOOL)isEditing
{
    //TODO: refactor this ugly and overly complicated method

    //TODO: can we support observations that have no attributes (no dialog)?
    //TODO: if I can't edit, then I should change the behavior of the controls on the form to reflect that

    //get data from entity attributes (unobscure the key names)
    NSMutableDictionary *data;
    if (template) {
        data = [[NSMutableDictionary alloc] init];
        for (NSAttributeDescription *attribute in feature.attributes) {
            NSString *cleanName = [attribute.name stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
            id value = [template valueForKey:attribute.name];
            if (value) {
                data[cleanName] = value;
            }
        }
        //AKRLog(@"default data attributes %@", data);
    }
    NSDictionary *config = feature.dialogJSON;
    //TODO: do not send data which might null out the radio buttons (some controls require a non-null default
    if (data.count == 0) {
        data = nil;
    }
    QRootElement *root = [[QRootElement alloc] initWithJSON:config andData:data];

    //TODO: if we are reviewing/editing an existing record, show the observing status

    //Show a Location Button only when editing/reviewing
    if (!isNew) {
        AngleDistanceLocation *angleDistanceLocation = [self.survey angleDistanceLocationFromEntity:entity];
        QButtonElement *locationButton = [[QButtonElement alloc] init];
        locationButton.appearance = [[QFlatAppearance alloc] init];
        locationButton.appearance.buttonAlignment = NSTextAlignmentCenter;
        //TODO: self.view.tintColor is gray after feature selector ViewControllers
        locationButton.appearance.actionColorEnabled = self.view.tintColor;
        if (angleDistanceLocation) {
            locationButton.title = @"Change Location";
            locationButton.onSelected = ^(){
                [self performAngleDistanceSequeWithFeature:feature entity:entity graphic:graphic];
            };
        } else {
            locationButton.title = @"Review Location";
            locationButton.onSelected = ^(){
                GpsPointTableViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"GpsPointTableViewController"];
                vc.gpsPoint = [self.survey gpsPointFromEntity:entity];
                vc.adhocLocation = [self.survey adhocLocationFromEntity:entity];
                CGSize contentSize = self.editAttributePopoverController ? self.editAttributePopoverController.popoverContentSize : self.reviewAttributePopoverController.popoverContentSize;
                vc.preferredContentSize = contentSize;
                [self.modalAttributeCollector pushViewController:vc animated:YES];
            };
        }
        [[root.sections lastObject] addElement:locationButton];
    }

    //Show a "move to GPS button" if:
    //  We have a GPS location (assumed to be recent)
    //  This is an observation feature that:
    //    allows GPS locations
    //    has an ad-hoc location
    if (self.locationServicesAvailable && self.survey.isRecording) {
        Observation *observation = [self.survey observationFromEntity:entity];
        if (observation) {
            WaysToLocateFeature options = feature.allowedLocations.nonTouchChoices;
            if ((options & LocateFeatureWithGPS) == LocateFeatureWithGPS) {
                if (observation.adhocLocation) {
                    QButtonElement *updateLocationButton = [[QButtonElement alloc] init];
                    updateLocationButton.appearance = [[QFlatAppearance alloc] init];
                    updateLocationButton.appearance.buttonAlignment = NSTextAlignmentCenter;
                    updateLocationButton.appearance.actionColorEnabled = self.view.tintColor;
                    updateLocationButton.title = @"Move to GPS Location";
                    updateLocationButton.onSelected = ^(){
                        //Note: add new gps point, but do not remove the adhoc location as that records the time of the observation
                        observation.gpsPoint = [self.survey addGpsPointAtLocation:self.locationManager.location];
                        if (observation.gpsPoint && graphic) {
                            [[graphic layer] removeGraphic:graphic];
                            [self.survey drawObservation:observation];
                        }
                    };
                    [[root.sections lastObject] addElement:updateLocationButton];
                }
            }
        }
    }


    //Delete/Cancel Button
    //TODO: support delete/cancel on a mission property
    if (![feature isKindOfClass:[ProtocolMissionFeature class]]) {
        NSString *buttonText = isNew ? @"Cancel" : @"Delete";
        QButtonElement *deleteButton = [[QButtonElement alloc] initWithTitle:buttonText];
        deleteButton.appearance = [[QFlatAppearance alloc] init];
        deleteButton.appearance.buttonAlignment = NSTextAlignmentCenter;
        if (!isNew) {
            deleteButton.appearance.actionColorEnabled = [UIColor redColor];
        } else {
            //TODO: self.view.tintColor is gray after Angle/Distance
            deleteButton.appearance.actionColorEnabled = self.view.tintColor;
        }
        deleteButton.onSelected = ^(){
            [[self.survey graphicsLayerForFeature:feature] removeGraphic:graphic];
            [self.survey deleteEntity:entity];
            [self.editAttributePopoverController dismissPopoverAnimated:YES];
            self.editAttributePopoverController = nil;
        };
        [[root.sections lastObject] addElement:deleteButton];
    }


    AttributeViewController *dialog = [[AttributeViewController alloc] initWithRoot:root];
    dialog.managedObject = entity;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.modalAttributeCollector = [[UINavigationController alloc] initWithRootViewController:dialog];
        dialog.resizeWhenKeyboardPresented = NO; //because the popover I'm in will resize
        UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:self.modalAttributeCollector];
        popover.delegate = self;
        if (isEditing) {
            self.editAttributePopoverController = popover;
        } else {
            self.reviewAttributePopoverController = popover;
        }
        [popover presentPopoverFromMapPoint:mapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        self.popoverMapPoint = mapPoint;
    } else {
        //TODO: test behavior for iPhone idiom
        self.modalAttributeCollector = [[UINavigationController alloc] initWithRootViewController:dialog];
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(saveAttributes:)];
        dialog.toolbarItems = @[doneButton];
        self.modalAttributeCollector.toolbarHidden = NO;
        self.modalAttributeCollector.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:self.modalAttributeCollector animated:YES completion:nil];
    }
}

// Called when editing popover is dismissed (or maybe when save/done button is tapped)
- (void)saveAttributes:(UIBarButtonItem *)sender
{
    AKRLog(@"Saving attributes from the recently dismissed modalAttributeCollector VC");
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    AttributeViewController *dialog = [self.modalAttributeCollector.viewControllers firstObject];
    [dialog.root fetchValueUsingBindingsIntoObject:dict];
    NSManagedObject *obj = dialog.managedObject;
    @try {
        for (NSString *aKey in dict){
            //This will throw an exception if the key is not valid. This will only happen with a bad protocol file - catch problem in testing, or protocol load
            NSString *obscuredKey = [NSString stringWithFormat:@"%@%@",kAttributePrefix,aKey];
            //AKRLog(@"Saving Attributes from Dialog key:%@ (%@) Value:%@", aKey, obscuredKey, [dict valueForKey:aKey]);
            [obj setValue:[dict valueForKey:aKey] forKey:obscuredKey];
        }
    }
    @catch (NSException *ex) {
        NSString *msg = [NSString stringWithFormat:@"%@\nCheck the protocol file.", ex.description];
        [[[UIAlertView alloc] initWithTitle:@"Save Failed" message:msg delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
    }
    //[self.modalAttributeCollector dismissViewControllerAnimated:YES completion:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
    self.modalAttributeCollector = nil;
}




#pragma mark - AngleDistance popover for feature editing

//Called programatically by feature bar button when creating a new Angle/Distance observation
- (void) performAngleDistanceSequeWithFeature:(ProtocolFeature *)feature fromButton:(UIBarButtonItem *)button
{
    if (self.angleDistancePopoverController) {
        [self.angleDistancePopoverController dismissPopoverAnimated:YES];
        self.angleDistancePopoverController = nil;
        return;
    }

    GpsPoint *gpsPoint = [self.survey addGpsPointAtLocation:self.locationManager.location];
    if (!gpsPoint) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to get current location for Angle/Distance." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        return;
    }
    
    LocationAngleDistance *location = nil;
    if (0 <= gpsPoint.course) {
        location = [[LocationAngleDistance alloc] initWithDeadAhead:gpsPoint.course protocolFeature:feature];
    } else {
        double currentHeading = self.locationManager.heading.trueHeading;
        if (0 <= currentHeading) {
            location = [[LocationAngleDistance alloc] initWithDeadAhead:currentHeading protocolFeature:feature];
        }
    }
    if (!location) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to get current course/heading for Angle/Distance." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        return;
    }

    AngleDistanceViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"AngleDistanceViewController"];
    vc.location = location;
    vc.completionBlock = ^(AngleDistanceViewController *controller) {
        self.angleDistancePopoverController = nil;
        AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
        Observation *observation = [self.survey createObservation:feature atGpsPoint:gpsPoint withAngleDistanceLocation:controller.location];
        AGSGraphic *graphic = [self.survey drawObservation:observation];
        [self setAttributesForFeatureType:feature entity:observation graphic:graphic defaults:nil atPoint:mapPoint isNew:YES isEditing:YES];
    };
    vc.cancellationBlock = ^(AngleDistanceViewController *controller) {
        self.angleDistancePopoverController = nil;
    };

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        self.angleDistancePopoverController = [[UIPopoverController alloc] initWithContentViewController:nav];
        vc.popover = self.angleDistancePopoverController;
        vc.popover.delegate = self;
        [self.angleDistancePopoverController presentPopoverFromBarButtonItem:button permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self.navigationController pushViewController:vc animated:YES];
    }
}

// This is called by the feature editor (setAttributesForFeatureType:), when the user wants to edit the Angle/Distance of an observation.
- (void) performAngleDistanceSequeWithFeature:(ProtocolFeature *)feature entity:(NSManagedObject *)entity graphic:(AGSGraphic *)graphic
{
    UINavigationController *nav = self.navigationController;
    if (!nav) {
        nav = (UINavigationController *)[self.editAttributePopoverController contentViewController];
    }
    AngleDistanceLocation *angleDistance = [self.survey angleDistanceLocationFromEntity:entity];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:angleDistance.direction protocolFeature:feature absoluteAngle:angleDistance.angle distance:angleDistance.distance];;
    AngleDistanceViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"AngleDistanceViewController"];
    vc.location = location;
    vc.completionBlock = ^(AngleDistanceViewController *controller) {
        self.angleDistancePopoverController = nil;
        Observation *observation = [self.survey observationFromEntity:entity];
        [self.survey updateAngleDistanceObservation:observation withAngleDistance:controller.location];
        [[graphic layer] removeGraphic:graphic];
        [self.survey drawObservation:observation];
        [nav popViewControllerAnimated:YES];
    };
    vc.cancellationBlock = ^(AngleDistanceViewController *controller) {
        [nav popViewControllerAnimated:YES];
    };

    [nav pushViewController:vc animated:YES];
}




#pragma mark - Private Methods - support for data model - gps points

- (AGSPoint *)mapPointFromGpsPoint:(GpsPoint *)gpsPoint
{
    return [gpsPoint pointOfGpsWithSpatialReference:self.mapView.spatialReference];
}

@end
