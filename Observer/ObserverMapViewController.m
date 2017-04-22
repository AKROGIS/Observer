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
#import "GpsPointTableViewController.h"

//Views
#import "AutoPanButton.h"
#import "AddFeatureBarButtonItem.h"
#import "AGSMapView+AKRAdditions.h"

//Support Model Objects
#import "AutoPanStateMachine.h"
#import "Survey+CsvExport.h"
#import "NSDate+Formatting.h"

//Support sub-system
#import "AKRLog.h"
#import "CommonDefines.h"
#import "GpsPoint.h"
#import "GpsPoint+Location.h"
#import "MissionProperty.h"
#import "MissionProperty+Location.h"
#import "POGraphic.h"
#import "Settings.h"
#import "QuickDialog.h"

//Constants and Magic Numbers/Strings
#define kOKButtonText              NSLocalizedString(@"OK", @"OK button text")
#define kCancelButtonText          NSLocalizedString(@"Cancel", @"Cancel button text")


#include <tgmath.h>  //replaces math.h with Type Generic Math, allows parameters/returns to be CGFloat (float or double)


@interface ObserverMapViewController () {
    double _initialRotationOfViewAtGestureStart;
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
@property (strong, nonatomic) IBOutlet UIBarButtonItem *editEnvironmentBarButton;

@property (strong, nonatomic) NSMutableArray *addFeatureBarButtonItems;  //NSArray of AddFeatureBarButtonItem

@property (weak, nonatomic) IBOutlet UILabel *statusMessage;
@property (weak, nonatomic) IBOutlet UILabel *totalizerMessage;

@property (weak, nonatomic) IBOutlet UIView *scalebar;
@property (weak, nonatomic) IBOutlet UILabel *scalebarEndLabel;

//Support
@property (nonatomic) int  busyCount;
@property (nonatomic, readonly) BOOL locationServicesAvailable;
@property (nonatomic) BOOL userWantsLocationUpdates;
@property (nonatomic) BOOL userWantsHeadingUpdates;
@property (nonatomic) BOOL gpsFailed;

@property (strong, nonatomic) AutoPanStateMachine *autoPanController;
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) id<AGSFeature> movingGraphic;  //maintain state between AGSMapViewTouchDelegate calls
@property (strong, nonatomic) Observation *movingObservation;  //maintain state between AGSMapViewTouchDelegate calls
@property (strong, nonatomic) MissionProperty *movingMissionProperty;  //maintain state between AGSMapViewTouchDelegate calls

//Simplify dealing with the presentation, push/pop, dismissal of the VC (it will be embedded in a UINavigationController
@property (strong, nonatomic) AttributeViewController *attributeCollector;

@end



@implementation ObserverMapViewController

#pragma mark - Super class overrides

- (void)viewDidLoad
{
    //AKRLog(@"Main view controller view did load");
    [super viewDidLoad];
    [self configureMapView];
    [self requestLocationServices];
    [self configureGpsButton];
    [self removeMissionPropertiesButton];
    [self configureObservationButtons];
    [self openMap:self.map];  // open in map setter may fail if the view isn't ready.
    [self openSurvey:self.survey];  // open in survey setter may fail if the view isn't ready.
    self.statusMessage.text = nil;
    self.totalizerMessage.text = nil;
    //Register map pan and zoom notifications for scale bar
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateScaleBar) name:AGSMapViewDidEndZoomingNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    //Always check when view did appear, user may have changed the settings
    [self requestAuthorizationForAlwaysOnLocationServices];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    // There can only be one modal displayed at a time, so close any alerts or popovers.
    // The users's action that triggered the segue is an implied dismissal of the alert/popover
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    //auto-save current survey in case user wants to mail or export it;  This will likely be in a new context
    //ignore the callback; because we can assume the auto-save will be done before the users gets that far
    //I might not have a survey or an open document, which would be ok, as there would be no need to save
    [self.survey.document autosaveWithCompletionHandler:nil];
    id vc1 = [segue destinationViewController];
    if([vc1 isKindOfClass:[UINavigationController class]])
    {
        vc1 = ((UINavigationController *)vc1).viewControllers.firstObject;
    }
    if([vc1 isKindOfClass:[UITabBarController class]])
    {
        vc1 = ((UITabBarController *)vc1).selectedViewController;
    }
    if ([segue.identifier isEqualToString:@"Select Survey"]){
        SurveySelectViewController *vc = (SurveySelectViewController *)vc1;
        vc.title = segue.identifier;
        __weak ObserverMapViewController *weakSelf = self;
        vc.surveySelectedAction = ^(Survey *survey){
            ObserverMapViewController *me = weakSelf;
            [me dismissViewControllerAnimated:YES completion:nil];
            me.survey = survey;
        };
        vc.surveyUpdatedAction = ^(Survey *survey){
            if ([survey isEqualToSurvey:self.survey]) {
                ObserverMapViewController *me = weakSelf;
                me.survey.title = survey.title;
                [me updateTitleBar];
            }
        };
        vc.surveyDeletedAction = ^(Survey *survey){
            if ([survey isEqualToSurvey:self.survey]) {
                weakSelf.survey = nil;
            };
        };
        return;
    }

    if ([segue.identifier isEqualToString:@"Select Map"]) {
        MapSelectViewController *vc = (MapSelectViewController *)vc1;
        vc.title = segue.identifier;
        __weak ObserverMapViewController *weakSelf = self;
        vc.mapSelectedAction = ^(Map *map){
            ObserverMapViewController *me = weakSelf;
            [me dismissViewControllerAnimated:YES completion:nil];
            me.map = map;
        };
        vc.mapDeletedAction = ^(Map *map){
            //map is the map that was deleted
            ObserverMapViewController *me = weakSelf;
            if ([me.map isEqualToMap:map]) {
                me.map = nil;
            };
        };
        return;
    }
}




