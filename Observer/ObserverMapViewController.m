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
#import "AGSMapView+AKRAdditions.h"
#import "UIPopoverController+Presenting.h"
#import "GpsPointTableViewController.h"
#import "Survey+CsvExport.h"
#import "GpsPoint+Location.h"
#import "Observation+Location.h"
#import "MissionProperty+Location.h"

//Views
#import "AutoPanButton.h"
#import "AddFeatureBarButtonItem.h"

//Support Model Objects
#import "AutoPanStateMachine.h"

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

//Model
@property (weak,   nonatomic, readonly) NSManagedObjectContext *context; //shortcut to self.survey.document.managedObjectContext

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
@property (nonatomic) BOOL isRecording;
@property (nonatomic) BOOL isObserving;

@property (strong, nonatomic) AutoPanStateMachine *autoPanController;
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) GpsPoint *lastGpsPointSaved;
@property (strong, nonatomic) MapReference *currentMapEntity;
@property (strong, nonatomic) Mission *mission;
@property (strong, nonatomic) MissionProperty *currentMissionProperty;
@property (strong, nonatomic) id<AGSFeature> movingGraphic;
@property (strong, nonatomic) Observation *movingObservation;
@property (strong, nonatomic) MissionProperty *movingMissionProperty;

//Setup for AngleDistance ViewController
@property (strong, nonatomic) LocationAngleDistance *angleDistanceOrientation;
@property (strong, nonatomic) GpsPoint *angleDistanceLocation;

//Used to save state for delegate callbacks (alertview, actionsheet and segue)
@property (strong, nonatomic) ProtocolFeature *currentProtocolFeature;
@property (strong, nonatomic) SProtocol *protocolForSurveyCreation;
@property (strong, nonatomic) AGSPoint *mapPointAtAddSelectedFeature;

@property (strong, nonatomic) AGSSpatialReference *wgs84;
@property (strong, nonatomic) NSMutableDictionary *graphicsLayers; // of AGSGraphicsLayer

@property (strong, nonatomic) UIPopoverController *angleDistancePopoverController;
@property (strong, nonatomic) UIPopoverController *mapsPopoverController;
@property (strong, nonatomic) UIPopoverController *surveysPopoverController;
@property (strong, nonatomic) UIPopoverController *featureSelectorPopoverController;
@property (strong, nonatomic) UIPopoverController *reviewAttributePopoverController;
@property (strong, nonatomic) UIPopoverController *editAttributePopoverController;

@property (strong, nonatomic) AGSPoint *popoverMapPoint;
//TODO: do I need this UINavigationController?
@property (strong, nonatomic) UINavigationController *modalAttributeCollector;

@end



@implementation ObserverMapViewController

#pragma mark - Super class overrides