#pragma mark - IBActions

// I'm doing the rotation myself, instead of using self.mapView.allowRotationByPinching = YES
// because I need to sync it with the compass rose,
// but the real problem was the mapView was missing some gestures, and capturing some I didn't get
- (IBAction)rotateMap:(UIRotationGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self.autoPanController userRotatedMap];
        _initialRotationOfViewAtGestureStart = (double)atan2(self.compassRoseButton.transform.b, self.compassRoseButton.transform.a);
    }
    double radians = _initialRotationOfViewAtGestureStart + (double)sender.rotation;
    double degrees = radians * (180 / M_PI);
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
        AKRLog(@"Whaaaat ... How did I try to start recording when I am already recording?");
        return;
    }
    if(!self.mapView.loaded) {
        AKRLog(@"Whaaaat ... How did I try to start recording when I don't have a map?");
        return;
    }
    if(!self.survey.isReady) {
        AKRLog(@"Whaaaat ... How did I try to start recording when I don't have a survey?");
        return;
    }
    CLLocation *location = self.mostRecentLocation;
    if (!location.timestamp) {
        [self showNoLocationAlert];
        return;
    }
    if(![self.survey startRecording:location]) {
        [self alert:nil message:@"Unable to start recording.  Please try again."];
        return;
    }
    [self showTrackLogAttributeEditor:self.survey.lastTrackLogSegment];
    self.startStopRecordingBarButtonItem = [self setBarButtonAtIndex:5 action:@selector(stopRecording:) ToPlay:NO];
    [self enableControls];
    [self startLocationUpdates];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (IBAction)startObserving:(UIBarButtonItem *)sender
{
    if (self.survey.isObserving || !self.survey.isRecording) {
        AKRLog(@"Whaaaat ... How did I try to start observing when I am not ready?");
        return;
    }
    CLLocation *location = self.mostRecentLocation;
    if (!location.timestamp) {
        [self showNoLocationAlert];
        return;
    }
    TrackLogSegment *tracklog = [self.survey startObserving:location];
    [self showTrackLogAttributeEditor:tracklog];
    self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:7 action:@selector(stopObserving:) ToPlay:NO];
    [self enableControls];
}

- (IBAction)changeEnvironment:(UIBarButtonItem *)sender
{
    if (self.survey.isRecording) {
        CLLocation *location = self.mostRecentLocation;
        if (!location.timestamp) {
            [self showNoLocationAlert];
            return;
        }
        TrackLogSegment *tracklog = [self.survey startNewTrackLogSegment:location];
        [self showTrackLogAttributeEditor:tracklog];
    } else {
        AKRLog(@"Unsupported code path.  Mission Properties without GPS points are not supported");
        //TODO: #181 Evaluate the need, and support or remove this code
        MissionProperty *missionProperty = [self.survey createMissionPropertyAtMapLocation:self.mapView.mapAnchor];
        [self showMissionPropertyAttributeEditor:missionProperty];
    }
}


#pragma mark - Actions wired up programatically

- (void)stopRecording:(UIBarButtonItem *)sender
{
    if (!self.survey.isRecording) {
        AKRLog(@"Whaaaat ... How did I try to stop recording when I am not recording?");
        return;
    }
    BOOL wasObserving = self.survey.isObserving;
    CLLocation *location = self.mostRecentLocation;
    [self stopLocationUpdates];
    [self.survey stopRecording:location]; //Stops observing
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    if (wasObserving) {
        self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:7 action:@selector(startObserving:) ToPlay:YES];
    }
    self.startStopRecordingBarButtonItem = [self setBarButtonAtIndex:5 action:@selector(startRecording:) ToPlay:YES];
    [self enableControls];
    self.totalizerMessage.text = nil;
}

- (void)stopObserving:(UIBarButtonItem *)sender
{
    if (!self.survey.isObserving) {
        AKRLog(@"Whaaaat ... How did I try to stop observing when I am not observing?");
        return;
    }
    CLLocation *location = self.mostRecentLocation;
    if (!location.timestamp) {
        [self showNoLocationAlert];
        return;
    }
    [self.survey stopObserving:location];
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
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *choiceText in [ProtocolFeatureAllowedLocations stringsForLocations:feature.allowedLocations.nonTouchChoices]) {
        UIAlertAction *locateChoice = [UIAlertAction actionWithTitle:choiceText
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * action){
                                                                 WaysToLocateFeature locationMethod = [ProtocolFeatureAllowedLocations locationMethodForName:choiceText];
                                                                 feature.preferredLocationMethod = locationMethod;
                                                                 [self addFeature:feature withNonTouchLocationMethod:locationMethod];
                                                             }];
        [actionSheet addAction:locateChoice];
    }
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kCancelButtonText style:UIAlertActionStyleCancel handler:nil];
    [actionSheet addAction:cancelAction];
    // Present the action sheet in a popover at the button
    actionSheet.modalPresentationStyle = UIModalPresentationPopover;
    [self presentViewController:actionSheet animated:YES completion:nil];
    UIPopoverPresentationController *popover = actionSheet.popoverPresentationController;
    popover.barButtonItem = button;
}




#pragma mark - Public Interface

- (void)setSurvey:(Survey *)survey
{
    if ([survey isEqualToSurvey:_survey]) {
        return;
    }
    if (survey == nil && _survey == nil) {  //[nil isEqualToSurvey:nil] returns false in check above, but we want true.
        return;
    }
    [self closeSurvey:_survey];
    _survey = survey;
    [self openSurvey:survey];
    [Settings manager].activeSurveyURL = survey.url;
}

- (void)setMap:(Map *)map
{
    if ([map isEqualToMap:_map]) {
        return;
    }
    if (map == nil && _map == nil) {  //[nil isEqualToMap:nil] returns false in check above, but we want true.
        return;
    }
    [self closeMap:_map];
    _map = map;
    [self openMap:map];
    [Settings manager].activeMapPropertiesURL = map.plistURL;
}




#pragma mark - Delegate Methods: UIPopoverPresentationControllerDelegate

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController
{
    //Only the attribute collector is using PopoverPresentationController delegate
    [self saveAttributes];
}




#pragma mark - Delegate Methods: CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    //AKRLog(@"locationManager: didUpdateLocations:%@",locations);
    if (self.survey.isRecording) {
        for (CLLocation *location in locations) {
            [self.survey maybeAddGpsPointAtLocation:location];
        }
        self.totalizerMessage.text = self.survey.totalizer.message;
    }

    //use the speed of the last location to update the autorotation behavior
    CLLocation *location = [locations lastObject];
    if (0 <= location.speed) {
        [self.autoPanController speedUpdate:location.speed];
    }

    if (self.gpsFailed) {
        self.gpsFailed = NO;
        [self enableControls];
        [self alert:nil message:@"@GPS is back!"];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    //AKRLog(@"locationManager: didUpdateHeading: %f",newHeading.trueHeading);
    [self rotateNorthArrow];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [self alert:@"Location Failure" message:error.localizedDescription];
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
    [self alert:nil message:@"Unable to load map"];
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

    AKRLog(@"mapView:didTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", (double)screen.x, (double)screen.y, mapPoint, features);
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
                        //TODO: #11 support moving mission properties
                        [self alert:nil message:@"Can't move mission properties yet."];
                        self.movingMissionProperty = nil;
                    }
                    if (self.movingObservation.angleDistanceLocation) {
                        //Moving Angle/Distance observations is done in the Angle/DistanceVC
                        [self alert:nil message:@"Can't move angle/distance features."];
                        self.movingObservation = nil;
                    }
                    if (self.movingObservation.gpsPoint) {
                        //Per Issue #69, Moving GPS Points is not a useful feature.
                        [self alert:nil message:@"Can't move GPS located features."];
                        self.movingObservation = nil;
                    }
                    if (self.movingMissionProperty || self.movingObservation) {
                        self.movingGraphic = feature;
                    }
                    break;
                }
                default:
                    [self alert:nil message:@"Zoom in to select a single feature."];
                    break;
            }
            break;
        }
        default:
            [self alert:nil message:@"Zoom in to select a single feature."];
            break;
    }
    AKRLog(@"moving %@",self.movingGraphic);
}

- (void)mapView:(AGSMapView *)mapView didMoveTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mapPoint features:(NSDictionary *)features
{
    //AKRLog(@"mapView:didMoveTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", screen.x, screen.y, mapPoint, features);

    //Only moving AdHoc locations, so they can go anywhere
    if (self.movingGraphic) {
        [self.movingGraphic setGeometry:mapPoint];
        if ([self.movingGraphic isKindOfClass:[POGraphic class]]) {
            [((POGraphic *)self.movingGraphic).label setGeometry:mapPoint];
        }
    }
}

- (void) mapView:(AGSMapView *)mapView didEndTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mapPoint features:(NSDictionary *)features
{
    AKRLog(@"mapView:didEndTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", (double)screen.x, (double)screen.y, mapPoint, features);

    //Move Adhoc location
    [self.survey updateAdhocLocation:self.movingObservation.adhocLocation withMapPoint:mapPoint];
    if ([self.movingGraphic isKindOfClass:[POGraphic class]]) {
        [(POGraphic *)self.movingGraphic redraw:self.movingObservation survey:self.survey];
    }

    //Move GPS location
    //Per Issue #69, Moving GPS Points is not a useful feature.

    //Move Mission Property
    //[self.survey updateAdhocLocation:self.movingMissionProperty.adhocLocation withMapPoint:mapPoint];
    //TODO: #11 if this was a mission property, then we need to update the tracklogs.

    self.movingObservation = nil;
    self.movingMissionProperty = nil;
    self.movingGraphic = nil;
}




#pragma mark - Alert Helper

- (void) alert:(NSString *)title message:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:kOKButtonText style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
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




#pragma mark - Private Properties

- (CLLocation *)mostRecentLocation
{
    //FIXME: #175 make sure that this is a current/good location
    return self.locationManager.location;
}

- (BOOL)locationServicesAvailable
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    BOOL authorized = (status == kCLAuthorizationStatusAuthorizedWhenInUse ||
                       status == kCLAuthorizationStatusAuthorizedAlways);

    return authorized;
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
    //Alert: calling the tilecache property may block for IO
    if (self.map.tileCache) {
        [self.mapView addMapLayer:self.map.tileCache withName:@"tilecache basemap"];
        //adding a layer is async. wait for AGSLayerDelegate layerDidLoad or layerDidFailToLoad to decrementBusy
    }
}