- (void)viewDidLoad
{
    AKRLog(@"Main view controller view did load");
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
    if (self.editAttributePopoverController) {
        [self.editAttributePopoverController dismissPopoverAnimated:NO];
    }
    if (self.reviewAttributePopoverController) {
        [self.reviewAttributePopoverController dismissPopoverAnimated:NO];
    }
    if (self.featureSelectorPopoverController) {
        [self.featureSelectorPopoverController dismissPopoverAnimated:NO];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.editAttributePopoverController presentPopoverFromMapPoint:self.popoverMapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
    [self.reviewAttributePopoverController presentPopoverFromMapPoint:self.popoverMapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
    [self.featureSelectorPopoverController presentPopoverFromMapPoint:self.popoverMapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:NO];
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


- (IBAction)startStopRecording:(UIBarButtonItem *)sender
{
    if (self.isRecording) {
        [self stopRecording];
    } else {
        [self startRecording];
    }
}

- (IBAction)startStopObserving:(UIBarButtonItem *)sender
{
    if (self.isObserving) {
        [self stopObserving];
    } else {
        [self startObserving];
    }
}

- (IBAction)changeEnvironment:(UIBarButtonItem *)sender
{
    [self saveNewMissionPropertyEditAttributes:YES];
}




#pragma mark - Actions wired up programatically

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




#pragma mark - public properties

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
    if (self.isRecording) {
        for (CLLocation *location in locations) {
            //Should probably be something like:
            //if ([self.survey addGpsPoint:location]) {
            //    [self.mapView addGpsPoint:location];
            //}

            if ([self isNewLocation:location]) {
                GpsPoint *oldPoint = self.lastGpsPointSaved;
                GpsPoint *gpsPoint = [self createGpsPoint:location];
                if (gpsPoint) {
                    [self drawGpsPointAtMapPoint:[self mapPointFromGpsPoint:gpsPoint]];
                }
                if (oldPoint && gpsPoint) {
                    [self drawTrackObserving:self.isObserving from:oldPoint to:gpsPoint];
                }
            }
        }
    }

    //use the speed of the last location to update the autorotation behavior
    CLLocation *location = [locations lastObject];
    if (0 <= location.speed) {
        [self.autoPanController speedUpdate:location.speed];
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
}




#pragma mark - Delegate Methods: AGSLayerDelegate

- (void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error
{
    self.map = nil;
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
    return [self isSelectableLayerName:layer.name];
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
            if (self.isObserving) {
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
                    NSManagedObject *entity = [self entityOnLayerNamed:layerName atTimestamp:timestamp];
                    if ([entity.entity.name isEqualToString:kMissionPropertyEntityName]) {
                        self.movingMissionProperty = (MissionProperty *)entity;
                    } else {
                        self.movingObservation = (Observation *)entity;
                    }
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

    //TODO: If the feature is based on a GPS point, then snap to the closest GPS point
    //TODO: if this was a mission property, then we need to update the tracklogs.
    if (self.movingGraphic) {
        [self.movingGraphic setGeometry:mapPoint];
    }
    [self updateAdhocLocation:self.movingObservation.adhocLocation withMapPoint:mapPoint];
    [self updateAdhocLocation:self.movingMissionProperty.adhocLocation withMapPoint:mapPoint];
    self.movingObservation = nil;
    self.movingMissionProperty = nil;
    self.movingGraphic = nil;
}



#pragma mark - Delegate Methods: AGSCalloutDelegate (all optional)




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
    return self.hasMap && self.mapView.spatialReference.inLinearUnits;
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
    return !self.locationManager ? NO : _locationServicesAvailable;
}

- (BOOL)isAutoRotating
{
    return self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeCompassNavigation ||
    self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeNavigation;
}

- (NSMutableDictionary *)graphicsLayers
{
    if (!_graphicsLayers)
        _graphicsLayers = [[NSMutableDictionary alloc] init];
    return _graphicsLayers;
}

- (AGSSpatialReference *)wgs84
{
    if (!_wgs84) {
        _wgs84 = [AGSSpatialReference wgs84SpatialReference];
    }
    return _wgs84;
}

- (MapReference *)currentMapEntity
{
    if (!_currentMapEntity) {
        // try to fetch it, otherwise create it.
        AKRLog(@"Looking for %@ in coredata",self.map);
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kMapEntityName];

        request.predicate = [NSPredicate predicateWithFormat:@"name == %@ AND author == %@ AND date == %@",
                             self.map.title, self.map.author, self.map.date];
        NSArray *results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
        _currentMapEntity = [results firstObject];
        if(!_currentMapEntity) {
            AKRLog(@"  Map not found, creating new CoreData Entity");
            _currentMapEntity = [NSEntityDescription insertNewObjectForEntityForName:kMapEntityName inManagedObjectContext:self.context];
            _currentMapEntity.name = self.map.title;
            _currentMapEntity.author = self.map.author;
            _currentMapEntity.date = self.map.date;
        }
    }
    return _currentMapEntity;
}

@synthesize context = _context;

- (NSManagedObjectContext *)context
{
    return self.survey.document.managedObjectContext;
}

- (MissionProperty *)currentMissionProperty
{
    if (!_currentMissionProperty) {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kMissionPropertyEntityName];
        request.fetchLimit = 1;
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"adhocLocation.timestamp" ascending:NO]];
        request.predicate = [NSPredicate predicateWithFormat:@"adhocLocation != NULL"];
        NSArray *results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
        MissionProperty *withMap = [results firstObject];
        if (withMap) {
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"gpsPoint.timestamp" ascending:NO]];
            request.predicate = [NSPredicate predicateWithFormat:@"gpsPoint != NULL AND gpsPoint.timestamp > %@", withMap.adhocLocation.timestamp];
        } else {
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"gpsPoint.timestamp" ascending:NO]];
            request.predicate = [NSPredicate predicateWithFormat:@"gpsPoint != NULL"];
        }
        results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
        MissionProperty *withGPS = [results firstObject];
        _currentMissionProperty = withGPS ? withGPS : withMap;
    }
    return _currentMissionProperty;
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
    self.mapView.locationDisplay.interfaceOrientation = self.interfaceOrientation;
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
                //TODO: feature names are too long for buttons, use a short name, or an icon
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
    self.selectSurveyButton.title = (self.context ? self.survey.title : @"Select Survey");
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

    self.startStopRecordingBarButtonItem.enabled = self.context != nil;
    self.startStopObservingBarButtonItem.enabled = self.isRecording && self.context;
    //TODO: if there are no mission properties, we should remove this button.
    self.editEnvironmentBarButton.enabled = self.isRecording && self.context && self.survey.protocol.missionFeature.attributes.count > 0;
    for (AddFeatureBarButtonItem *item in self.addFeatureBarButtonItems) {
        item.enabled = self.isObserving;
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

- (void)setupGPS
{
    self.mapView.locationDisplay.navigationPointHeightFactor = 0.5;
    self.mapView.locationDisplay.wanderExtentFactor = 0.0;
    [self.mapView.locationDisplay startDataSource];
    [self startStopLocationServicesForPanMode];
}




#pragma mark - Private Methods - support for UI actions

- (void)startStopLocationServicesForPanMode
{
    if ([self isAutoRotating]) {
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

- (void)startRecording
{
    AKRLog(@"start recording");
    self.isRecording = YES;
    self.startStopObservingBarButtonItem.enabled = YES;
    [self setBarButtonAtIndex:5 action:@selector(startStopRecording:) ToPlay:NO];
    [self startLocationUpdates];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    self.mission = [NSEntityDescription insertNewObjectForEntityForName:kMissionEntityName
                                                 inManagedObjectContext:self.context];
}

- (void)stopRecording
{
    AKRLog(@"stop recording");
    self.isRecording = NO;
    if (self.isObserving) {
        [self stopObserving];
    } else {
        [self enableControls];
    }
    self.startStopObservingBarButtonItem.enabled = NO;
    [self setBarButtonAtIndex:5 action:@selector(startStopRecording:) ToPlay:YES];
    [self stopLocationUpdates];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    //[self.survey saveWithCompletionHandler:nil];
    self.mission = nil;
}

- (void)startObserving
{
    AKRLog(@"start observing");
    self.isObserving = YES;
    if ([self saveNewMissionPropertyEditAttributes:YES]){
        self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:6 action:@selector(startStopObserving:) ToPlay:NO];
        [self enableControls];
    } else {
        self.isObserving = NO;
    }
}

- (void)stopObserving
{
    AKRLog(@"stop observing");
    self.isObserving = NO;
    self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:6 action:@selector(startStopObserving:) ToPlay:YES];
    [self saveNewMissionPropertyEditAttributes:NO];
    [self enableControls];
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
    if (!self.isRecording && ![self isAutoRotating]) {
        self.userWantsLocationUpdates = NO;
        if (self.locationServicesAvailable) {
            //AKRLog(@"Stop Updating Location");
            [self.locationManager stopUpdatingLocation];
        }
    }
}

- (BOOL)isNewLocation:(CLLocation *)location
{
    if (!self.lastGpsPointSaved)
        return YES;
    //0.0001 deg in latitude is about 18cm (<1foot) assuming a mean radius of 6371m, and less in longitude away from the equator.
    if (fabs(location.coordinate.latitude - self.lastGpsPointSaved.latitude) > 0.0001)
        return YES;
    if (fabs(location.coordinate.longitude - self.lastGpsPointSaved.longitude) > 0.0001)
        return YES;
    //TODO: is 10 seconds a good default?  do I want a user setting? this gets called a lot, so I don't want to slow down with a lookup
    if ([location.timestamp timeIntervalSinceDate:self.lastGpsPointSaved.timestamp] > 10.0)
        return YES;
    return NO;
}




#pragma mark - Private Methods - support for map delegate

- (void)closeMap
{
    [self.mapView reset]; //removes all layers, clear SR, envelope, etc.
    self.currentMapEntity = nil;
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
            //adding a layer is async. wait for AGSLayerDelegate layerDidLoad or layerDidFailToLoad to decrementBusy
        } else {
            [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to open the map." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        }
    }
}

- (void)initializeGraphicsLayer
{
    AKRLog(@"Creating graphics layers");

    //gps points layer
    AGSGraphicsLayer *graphicsLayer = [[AGSGraphicsLayer alloc] init];
    AGSMarkerSymbol *symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[UIColor blueColor]];
    [symbol setSize:CGSizeMake(6,6)];
    [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:symbol]];
    [self.mapView addMapLayer:graphicsLayer withName:kGpsPointEntityName];
    self.graphicsLayers[kGpsPointEntityName] = graphicsLayer;

    //All Features
    for (ProtocolFeature *feature in self.survey.protocol.features) {
        graphicsLayer = [[AGSGraphicsLayer alloc] init];
        [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:feature.symbology.agsMarkerSymbol]];
        [self.mapView addMapLayer:graphicsLayer withName:feature.name];
        self.graphicsLayers[feature.name] = graphicsLayer;
    }

    //Mission Property points
    ProtocolMissionFeature *feature = self.survey.protocol.missionFeature;
    graphicsLayer = [[AGSGraphicsLayer alloc] init];
    [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:feature.symbology.agsMarkerSymbol]];
    [self.mapView addMapLayer:graphicsLayer withName:kMissionPropertyEntityName];
    self.graphicsLayers[kMissionPropertyEntityName] = graphicsLayer;
    //Mission Property observing tracks
    NSString * name = [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOn];
    graphicsLayer = [[AGSGraphicsLayer alloc] init];
    [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:feature.observingSymbology.agsLineSymbol]];
    [self.mapView addMapLayer:graphicsLayer withName:name];
    self.graphicsLayers[name] = graphicsLayer;
    //Mission Property not observing track
    name = [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOff];
    graphicsLayer = [[AGSGraphicsLayer alloc] init];
    [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:feature.notObservingSymbology.agsLineSymbol]];
    [self.mapView addMapLayer:graphicsLayer withName:name];
    self.graphicsLayers[name] = graphicsLayer;
}