- (void)requestLocationServices
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
}

- (void)configureGpsButton
{
    self.autoPanController = [[AutoPanStateMachine alloc] init];
    self.autoPanController.mapView = self.mapView;
    self.autoPanController.compassRoseButton = self.compassRoseButton;
    self.autoPanController.autoPanModeButton = self.panButton;
}

- (void)addMissionPropertiesButton
{
    // Adds button at the end of the toolbar, so call before adding observation buttons
    if (![self.toolbar.items containsObject:self.editEnvironmentBarButton] &&
        self.survey.protocol.missionFeature.attributes.count > 0) {
        // self.toolbar.items is immutable, so we need to get a copy to change it
        NSMutableArray *toolbarButtons = [self.toolbar.items mutableCopy];
        [toolbarButtons addObject:self.editEnvironmentBarButton];
        [self.toolbar setItems:toolbarButtons animated:YES];
    }
}

- (void)removeMissionPropertiesButton
{
    if ([self.toolbar.items containsObject:self.editEnvironmentBarButton]) {
        // self.toolbar.items is immutable, so we need to get a copy to change it
        NSMutableArray *toolbarButtons = [self.toolbar.items mutableCopy];
        [toolbarButtons removeObject:self.editEnvironmentBarButton];
        [self.toolbar setItems:toolbarButtons animated:YES];
    }
}