- (void)clearGraphics
{
    NSMutableArray *graphicsLayers = [NSMutableArray new];
    for (AGSLayer *layer in self.mapView.mapLayers) {
        if ([layer isKindOfClass:[AGSGraphicsLayer class]]) {
            [graphicsLayers addObject:layer];
        }
    }
    for (AGSLayer *layer in graphicsLayers) {
        [self.mapView removeMapLayer:layer];
    }
}

- (void)loadGraphics
{
    BOOL surveyReady = self.survey.document.documentState == UIDocumentStateNormal;
    if (!surveyReady || !self.mapView.loaded) {
        AKRLog(@"Loading graphics - can't because %@.", surveyReady ? @"map isn't loaded" : (self.mapView.loaded ? @"survey isn't loaded" : @"map AND survey are null! - how did that happen?"));
        return;
    }
    [self initializeGraphicsLayer];
    AKRLog(@"Loading graphics from coredata");
    AKRLog(@"  Fetching gpsPoints");
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:kTimestampKey ascending:YES]];
    NSError *error = [[NSError alloc] init];
    NSArray *results = [self.context executeFetchRequest:request error:&error];
    AKRLog(@"  Drawing %d gpsPoints", results.count);
    if (!results && error.code)
        AKRLog(@"Error Fetching GpsPoint %@",error);
    GpsPoint *previousPoint;
    BOOL observing = NO;
    for (GpsPoint *gpsPoint in results) {
        //draw each individual GPS point
        //[self drawGpsPoint:gpsPoint];

        //Keep track of the previous point to draw tracks
        if (!previousPoint) {
            previousPoint = gpsPoint;
            continue;
        }
        if (previousPoint.mission != gpsPoint.mission) {
            previousPoint = gpsPoint;
            continue;
        }
        if (previousPoint.missionProperty) {
            observing = previousPoint.missionProperty.observing;
        }
        [self drawTrackObserving:observing from:previousPoint to:gpsPoint];

        previousPoint = gpsPoint;
    }

    //Get Observations
    AKRLog(@"  Fetching observations");
    request = [NSFetchRequest fetchRequestWithEntityName:kObservationEntityName];
    results = [self.context executeFetchRequest:request error:&error];
    if (!results && error.code)
        AKRLog(@"Error Fetching Observations %@",error);
    AKRLog(@"  Drawing %d observations", results.count);
    for (Observation *observation in results) {
        [self loadObservation:observation];
    }
    //Get MissionProperties
    AKRLog(@"  Fetching mission properties");
    request = [NSFetchRequest fetchRequestWithEntityName:kMissionPropertyEntityName];
    results = [self.context executeFetchRequest:request error:&error];
    if (!results && error.code)
        AKRLog(@"Error Fetching Mission Properties %@",error);
    AKRLog(@"  Drawing %d Mission Properties", results.count);
    for (MissionProperty *missionProperty in results) {
        [self loadMissionProperty:missionProperty];
    }

    AKRLog(@"  Done loading graphics");
}

- (AGSPoint *)mapPointFromGpsPoint:(GpsPoint *)gpsPoint
{
    return [gpsPoint pointOfGpsWithSpatialReference:self.mapView.spatialReference];
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
                //AKRLog(@"Start OpenSurvey completion handler");
                if (success) {
                    [self logStats];
                    [self loadGraphics];
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
            if (self.isRecording) {
                [self stopRecording];
            }
            [self clearCachedEntities];
            [self clearGraphics];
            [survey closeDocumentWithCompletionHandler:^(BOOL success) {
                //this completion handler runs on the main queue;
                //AKRLog(@"Start CloseSurvey completion handler");
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

- (void)clearCachedEntities
{
    //If I switch coredata stores, I need to forget the entities that point to the current coredata store
    self.currentMapEntity = nil;
    self.lastGpsPointSaved = nil;
    self.mission = nil;
    self.currentMissionProperty = nil;
}




#pragma mark - Private Methods - support for data model - gps points

- (GpsPoint *)createGpsPoint:(CLLocation *)gpsData
{
    //AKRLog(@"Creating GpsPoint, Lat = %f, lon = %f, timestamp = %@", gpsData.coordinate.latitude, gpsData.coordinate.longitude, gpsData.timestamp);
    if (!gpsData.timestamp) {
        AKRLog(@"Can't save a GPS Point without a timestamp!");
        return nil; //TODO: added for testing on simulator, remove for production
    }
    if (self.lastGpsPointSaved && [self.lastGpsPointSaved.timestamp timeIntervalSinceDate:gpsData.timestamp] == 0) {
        return self.lastGpsPointSaved;
    }
    GpsPoint *gpsPoint = [NSEntityDescription insertNewObjectForEntityForName:kGpsPointEntityName
                                                       inManagedObjectContext:self.context];
    if (!gpsPoint) {
        AKRLog(@"Could not create a Gps Point in Core Data");
        return nil;
    }

    gpsPoint.mission = self.mission;
    gpsPoint.altitude = gpsData.altitude;
    gpsPoint.course = gpsData.course;
    gpsPoint.horizontalAccuracy = gpsData.horizontalAccuracy;
    //TODO: CLLocation only guarantees that lat/long are double.  Our Coredata constraint may fail.
    gpsPoint.latitude = gpsData.coordinate.latitude;
    gpsPoint.longitude = gpsData.coordinate.longitude;
    gpsPoint.speed = gpsData.speed;
    gpsPoint.timestamp = gpsData.timestamp; // ? gpsData.timestamp : [NSDate date]; //TODO: added for testing on simulator, remove for production
    gpsPoint.verticalAccuracy = gpsData.verticalAccuracy;
    self.lastGpsPointSaved = gpsPoint;
    return gpsPoint;
}

- (void)drawGpsPointAtMapPoint:(AGSPoint *)mapPoint
{
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:nil];
    [self.graphicsLayers[kGpsPointEntityName] addGraphic:graphic];
}

- (void)drawTrackObserving:(BOOL)observing from:(GpsPoint *)fromPoint to:(GpsPoint *)toPoint
{
    //TODO: draw a polyline instead of single lines
    AGSPoint *point1 = [self mapPointFromGpsPoint:fromPoint];
    AGSPoint *point2 = [self mapPointFromGpsPoint:toPoint];
    AGSMutablePolyline *line = [[AGSMutablePolyline alloc] init];
    [line addPathToPolyline];
    [line addPointToPath:point1];
    [line addPointToPath:point2];
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:line symbol:nil attributes:nil];
    NSString *name = [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, (observing ? kTrackOn : kTrackOff)];
    [self.graphicsLayers[name] addGraphic:graphic];
}




#pragma mark - Private Methods - support for data model - observations

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
    GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
    if (!gpsPoint) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to get GPS point for Feature." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        return;
    }
    Observation *observation = [self createObservation:feature atGpsPoint:gpsPoint];
    if (!observation) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to create feature." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        return;
    }
    AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
    AGSGraphic *graphic = [self drawObservation:observation atPoint:mapPoint];
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
        if ([self shouldPerformAngleDistanceSequeWithFeature:feature]) {
            [self performAngleDistanceSequeWithFeature:feature button:button];
        }
    } else {
        AKRLog(@"Oh No! I couldn't find the calling button for the segue");
    }
}