- (void)configureObservationButtons
{
    NSMutableArray *toolbarButtons = [self.toolbar.items mutableCopy];
    //Remove any existing Add Feature buttons
    [toolbarButtons removeObjectsInArray:self.addFeatureBarButtonItems];

    [self.addFeatureBarButtonItems removeAllObjects];
    if (self.survey.protocol) {
        for (ProtocolFeature *feature in self.survey.protocol.features) {
            feature.allowedLocations.locationPresenter = self;
            if (feature.allowedLocations.countOfNonTouchChoices > 0) {
                //feature names (from protocol file) should be short enough to fit on a button
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
    // This is called by the Survey VC when editing to catch a name change of self.survey
    // It is also called by the completion handlers in close/open survey methods (called by viewDidLoad and setSurvey.
    // Using self.survey solves a problem where the close completion handler ends up on the main queue after open handler.
    // This must be called in handlers because open/close sets the self.selectSurveyButton.title to 'working...'
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

    self.startStopRecordingBarButtonItem.enabled = self.survey.isReady && self.mapView.loaded && self.locationServicesAvailable && !self.gpsFailed;
    self.startStopObservingBarButtonItem.enabled = self.survey.isRecording && !self.gpsFailed;
    self.editEnvironmentBarButton.enabled = self.survey.isRecording && self.survey.protocol.missionFeature.attributes.count > 0 && !self.gpsFailed;
    for (AddFeatureBarButtonItem *item in self.addFeatureBarButtonItems) {
        item.enabled = self.survey.isObserving && !self.gpsFailed;
    }
    [self updateStatusMessage];
}

- (void)updateStatusMessage
{
    //call this from map load; start/stop recording/observing  gps fail/recover (all the cases when enableControls is called)
    self.statusMessage.text = self.gpsFailed ? @"GPS Failed" : self.survey.statusMessage;
    if (self.survey.isRecording) {
        self.statusMessage.textColor = [UIColor colorWithWhite:(CGFloat)0.7 alpha:1];
    }
    if (self.survey.isObserving) {
        self.statusMessage.textColor = [UIColor colorWithRed:1.0 green:0.0 blue:0.5 alpha:1.0];
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

- (void)showNoLocationAlert
{
    //TODO: #175 provide more helpful error message.  Why can't I get the location?  What can the user do about it?
    //This is a low priority, since the buttons that activate this should not be enabled unless location services are available.
    [self alert:nil message:@"Unable to get your location.  Please try again later."];
}

- (void)requestAuthorizationForAlwaysOnLocationServices
{
    // Good reference: http://nevan.net/2014/09/core-location-manager-changes-in-ios-8/

    // ** Don't forget to add NSLocationAlwaysUsageDescription in Observer-Info.plist and give it a string

    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];

    //Ignore kCLAuthorizationStatusRestricted - location services turned off with Parental Restrictions; nothing we can do.

    // If the status is denied or only granted for when in use, display an alert
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusDenied) {
        NSString *title;
        title = (status == kCLAuthorizationStatusDenied) ? @"Location services are off" : @"Background location is not enabled";
        NSString *message = @"To make observations you must turn on 'Always' in the Location Services Settings";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *abortAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                              style:UIAlertActionStyleCancel
                                                            handler:nil];
        UIAlertAction *settingAction = [UIAlertAction actionWithTitle:@"Settings"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action){
                                                                  [self gotoSettings];
                                                              }];
        [alert addAction:abortAction];
        [alert addAction:settingAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
    // The user has not enabled any location services. Request background authorization.
    else if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestAlwaysAuthorization];
    }
}

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


- (void)updateScaleBar
{
    //Get length of ScaleBar
    CGPoint screenPointStart = CGPointMake(self.scalebar.frame.origin.x, self.scalebar.frame.origin.y);
    AGSPoint *mapPointStart = [self.mapView toMapPoint:screenPointStart];

    CGPoint screenPointEnd = CGPointMake(self.scalebar.frame.origin.x + self.scalebar.frame.size.width, self.scalebar.frame.origin.y);
    AGSPoint *mapPointEnd = [self.mapView toMapPoint:screenPointEnd];

    AGSGeometryEngine *ge = [AGSGeometryEngine defaultGeometryEngine];
    
    double distance = [ge distanceFromGeometry:mapPointStart toGeometry:mapPointEnd];
    //TODO: #146 respect SR of mapView, and Distance units from settings
    //   Or use a Google style scale bar with both SI/metric

    //FIXME: #146 scale is off by a factor of 2 (compared to west high track in image)
    distance = distance/2.0;

    if(distance > 10000) //10km
    {
        //show the labels in km
        self.scalebarEndLabel.text = [NSString stringWithFormat:@"%0.0f km", distance/1000];
    }
    else
    {
        //show the labels in meters
        self.scalebarEndLabel.text = [NSString stringWithFormat:@"%0.0f m", distance];
    }
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

- (void)closeMap:(Map *)map
{
    if (!self.isViewLoaded) {
        AKRLog(@"Cannot close the map becasue the view is not ready yet.");
        return;
    }
    if (!map) {
        AKRLog(@"Cannot close the map because none was provided.");
        return;
    }
    [self.mapView reset]; //removes all layers, clear SR, envelope, etc.
    [self.survey clearMap];
    [self.survey clearMapMapViewSpatialReference];
    self.noMapView.hidden = NO;
    self.panButton.enabled = NO;
}

- (void)openMap:(Map *)map
{
    if (!self.isViewLoaded) {
        AKRLog(@"Cannot open the map becasue the view is not ready yet.");
        return;
    }
    if (!map) {
        AKRLog(@"Cannot open the map because none was provided.");
        return;
    }
    AKRLog(@"Opening the map %@", map);
    //Alert: calling the tilecache property may block for IO
    if (map.tileCache)
    {
        [self incrementBusy];
        self.noMapView.hidden = YES;
        self.panButton.enabled = YES;
        self.map.tileCache.delegate = self;
        AKRLog(@"Loading the basemap %@", map);
        [self.mapView addMapLayer:map.tileCache withName:@"tilecache basemap"];
        //adding a layer is async. See AGSLayerDelegate layerDidLoad or layerDidFailToLoad for additional action taken when opening a map
    } else {
        [self alert:nil message:@"Unable to open the map."];
    }
}

- (void)setupGPS
{
    self.mapView.locationDisplay.navigationPointHeightFactor = 0.5;
    self.mapView.locationDisplay.wanderExtentFactor = 0.0;
    [self.mapView.locationDisplay startDataSource];
    [self startStopLocationServicesForPanMode];
}

- (void)loadGraphics
{
    if (!self.survey.isReady) {
        AKRLog(@"Cannot load graphics because the survey isn't ready yet");
        return;
    }
    if (!self.mapView.loaded) {
        AKRLog(@"Cannot load graphics because the map isn't loaded yet");
        return;
    }
    [self.survey setMap:self.map];
    [self.survey setMapViewSpatialReference:self.mapView.spatialReference];
    [self initializeGraphicsLayer];
    [self.survey loadGraphics];
}

- (void)initializeGraphicsLayer
{
    NSDictionary *graphicsLayers = [self.survey graphicsLayersByName];
    NSString *onTransect = [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOn];
    NSString *offTransect = [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOff];
    //Draw these layers first and in this order
    NSArray *lowerLayers = @[onTransect, offTransect, kGpsPointEntityName, kMissionPropertyEntityName, kLabelLayerName];
    for (NSString *name in lowerLayers) {
        [self.mapView addMapLayer:graphicsLayers[name] withName:name];
    }
    // Draw the remaining layers (observations) in any order
    NSMutableArray *layerNames = [NSMutableArray arrayWithArray:[graphicsLayers allKeys]];
    [layerNames removeObjectsInArray:lowerLayers];
    for (NSString *name in layerNames) {
        [self.mapView addMapLayer:graphicsLayers[name] withName:name];
    }
}




#pragma mark - Private Methods - support for data model - Surveys

- (void)closeSurvey:(Survey *)survey
{
    if (!self.isViewLoaded) {
        AKRLog(@"Cannot close the survey because the view isn't loaded yet");
        return;
    }
    if (!survey) {
        AKRLog(@"Cannot close the survey, because there is none");
        return;
    }
    if (survey.document.documentState != UIDocumentStateNormal) {
        AKRLog(@"Survey (%@) is in an abnormal state: %lu", survey.title, (unsigned long)survey.document.documentState);
        //There is really nothing I can do but continue...
    }
    AKRLog(@"Closing survey document (%@)", survey.title);
    [self incrementBusy];  //closing the survey document may block
    self.selectSurveyButton.title = @"Closing survey...";
    if (survey.isRecording) {
        [self stopRecording:nil];
    }
    [self.mapView clearGraphicsLayers];
    [survey closeDocumentWithCompletionHandler:^(BOOL success) {
        //this completion handler runs on the main thread;
        if (!success) {
            AKRLog(@"Survey (%@) failed to close", survey.title);
            //There is really nothing I can do but continue...
        }
        [self removeMissionPropertiesButton];
        [self configureObservationButtons];
        [self updateTitleBar];
        [self decrementBusy];
    }];
}

- (void)openSurvey:(Survey *)survey
{
    if (!self.isViewLoaded) {
        AKRLog(@"Cannot open the survey because the view isn't loaded yet");
        return;
    }
    if (!survey) {
        AKRLog(@"Cannot open the survey, because there is none");
        return;
    }
    AKRLog(@"Opening survey document (%@)", self.survey.title);
    [self incrementBusy];
    self.selectSurveyButton.title = @"Loading survey...";
    [self.survey openDocumentWithCompletionHandler:^(BOOL success) {
        //do any other background work;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
                [self alert:nil message:@"Unable to open the survey."];
            } else {
                [self loadGraphics];
            }
            [self addMissionPropertiesButton];
            [self configureObservationButtons];
            [self updateTitleBar];
            [self decrementBusy];
        });
    }];
}

- (void)gotoSettings
{
    [self openScheme:UIApplicationOpenSettingsURLString];
}

- (void)openScheme:(NSString *)scheme {
    UIApplication *application = [UIApplication sharedApplication];
    NSURL *URL = [NSURL URLWithString:scheme];
    if ([application respondsToSelector:@selector(openURL:options:completionHandler:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
        //iOS 10.0+
        [application openURL:URL options:@{} completionHandler:^(BOOL success) {
            NSLog(@"Open %@: %d", scheme, success);
        }];
#pragma clang diagnostic pop
    } else {
        //iOS < 10
        BOOL success = [application openURL:URL];
        NSLog(@"Open %@: %d",scheme,success);
    }
}





//TODO: #183 Cleanup the following code








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
        case LocateFeatureWithMapTouch:
        case LocateFeatureUndefined:
            AKRLog(@"Location method (%lu) specified is not valid",(unsigned long)locationMethod);
    }
}

- (void)addFeatureAtGps:(ProtocolFeature *)feature
{
    CLLocation *location = self.mostRecentLocation;
    if (!location.timestamp) {
        [self showNoLocationAlert];
        return;
    }
    GpsPoint *gpsPoint = [self.survey addGpsPointAtLocation:location];
    Observation *observation = [self.survey createObservation:feature atGpsPoint:gpsPoint];
    AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
    AGSGraphic *graphic = [self.survey drawObservation:observation];
    [self setAttributesForFeatureType:feature entity:observation graphic:graphic defaults:nil atPoint:mapPoint isNew:YES isEditing:YES];
}

- (void)addFeatureAtAngleDistance:(ProtocolFeature *)feature
{
    //Find the bar button item with the feature to attach the popover.
    AddFeatureBarButtonItem *button = nil;
    for (AddFeatureBarButtonItem *item in self.addFeatureBarButtonItems) {
        if (item.feature == feature) {
            button = item;
            break;
        }
    }
    if (button) {
        // It is not possible (AFIK) to set the anchor for a manual popover seque, hence I must do the "segue" with code
        //TODO: #144 Use the uipopoverpresentationcontrollerdelegate prepareForPopoverPresentation
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
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    [features enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *choiceText = ((ProtocolFeature *)obj).name;
        UIAlertAction *featureChoice = [UIAlertAction actionWithTitle:choiceText
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action){
                                                                  __block ProtocolFeature *actionFeature = nil;
                                                                  [self.survey.protocol.featuresWithLocateByTouch enumerateObjectsUsingBlock:^(id obj2, NSUInteger idx2, BOOL *stop2) {
                                                                      if ([choiceText isEqualToString:((ProtocolFeature *)obj2).name]) {
                                                                          *stop2 = YES;
                                                                          actionFeature = obj2;
                                                                      }
                                                                  }];
                                                                  if (actionFeature) {
                                                                      [self addFeature:actionFeature atMapPoint:mapPoint];
                                                                  } else {
                                                                      AKRLog(@"Oh No!, Selected feature not found in survey protocol");
                                                                  }
                                                              }];
        [actionSheet addAction:featureChoice];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kCancelButtonText style:UIAlertActionStyleCancel handler:nil];
    [actionSheet addAction:cancelAction];
    // Present the action sheet in a popover at the feature's screen point in the mapview
    actionSheet.modalPresentationStyle = UIModalPresentationPopover;
    [self presentViewController:actionSheet animated:YES completion:nil];
    UIPopoverPresentationController *popover = actionSheet.popoverPresentationController;
    popover.sourceView = self.mapView;
    popover.sourceRect = CGRectMake(screenpoint.x, screenpoint.y, 1, 1);
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
    vc.protocol = self.survey.protocol;
    vc.featureSelectedCallback = ^(NSString *layerName, id<AGSFeature> graphic) {
        //TODO: 185 a better solution would be to put this inside a navigation view controller inside the popover
        [self dismissViewControllerAnimated:YES completion:nil];
        [self presentFeature:graphic fromLayer:layerName atMapPoint:mapPoint];
    };
    //TODO: #168 reduce popover size
    vc.modalPresentationStyle = UIModalPresentationPopover;
    [self presentViewController:vc animated:YES completion:nil];
    UIPopoverPresentationController *popover = vc.popoverPresentationController;
    popover.sourceView = self.mapView;
    CGPoint screenPoint = [self.mapView nearestScreenPoint:mapPoint];
    popover.sourceRect = CGRectMake(screenPoint.x, screenPoint.y, 1, 1);
}