- (void)addFeatureAtTarget:(ProtocolFeature *)feature
{
    Observation *observation = [self createObservation:feature AtMapLocation:self.mapView.mapAnchor];
    AGSGraphic *graphic = [self drawObservation:observation atPoint:self.mapView.mapAnchor];
    [self setAttributesForFeatureType:feature entity:observation graphic:graphic defaults:nil atPoint:self.mapView.mapAnchor isNew:YES isEditing:YES];
}

- (Observation *)createObservation:(ProtocolFeature *)feature
{
    //AKRLog(@"Creating Observation managed object");
    NSString *entityName = [NSString stringWithFormat:@"%@%@",kObservationPrefix,feature.name];
    Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                             inManagedObjectContext:self.context];
    NSAssert(observation, @"%@", @"Could not create an Observation in Core Data");
    observation.mission = self.mission;
    return observation;
}

- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint
{
    Observation *observation = [self createObservation:feature];
    observation.gpsPoint = gpsPoint;
    return observation;
}

- (Observation *)createObservation:(ProtocolFeature *)feature AtMapLocation:(AGSPoint *)mapPoint
{
    Observation *observation = [self createObservation:feature];
    observation.adhocLocation = [self createAdhocLocationWithMapPoint:mapPoint];
    return observation;
}

- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint withAngleDistanceLocation:(LocationAngleDistance *)angleDistance
{
    Observation *observation = [self createObservation:feature atGpsPoint:gpsPoint];
    observation.angleDistanceLocation = [self createAngleDistanceLocationWithAngleDistanceLocation:angleDistance];
    return observation;
}

- (void)loadObservation:(Observation *)observation
{
    //AKRLog(@"    Loading observation");
    AGSPoint *point = [observation pointOfFeatureWithSpatialReference:self.mapView.spatialReference];
    NSAssert(point, @"An observation in %@ has no location", observation.entity.name);
    [self drawObservation:observation atPoint:point];
}

- (AGSGraphic *)drawObservation:(Observation *)observation atPoint:(AGSPoint *)mapPoint
{
    //AKRLog(@"    Drawing observation type %@",observation.entity.name);
    NSDate *timestamp = [observation timestamp];
    NSAssert(timestamp, @"An observation in %@ has no timestamp", observation.entity.name);
    NSDictionary *attribs = timestamp ? @{kTimestampKey:timestamp} : @{kTimestampKey:[NSNull null]};
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attribs];
    NSString * name = [observation.entity.name stringByReplacingOccurrencesOfString:kObservationPrefix withString:@""];
    [self.graphicsLayers[name] addGraphic:graphic];
    return graphic;
}

- (void)updateAdhocLocation:(AdhocLocation *)adhocLocation withMapPoint:(AGSPoint *)mapPoint
{
    //mapPoint is in the map coordinates, convert to WGS84
    AGSPoint *wgs84Point = (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:mapPoint toSpatialReference:self.wgs84];
    adhocLocation.latitude = wgs84Point.y;
    adhocLocation.longitude = wgs84Point.x;
    if (self.lastGpsPointSaved && [self.lastGpsPointSaved.timestamp timeIntervalSinceDate: [NSDate date]] < kStaleInterval) {
        adhocLocation.timestamp = self.lastGpsPointSaved.timestamp;
        //Used for relating the adhoc observation to where the observer was when the observation was made
    } else {
        adhocLocation.timestamp = [NSDate date];
    }
}

- (AdhocLocation *)createAdhocLocationWithMapPoint:(AGSPoint *)mapPoint
{
    //AKRLog(@"Adding Adhoc Location to Core Data at Map Point %@", mapPoint);
    AdhocLocation *adhocLocation = [NSEntityDescription insertNewObjectForEntityForName:kAdhocLocationEntityName
                                                                 inManagedObjectContext:self.context];
    NSAssert(adhocLocation, @"%@", @"Could not create an AdhocLocation in Core Data");
    [self updateAdhocLocation:adhocLocation withMapPoint:mapPoint];
    adhocLocation.map = self.currentMapEntity;
    return adhocLocation;
}

- (AngleDistanceLocation *)createAngleDistanceLocationWithAngleDistanceLocation:(LocationAngleDistance *)location
{
    //AKRLog(@"Adding Angle = %f, Distance = %f, Course = %f to CoreData", location.absoluteAngle, location.distanceMeters, location.deadAhead);
    AngleDistanceLocation *angleDistance = [NSEntityDescription insertNewObjectForEntityForName:kAngleDistanceLocationEntityName
                                                                         inManagedObjectContext:self.context];
    NSAssert(angleDistance, @"%@", @"Could not create an AngleDistanceLocation in Core Data");
    angleDistance.angle = location.absoluteAngle;
    angleDistance.distance = location.distanceMeters;
    angleDistance.direction = location.deadAhead;
    return angleDistance;
}


#pragma mark - Private Methods - support for data model - mission properties

- (MissionProperty *)createMissionProperty
{
    //AKRLog(@"Creating MissionProperty managed object");
    MissionProperty *missionProperty = [NSEntityDescription insertNewObjectForEntityForName:kMissionPropertyEntityName inManagedObjectContext:self.context];
    NSAssert(missionProperty, @"%@", @"Could not create a Mission Property in Core Data");
    missionProperty.mission = self.mission;
    return missionProperty;
}

- (MissionProperty *)createMissionPropertyAtGpsPoint:(GpsPoint *)gpsPoint
{
    //AKRLog(@"Creating MissionProperty at GPS point");
    if (!gpsPoint.timestamp) {
        AKRLog(@"Unable to create a mission property; timestamp for gps point is nil");
        return nil;
    }
    MissionProperty *missionProperty = [self createMissionProperty];
    missionProperty.gpsPoint = gpsPoint;
    return missionProperty;
}

- (MissionProperty *)createMissionPropertyAtMapLocation:(AGSPoint *)mapPoint
{
    //AKRLog(@"Creating MissionProperty at Map point");
    AdhocLocation *adhocLocation = [self createAdhocLocationWithMapPoint:mapPoint];
    if (!adhocLocation.timestamp) {
        AKRLog(@"Unable to create a mission property; timestamp for adhoc location is nil");
        [self.context deleteObject:adhocLocation];
        return nil;
    }
    MissionProperty *missionProperty = [self createMissionProperty];
    missionProperty.adhocLocation = adhocLocation;
    return missionProperty;
}

- (void)loadMissionProperty:(MissionProperty *)missionProperty
{
    //AKRLog(@"    Loading missionProperty");
    AGSPoint *point = [missionProperty pointOfMissionPropertyWithSpatialReference:self.mapView.spatialReference];
    NSAssert(point, @"A mission property has no location");
    [self drawMissionProperty:missionProperty atPoint:point];
}

- (AGSGraphic *)drawMissionProperty:(MissionProperty *)missionProperty atPoint:(AGSPoint *)mapPoint
{
    NSDate *timestamp = [missionProperty timestamp];
    NSAssert(timestamp, @"A mission property has no timestamp");
    NSDictionary *attribs = timestamp ? @{kTimestampKey:timestamp} : @{kTimestampKey:[NSNull null]};
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attribs];
    [self.graphicsLayers[kMissionPropertyEntityName] addGraphic:graphic];
    return graphic;
}

- (BOOL)saveNewMissionPropertyEditAttributes:(BOOL)edit
{
    MissionProperty *missionProperty;
    AGSPoint *mapPoint;
    GpsPoint *gpsPoint;
    //do not create a mission property, until I have checked the database (if necessary) for the last mission property
    MissionProperty * template = self.currentMissionProperty;
    if (self.locationServicesAvailable) {
        gpsPoint = [self createGpsPoint:self.locationManager.location];
    }
    if (gpsPoint) {
        mapPoint = [self mapPointFromGpsPoint:gpsPoint];
        missionProperty = [self createMissionPropertyAtGpsPoint:gpsPoint];
    } else {
        mapPoint = self.mapView.mapAnchor;
        missionProperty = [self createMissionPropertyAtMapLocation:mapPoint];
    }
    if (!missionProperty) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to create a new Mission Property." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
        return NO;
    }
    missionProperty.observing = self.isObserving;
    AGSGraphic *graphic = [self drawMissionProperty:missionProperty atPoint:mapPoint];
    if (edit) {
        [self setAttributesForFeatureType:self.survey.protocol.missionFeature entity:missionProperty graphic:graphic defaults:template atPoint:mapPoint  isNew:YES isEditing:YES];
    } else {
        [self copyAttributesForFeature:self.survey.protocol.missionFeature fromEntity:template toEntity:missionProperty];
    }
    self.currentMissionProperty = missionProperty;
    return YES;
}




#pragma mark - Private Methods to Support Feature Selection/Presentation

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

- (void)addFeature:(ProtocolFeature *)feature atMapPoint:(AGSPoint *)mapPoint
{
    Observation *observation = [self createObservation:feature AtMapLocation:mapPoint];
    AGSGraphic *graphic = [self drawObservation:observation atPoint:mapPoint];
    [self setAttributesForFeatureType:feature entity:observation graphic:graphic defaults:nil atPoint:mapPoint  isNew:YES isEditing:YES];
}

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
}

- (void)presentFeature:(id<AGSFeature>)agsFeature fromLayer:(NSString *)layerName atMapPoint:(AGSPoint *)mapPoint
{
    NSDate *timestamp = (NSDate *)[agsFeature safeAttributeForKey:kTimestampKey];

    AKRLog(@"Presenting feature for layer %@ with timestamp %@", layerName, timestamp);

    //NOTE: entityNamed:atTimestamp: only works with layers that have a gpspoint or an adhoc, so missionProperties and Observations
    //NOTE: gpsPoints do not have a QuickDialog definition; tracklogs would need to use the related missionProperty
    //TODO: expand to work on gpsPoints and tracklog segments
    if (![self isSelectableLayerName:layerName]) {
        AKRLog(@"  Bailing. layer type is not supported");
    }

    //get the feature type from the layername
    ProtocolFeature * feature = nil;
    if ([layerName isEqualToString:kMissionPropertyEntityName]) {
        feature =  self.survey.protocol.missionFeature;
    } else {
        for (ProtocolFeature *f in self.survey.protocol.features) {
            if ([f.name isEqualToString:layerName]) {
                feature = f;
                break;
            }
        }
    }

    //get entity using the timestamp on the layername and the timestamp on the AGS Feature
    NSManagedObject *entity = [self entityOnLayerNamed:layerName atTimestamp:timestamp];

    if (!feature || !entity) {
        AKRLog(@"  Bailing. Could not find the dialog configuration, and/or the feature");
        return;
    }

    //TODO: When do I implement readonly features
    [self setAttributesForFeatureType:feature entity:entity graphic:(AGSGraphic *)agsFeature defaults:entity atPoint:mapPoint isNew:NO isEditing:YES];
}