//called by map touch and feature selector popover
- (void)presentFeature:(id<AGSFeature>)agsFeature fromLayer:(NSString *)layerName atMapPoint:(AGSPoint *)mapPoint
{
    NSDate *timestamp = (NSDate *)[agsFeature safeAttributeForKey:kTimestampKey];

    AKRLog(@"Presenting feature for layer %@ with timestamp %@", layerName, timestamp);

    //NOTE: entityNamed:atTimestamp: only works with layers that have a gpspoint or an adhoc, so missionProperties and Observations
    //NOTE: gpsPoints do not have a QuickDialog definition; tracklogs would need to use the related missionProperty
    //TODO: #184 expand to work on gpsPoints and tracklog segments
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

    [self setAttributesForFeatureType:feature entity:entity graphic:(AGSGraphic *)agsFeature defaults:entity atPoint:mapPoint isNew:NO isEditing:YES];
}




#pragma mark - Private Methods - misc support for data model

- (void)showTrackLogAttributeEditor:(TrackLogSegment *)tracklog
{
    if (self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
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
    //TODO: #183 Cleanup, isEditing parameter is never used. We always allow editing. Callers all use YES
    //TODO: #183 refactor this ugly and overly complicated method

    //TODO: #53 can we support observations that have no attributes (no dialog)?

    //get data from entity attributes (unobscure the key names)
    NSMutableDictionary *data;
    if (template || entity) {
        data = [[NSMutableDictionary alloc] init];
        for (NSAttributeDescription *attribute in feature.attributes) {
            NSString *cleanName = [attribute.name stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
            // Use value provided by entity, else use template
            id value = [entity valueForKey:attribute.name];
            if (value) {
                data[cleanName] = value;
            } else {
                value = [template valueForKey:attribute.name];
                if (value) {
                    data[cleanName] = value;
                }
            }
        }
        //AKRLog(@"default data attributes %@", data);
    }
    NSDictionary *config = feature.dialogJSON;
    //TODO: #53 do not send data which might null out the radio buttons (some controls require a non-null default).
    if (data.count == 0) {
        data = nil;
    }
    QRootElement *root = [[QRootElement alloc] initWithJSON:config andData:data];

    id maybeDate = [entity valueForKeyPath:@"adhocLocation.timestamp"];
    if (!maybeDate) {
        maybeDate = [entity valueForKeyPath:@"gpsPoint.timestamp"];
    }
    if ([maybeDate isKindOfClass:[NSDate class]]) {
        NSDate *timestamp = (NSDate *)maybeDate;
        if (feature.hasUniqueId) {
            root.title = [NSString stringWithFormat:@"%@ %@", root.title, [entity valueForKey:feature.uniqueIdName]];
        } else {
            root.title = [NSString stringWithFormat:@"%@ @ %@", root.title, [timestamp stringWithMediumTimeFormat]];
        }
        QLabelElement *label = [QLabelElement new];
        label.title = @"Timestamp";
        label.value = [timestamp stringWithMediumDateTimeFormat];
        //[[root.sections firstObject] insertObject:label atIndex:0]; //crashed inexplicably
        [[[root.sections firstObject] elements] insertObject:label atIndex:0];  //works unless elements is nil
    }

    //Show a Location Button only when editing/reviewing
    if (!isNew) {
        AngleDistanceLocation *angleDistanceLocation = [self.survey angleDistanceLocationFromEntity:entity];
        QButtonElement *locationButton = [[QButtonElement alloc] init];
        locationButton.appearance = [[QFlatAppearance alloc] init];
        locationButton.appearance.buttonAlignment = NSTextAlignmentCenter;
        //TODO: #75 self.view.tintColor is gray after feature selector ViewControllers
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
                //TODO: #168 Resize popover
                [self.attributeCollector.navigationController pushViewController:vc animated:YES];
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
                        CLLocation *location = self.mostRecentLocation;
                        if (!location.timestamp) {
                            [self showNoLocationAlert];
                            return;
                        }
                        observation.gpsPoint = [self.survey addGpsPointAtLocation:location];
                        // "Move" the observation; put the new graphic in the dialog for other attribute changes
                        // all graphics for observations should be a POGraphic; do nothing if something went wrong
                        if ([graphic isKindOfClass:[POGraphic class]]) {
                            AGSGraphic *newGraphic = [(POGraphic *)graphic redraw:observation survey:self.survey];
                            UINavigationController *nav = (UINavigationController *)self.presentedViewController;
                            AttributeViewController *dialog = (AttributeViewController *)[nav topViewController];
                            dialog.graphic = newGraphic;
                            // Would be nice to move the popup, but it doesn't work (deprecated in 9.x)
                        }
                    };
                    [[root.sections lastObject] addElement:updateLocationButton];
                }
            }
        }
    }

    //Delete Button
    //You cannot delete a mission property (cancel is done on VC Nav controls).
    if (![feature isKindOfClass:[ProtocolMissionFeature class]]) {
        NSString *buttonText = @"Delete";
        QButtonElement *deleteButton = [[QButtonElement alloc] initWithTitle:buttonText];
        deleteButton.appearance = [[QFlatAppearance alloc] init];
        deleteButton.appearance.buttonAlignment = NSTextAlignmentCenter;
        deleteButton.appearance.actionColorEnabled = [UIColor redColor];
        deleteButton.onSelected = ^(){
            if ([graphic isKindOfClass:[POGraphic class]]) {
                [(POGraphic *)graphic remove];
            } else {
                [graphic.layer removeGraphic:graphic];
            }
            [self.survey deleteEntity:entity];
            [self dismissViewControllerAnimated:YES completion:nil];
        };
        if (self.survey.protocol.cancelOnTop) {
            [[root.sections firstObject] insertElement:deleteButton atIndex:0];
        } else {
            [[root.sections lastObject] addElement:deleteButton];
        }
    }


    AttributeViewController *dialog = [[AttributeViewController alloc] initWithRoot:root];
    dialog.managedObject = entity;
    dialog.graphic = graphic;

    // Present VC
    self.attributeCollector = dialog;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:dialog];
    dialog.resizeWhenKeyboardPresented = NO; //because the popover I'm in will resize
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismissAttributeCollector:)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(saveAndDismissAttributeCollector:)];
    dialog.toolbarItems = @[cancelButton, flex, doneButton];
    nav.toolbarHidden = NO;
    nav.modalPresentationStyle = UIModalPresentationPopover;
    [self presentViewController:nav animated:YES completion:nil];
    UIPopoverPresentationController *popover = nav.popoverPresentationController;
    popover.sourceView = self.mapView;
    CGPoint screenPoint = [self.mapView nearestScreenPoint:mapPoint];
    popover.sourceRect = CGRectMake(screenPoint.x, screenPoint.y, 1, 1);
    popover.delegate = self;
}

- (void) saveAndDismissAttributeCollector:(UIBarButtonItem *)sender
{
    [self saveAttributes];
    [self dismissAttributeCollector:sender];
}

- (void) dismissAttributeCollector:(UIBarButtonItem *)sender
    {
    [self dismissViewControllerAnimated:YES completion:nil];
    self.attributeCollector = nil;
}

// Called when editing popover is dismissed (or maybe when save/done button is tapped)
- (void)saveAttributes
{
    AKRLog(@"Saving attributes from the recently dismissed Attribute Collector VC");
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    AttributeViewController *dialog = self.attributeCollector;
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
        [self alert:@"Save Failed" message:msg];
    }
    //For observations, redraw the graphic and label with the new attributes
    if ([dialog.managedObject isKindOfClass:[Observation class]]) {
        // all graphics for observations should be a POGraphic; do nothing if something went wrong
        if ([dialog.graphic isKindOfClass:[POGraphic class]]) {
            [(POGraphic *)dialog.graphic redraw:(Observation *)dialog.managedObject survey:self.survey];
        }
    }
    //For Mission properties currently do nothing (no labels or attribute based symbology supported)

    //Update Totalizer
    if ([obj isKindOfClass:[MissionProperty class]]) {
        if (self.survey.isRecording) {
            [self.survey.totalizer missionPropertyChanged:(MissionProperty *)obj];
            self.totalizerMessage.text = self.survey.totalizer.message;
        }
    }
}




#pragma mark - AngleDistance popover for feature editing

//Called programatically by feature bar button when creating a new Angle/Distance observation
- (void) performAngleDistanceSequeWithFeature:(ProtocolFeature *)feature fromButton:(UIBarButtonItem *)button
{
    CLLocation *recentlocation = self.mostRecentLocation;
    if (!recentlocation.timestamp) {
        [self showNoLocationAlert];
        return;
    }
    GpsPoint *gpsPoint = [self.survey addGpsPointAtLocation:recentlocation];
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
        [self alert:nil message:@"Unable to get current course/heading for Angle/Distance."];
        return;
    }

    AngleDistanceViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"AngleDistanceViewController"];
    vc.location = location;
    vc.completionBlock = ^(AngleDistanceViewController *controller) {
        AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
        Observation *observation = [self.survey createObservation:feature atGpsPoint:gpsPoint withAngleDistanceLocation:controller.location];
        AGSGraphic *graphic = [self.survey drawObservation:observation];
        [self setAttributesForFeatureType:feature entity:observation graphic:graphic defaults:nil atPoint:mapPoint isNew:YES isEditing:YES];
    };

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPopover;
    [self presentViewController:nav animated:YES completion:nil];
    nav.popoverPresentationController.barButtonItem = button;
}

// This is called by the feature editor (setAttributesForFeatureType:), when the user wants to edit the Angle/Distance of an observation.
- (void) performAngleDistanceSequeWithFeature:(ProtocolFeature *)feature entity:(NSManagedObject *)entity graphic:(AGSGraphic *)graphic
{
    UINavigationController *nav = (UINavigationController *)self.presentedViewController;
    AngleDistanceLocation *angleDistance = [self.survey angleDistanceLocationFromEntity:entity];
    LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:angleDistance.direction protocolFeature:feature absoluteAngle:angleDistance.angle distance:angleDistance.distance];;
    AngleDistanceViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"AngleDistanceViewController"];
    vc.location = location;
    vc.completionBlock = ^(AngleDistanceViewController *controller) {
        Observation *observation = [self.survey observationFromEntity:entity];
        [self.survey updateAngleDistanceObservation:observation withAngleDistance:controller.location];
        // "Move" the observation; put the new graphic in the dialog for other attribute changes
        // all graphics for observations should be a POGraphic; do nothing if something went wrong
        if ([graphic isKindOfClass:[POGraphic class]]) {
            AGSGraphic *newGraphic = [(POGraphic *)graphic redraw:observation survey:self.survey];
            AttributeViewController *dialog = (AttributeViewController *)[nav.viewControllers objectAtIndex:0];
            dialog.graphic = newGraphic;
            // Would be nice to move the popup, but it doesn't work (deprecated in 9.x)
            //AGSPoint *toPoint = (AGSPoint *)newGraphic.geometry;
            //[self.editAttributePopoverController presentPopoverFromMapPoint:toPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }
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