#pragma mark - Private Methods - misc support for data model

- (void)setAttributesForFeatureType:(ProtocolFeature *)feature entity:(NSManagedObject *)entity graphic:(AGSGraphic *)graphic defaults:(NSManagedObject *)template atPoint:(AGSPoint *)mapPoint isNew:(BOOL)isNew isEditing:(BOOL)isEditing
{
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
        AngleDistanceLocation *angleDistanceLocation = [self angleDistanceLocationFromEntity:entity];
        QButtonElement *locationButton = [[QButtonElement alloc] init];
        locationButton.appearance = [[QFlatAppearance alloc] init];
        locationButton.appearance.buttonAlignment = NSTextAlignmentCenter;
        //TODO: self.view.tintColor is gray after feature selector ViewControllers
        locationButton.appearance.actionColorEnabled = self.view.tintColor;
        if (angleDistanceLocation) {
            locationButton.title = @"Change Location";
            locationButton.onSelected = ^(){
                [[[UIAlertView alloc] initWithTitle:nil message:@"Feature not implemented yet." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
                //TODO: Use angleDistanceLocation and self.survey.protocol to initialize the UIViewController
                //if ([self shouldPerformAngleDistanceSequeWithFeature:feature]) {
                //    [self performAngleDistanceSequeWithFeature:feature entity:entity mapPoint:mapPoint];
                //}
            };
        } else {
            locationButton.title = @"Review Location";
            locationButton.onSelected = ^(){
                GpsPointTableViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"GpsPointTableViewController"];
                vc.gpsPoint = [self gpsPointFromEntity:entity];
                vc.adhocLocation = [self adhocLocationFromEntity:entity];
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
    if (self.locationServicesAvailable && self.isRecording && self.lastGpsPointSaved) {
        if ([self isKindOfObservation:entity]) {
            Observation *observation = (Observation *)entity;
            WaysToLocateFeature options = feature.allowedLocations.nonTouchChoices;
            if ((options & LocateFeatureWithGPS) == LocateFeatureWithGPS) {
                AdhocLocation *adhocLocation = [self adhocLocationFromEntity:observation];
                if (adhocLocation) {
                    QButtonElement *updateLocationButton = [[QButtonElement alloc] init];
                    updateLocationButton.appearance = [[QFlatAppearance alloc] init];
                    updateLocationButton.appearance.buttonAlignment = NSTextAlignmentCenter;
                    updateLocationButton.appearance.actionColorEnabled = self.view.tintColor;
                    updateLocationButton.title = @"Move to GPS Location";
                    updateLocationButton.onSelected = ^(){
                        observation.gpsPoint = self.lastGpsPointSaved;
                        [graphic setGeometry:[self mapPointFromGpsPoint:self.lastGpsPointSaved]];
                        //Note: do not remove the adhoc location as that records the time of the observation
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
            [[self layerForFeatureType:feature] removeGraphic:graphic];
            [self.context deleteObject:entity];
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
        self.popoverMapPoint = mapPoint;
        if (isEditing) {
            self.editAttributePopoverController = popover;
        } else {
            self.reviewAttributePopoverController = popover;
        }
        [popover presentPopoverFromMapPoint:mapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
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

- (void) copyAttributesForFeature:(ProtocolFeature *)feature fromEntity:(NSManagedObject *)fromEntity toEntity:(NSManagedObject *)toEntity
{
    for (NSAttributeDescription *attribute in feature.attributes) {
        id value = [fromEntity valueForKey:attribute.name];
        if (value) {
            [toEntity setValue:value forKey:attribute.name];
        }
    }
}



#pragma mark - Private Methods - misc support

- (NSManagedObject *)entityOnLayerNamed:(NSString *)layerName atTimestamp:(NSDate *)timestamp
{
    if (!layerName || !timestamp) {
        return nil;
    }
    if (![self isSelectableLayerName:layerName]) {
        return nil;
    }
    
    //Deal with ESRI graphic date bug
    NSDate *start = [timestamp dateByAddingTimeInterval:-0.01];
    NSDate *end = [timestamp dateByAddingTimeInterval:+0.01];
    NSString *name = [self entityNameFromLayerName:layerName];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:name];
    request.predicate = [NSPredicate predicateWithFormat:@"(%@ <= gpsPoint.timestamp AND gpsPoint.timestamp <= %@) || (%@ <= adhocLocation.timestamp AND adhocLocation.timestamp <= %@)",start,end,start,end];
    NSArray *results = [self.context executeFetchRequest:request error:nil];
    return (NSManagedObject *)[results lastObject]; // will return nil if there was an error, or no results
}

- (NSString *)entityNameFromLayerName:(NSString *)layerName {
    NSString *entityName = nil;
    if ([layerName isEqualToString:kGpsPointEntityName] || [layerName isEqualToString:kMissionPropertyEntityName]) {
        entityName = layerName;
    } else if ([layerName hasPrefix:kMissionPropertyEntityName]) {
        entityName = nil;
    } else {
        entityName = [NSString stringWithFormat:@"%@%@",kObservationPrefix, layerName];
    }
    return entityName;
}

- (BOOL)isSelectableLayerName:(NSString *)layerName {
    for (NSString *badName in @[kGpsPointEntityName,
                                [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOn],
                                [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, kTrackOff]]) {
        if ([layerName isEqualToString:badName]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)isKindOfObservation:(NSManagedObject *)entity
{
    return [entity.entity.name hasPrefix:kObservationPrefix];
}

- (AngleDistanceLocation *)angleDistanceLocationFromEntity:(NSManagedObject *)entity
{
    if ([entity.entity.name hasPrefix:kObservationPrefix]) {
        return ((Observation *)entity).angleDistanceLocation;
    }
    return nil;
}

- (GpsPoint *)gpsPointFromEntity:(NSManagedObject *)entity
{
    NSString *entityName = entity.entity.name;
    if ([entityName hasPrefix:kObservationPrefix]) {
        return ((Observation *)entity).gpsPoint;
    }
    if ([entityName isEqualToString:kMissionPropertyEntityName]) {
        return ((MissionProperty *)entity).gpsPoint;
    }
    return nil;
}

- (AdhocLocation *)adhocLocationFromEntity:(NSManagedObject *)entity
{
    NSString *entityName = entity.entity.name;
    if ([entityName hasPrefix:kObservationPrefix]) {
        return ((Observation *)entity).adhocLocation;
    }
    if ([entityName isEqualToString:kMissionPropertyEntityName]) {
        return ((MissionProperty *)entity).adhocLocation;
    }
    return nil;
}

- (AGSGraphicsLayer *)layerForFeatureType:(ProtocolFeature *)feature
{
    if ([feature isKindOfClass:[ProtocolMissionFeature class]]) {
        return self.graphicsLayers[kMissionPropertyEntityName];
    } else {
        return self.graphicsLayers[feature.name];
    }
}

- (BOOL) shouldPerformAngleDistanceSequeWithFeature:(ProtocolFeature *)feature
{
    if (self.angleDistancePopoverController) {
        //TODO: is this code path possible?
        [self.angleDistancePopoverController dismissPopoverAnimated:YES];
        self.angleDistancePopoverController = nil;
        return NO;
    }

    self.angleDistanceOrientation = nil;
    self.angleDistanceLocation = [self createGpsPoint:self.locationManager.location];

    double currentCourse = self.angleDistanceLocation.course;
    if (0 <= currentCourse) {
        self.angleDistanceOrientation = [[LocationAngleDistance alloc] initWithDeadAhead:currentCourse protocolFeature:feature];
    } else {
        double currentHeading = self.locationManager.heading.trueHeading;
        if (0 <= currentHeading) {
            self.angleDistanceOrientation = [[LocationAngleDistance alloc] initWithDeadAhead:currentHeading protocolFeature:feature];
        }
    }
    if (!self.angleDistanceLocation) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to get current location for Angle/Distance." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
    }
    if (!self.angleDistanceOrientation) {
        [[[UIAlertView alloc] initWithTitle:nil message:@"Unable to get current heading for Angle/Distance." delegate:nil cancelButtonTitle:nil otherButtonTitles:kOKButtonText, nil] show];
    }
    return self.angleDistanceOrientation && self.angleDistanceLocation;
}

- (void) performAngleDistanceSequeWithFeature:(ProtocolFeature *)feature button:(UIBarButtonItem *)button
{
    LocationAngleDistance *location = self.angleDistanceOrientation;
    GpsPoint *gpsPoint = self.angleDistanceLocation;

    AngleDistanceViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"AngleDistanceViewController"];
    vc.location = location;
    vc.completionBlock = ^(AngleDistanceViewController *controller) {
        self.angleDistancePopoverController = nil;
        AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
        Observation *observation = [self createObservation:feature atGpsPoint:gpsPoint withAngleDistanceLocation:controller.location];
        AGSGraphic *graphic = [self drawObservation:observation atPoint:[controller.location pointFromPoint:mapPoint]];
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

- (void) performAngleDistanceSequeWithFeature:(ProtocolFeature *)feature entity:(NSManagedObject *)entity mapPoint:(AGSPoint *)mapPoint
{
    //Setup angle distance form
    [self.angleDistancePopoverController presentPopoverFromMapPoint:mapPoint inMapView:self.mapView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}



#pragma mark - Diagnostic Aids - to be removed

- (void)logStats
{
#ifdef AKR_DEBUG
    AKRLog(@"Survey document is open. It contains:");
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
    NSArray *results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"  %d GpsPoints", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kObservationEntityName];
    results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"  %d Observations", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kMissionPropertyEntityName];
    results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"  %d MissionProperties", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kMissionEntityName];
    results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"  %d Missions", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:kMapEntityName];
    results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    AKRLog(@"  %d Maps", results.count);
    //AKRLog(@"  All GPS as CSV:\n%@",[self.survey csvForGpsPointsMatching:nil]);
    AKRLog(@"  GPS (last 7 days) as CSV:\n%@",[self.survey csvForGpsPointsSince:[[NSDate date] dateByAddingTimeInterval:-(60*60*24*7)]]);
    AKRLog(@"  TrackLog Summary as CSV:\n%@",[self.survey csvForTrackLogMatching:nil]);
    NSDictionary *dict = [self.survey csvForFeaturesMatching:nil];
    for (NSString *key in dict){
        AKRLog(@"\n   Observations of %@\n%@\n",key,dict[key]);
    }
#endif
}

@end
