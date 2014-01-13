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

//FIXME: if basemap is in a geographic projection, then angle and distance calculations will not work, so disable angle/distance button

#import "SurveyCollection.h"
#import "MapCollection.h"
#import "ObserverMapViewController.h"
#import "AngleDistanceViewController.h"
#import "ProtocolCollection.h"
#import "SurveySelectViewController.h"
#import "MapSelectViewController.h"
#import "AttributeViewController.h"
#import "AutoPanStateMachine.h"
#import "AutoPanButton.h"

@interface ObserverMapViewController () {
    CGFloat _initialRotationOfViewAtGestureStart;
}

@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *mapLoadingIndicator;
@property (weak, nonatomic) IBOutlet UILabel *noMapLabel;
@property (weak, nonatomic) IBOutlet UIButton *northButton2;

@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectMapButton;
@property (weak, nonatomic) IBOutlet AutoPanButton *panButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *selectSurveyButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *startStopRecordingBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *startStopObservingBarButtonItem;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *editEnvironmentBarButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addAdObservationBarButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addGpsObservationBarButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addObservationBarButton;

@property (weak, nonatomic) NSManagedObjectContext *context;
@property (nonatomic) int busyCount;
@property (strong, nonatomic) AutoPanStateMachine *autoPanController;

@property (nonatomic) BOOL userWantsAutoPanOn;
@property (nonatomic) AGSLocationDisplayAutoPanMode savedAutoPanMode;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (nonatomic) BOOL locationServicesAvailable;
@property (nonatomic) BOOL userWantsLocationUpdates;
@property (nonatomic) BOOL userWantsHeadingUpdates;
@property (strong, nonatomic) GpsPoint *lastGpsPointSaved;
@property (strong, nonatomic) MapReference *currentMapEntity;

@property (strong, nonatomic) AGSGraphicsLayer *observationsLayer;
@property (strong, nonatomic) AGSGraphicsLayer *gpsPointsLayer;
@property (strong, nonatomic) AGSGraphicsLayer *gpsTracksLayer;
@property (strong, nonatomic) AGSGraphicsLayer *missionPropertiesLayer;
@property (strong, nonatomic) UIPopoverController *angleDistancePopoverController;
@property (strong, nonatomic) UIPopoverController *mapsPopoverController;
@property (strong, nonatomic) UIPopoverController *surveysPopoverController;
@property (strong, nonatomic) AGSSpatialReference *wgs84;

@property (strong, nonatomic) Survey *survey;
@property (strong, nonatomic) SurveyCollection* surveys;
@property (strong, nonatomic) MapCollection* maps;
@property (strong, nonatomic) UIPopoverController *quickDialogPopoverController;
@property (strong, nonatomic) UINavigationController *modalAttributeCollector;

@property (nonatomic) BOOL isRecording;
@property (nonatomic) BOOL isObserving;

@property (strong, nonatomic) Mission *mission;

@end



@implementation ObserverMapViewController

#pragma mark - Super class overrides

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.autoPanController = [[AutoPanStateMachine alloc] init];
    self.autoPanController.mapView = self.mapView;
    self.autoPanController.compassRoseButton = self.northButton2;
    self.autoPanController.autoPanModeButton = self.panButton;

    self.noMapLabel.hidden = YES;
    [self incrementBusy];
    self.mapView.layerDelegate = self;
    self.mapView.touchDelegate = self;
    self.mapView.callout.delegate = self;
    [self configureView];
}

- (void)didReceiveMemoryWarning
{
    NSLog(@"Observer Map ViewController did recieve memory warning");
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    if ([identifier isEqualToString:@"AngleDistancePopOver"])
    {
        if (self.angleDistancePopoverController) {
            [self.angleDistancePopoverController dismissPopoverAnimated:YES];
            self.angleDistancePopoverController = nil;
            return NO;
        }
        if (!self.mapView.locationDisplay.mapLocation) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location Unknown" message:@"Unable to calculate a location with a current location for reference." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alert show];
            return NO;
        }

        if (self.mapView.locationDisplay.location.course < 0 && self.locationManager.heading.trueHeading < 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Heading Unknown" message:@"Unable to calculate a location with a current heading for reference." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alert show];
            return NO;
        }
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    UINavigationController *nav = [segue destinationViewController];

    if ([[segue identifier] isEqualToString:@"AngleDistancePopOver"])
    {
        AngleDistanceViewController *vc = (AngleDistanceViewController*)[nav.viewControllers firstObject];

        //create/save current GpsPoint, because it may take a while for the user to enter an angle/distance
        GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
        AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
        double currentCourse = gpsPoint.course;

        LocationAngleDistance *location;
        if (0 <= currentCourse) {
            location = [[LocationAngleDistance alloc] initWithDeadAhead:currentCourse protocol:self.survey.protocol];
        }
        else {
            double currentHeading = self.locationManager.heading.trueHeading;
            if (0 <= currentHeading) {
                location = [[LocationAngleDistance alloc] initWithDeadAhead:currentHeading protocol:self.survey.protocol];
            }
            else {
                location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocol:self.survey.protocol];
            }
        }
        vc.location = location;

        if ([segue isKindOfClass:[UIStoryboardPopoverSegue class]]) {
            self.angleDistancePopoverController = ((UIStoryboardPopoverSegue *)segue).popoverController;
            vc.popover = self.angleDistancePopoverController;
            vc.popover.delegate = self;
        }
        vc.completionBlock = ^(AngleDistanceViewController *sender) {
            self.angleDistancePopoverController = nil;
            Observation *observation = [self createObservationAtGpsPoint:gpsPoint withAngleDistanceLocation:sender.location];
            [self drawObservation:observation atPoint:[sender.location pointFromPoint:mapPoint]];
            [self setAttributesForObservation:observation atPoint:mapPoint];
        };
        vc.cancellationBlock = ^(AngleDistanceViewController *sender) {
            self.angleDistancePopoverController = nil;
        };
    }

    if ([segue.identifier isEqualToString:@"Select Survey"]){
        SurveySelectViewController *vc = (SurveySelectViewController *)[nav.childViewControllers firstObject];
        vc.title = segue.identifier;
        vc.items = self.surveys;
        vc.selectedSurveyChanged = ^{
            // on calling thread
            [self changeSurvey];
        };
        vc.selectedSurveyChangedName = ^{
            [self updateTitleBar];
        };
        if ([segue isKindOfClass:[UIStoryboardPopoverSegue class]]) {
            self.surveysPopoverController = ((UIStoryboardPopoverSegue *)segue).popoverController;
            vc.popover = self.surveysPopoverController;
            vc.popover.delegate = self;
        }
        return;
    }

    if ([segue.identifier isEqualToString:@"Select Map"]) {
        MapSelectViewController *vc = (MapSelectViewController *)[nav.childViewControllers firstObject];
        vc.title = segue.identifier;
        vc.items = self.maps;
        vc.rowSelectedCallback = ^(NSIndexPath*indexPath){
            [self resetBasemap];
        };
        if ([segue isKindOfClass:[UIStoryboardPopoverSegue class]]) {
            self.mapsPopoverController = ((UIStoryboardPopoverSegue *)segue).popoverController;
            vc.popover = self.mapsPopoverController;
            vc.popover.delegate = self;
        }
        return;
    }}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.mapView.locationDisplay.interfaceOrientation = toInterfaceOrientation;
}




#pragma mark - IBActions

// I'm doing the rotation myself, instead of using self.mapView.allowRotationByPinching = YES
// because I need to sync it with the compass rose,
// but the real problem was the mapView was missing some gestures, and capturing some I didn't get
- (IBAction)rotateMap:(UIRotationGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        [self.autoPanController userRotatedMap];
        _initialRotationOfViewAtGestureStart = atan2f(self.northButton2.transform.b, self.northButton2.transform.a);
    }
    CGFloat radians = _initialRotationOfViewAtGestureStart + sender.rotation;
    CGFloat degrees = radians * (180 / M_PI);
    self.northButton2.transform = CGAffineTransformMakeRotation(radians);
    [self.mapView setRotationAngle:-1*degrees];
}

- (IBAction)panMap:(UIPanGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        //NSLog(@"User started Pan");
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
    self.northButton2.transform = CGAffineTransformMakeRotation(0);
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
    NSLog(@"Add Mission Property");
    //FIXME: populate form with prior values or defaults
    //FIXME: if gps, then add at GPS else add adhoc at current location
    //launch pop up to enter attributes, use existing as defaults

    if (self.quickDialogPopoverController) {
        return;
    }
    //create VC from QDialog json in protocol, add newController to popover, display popover
    NSDictionary *dialog = self.surveys.selectedSurvey.protocol.dialogs[@"MissionProperty"];
    QRootElement *root = [[QRootElement alloc] initWithJSON:dialog andData:nil];
    QuickDialogController *viewController = [QuickDialogController controllerForRoot:root];
    //UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    self.quickDialogPopoverController = [[UIPopoverController alloc] initWithContentViewController:viewController];
    self.quickDialogPopoverController.delegate = self;
    //self.popover.popoverContentSize = CGSizeMake(644, 425);
    [self.quickDialogPopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

- (IBAction)addGpsObservation:(UIBarButtonItem *)sender
{
    GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
    Observation *observation = [self createObservationAtGpsPoint:gpsPoint];
    AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
    [self drawObservation:observation atPoint:mapPoint];
    [self setAttributesForObservation:observation atPoint:mapPoint];
    //TODO: is there any reason to add the attributes to the graphic?
    //    NSDictionary *attributes = [self createAttributesFromObservation:observation];
    //    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attributes];
    //    [self.observationsLayer removeGraphic:oldGraphic]; //how do we get the old graphic
    //    [self.observationsLayer addGraphic:graphic];
}

- (IBAction)addAdhocObservation:(UIBarButtonItem *)sender
{
    GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
    //ignore the gpsPoint if it is over a second old
    if ([gpsPoint.timestamp timeIntervalSinceNow] < -2.0)
        gpsPoint = nil;
    Observation *observation = [self createObservationAtGpsPoint:gpsPoint withAdhocLocation:self.mapView.mapAnchor];
    [self drawObservation:observation atPoint:self.mapView.mapAnchor];
    [self setAttributesForObservation:observation atPoint:self.mapView.mapAnchor];
}




#pragma mark - public methods

- (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    BOOL success = NO;
    if ([SurveyCollection collectsURL:url]) {
        success = [self.surveys openURL:url];
        if (!success) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can't open file" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        } else {
            //FIXME: update UI for new survey)
            [[[UIAlertView alloc] initWithTitle:@"Thanks" message:@"I should do something now." delegate:nil cancelButtonTitle:@"Do it later" otherButtonTitles:nil] show];
        }
    }
    if ([MapCollection collectsURL:url]) {
        success = ![self.maps openURL:url];
        if (!success) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can't open file" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        } else {
            //FIXME: update UI for new map)
            [[[UIAlertView alloc] initWithTitle:@"Thanks" message:@"I should do something now." delegate:nil cancelButtonTitle:@"Do it later" otherButtonTitles:nil] show];
        }
    }

    //FIXME: this isn't working when the Protocol view is up
    //I need to make sure I am getting the protocol collection it is using, and make sure updates are going to the delegate.
    if ([ProtocolCollection collectsURL:url]) {
        ProtocolCollection *protocols = [ProtocolCollection sharedCollection];
        [protocols openWithCompletionHandler:^(BOOL success) {
            SProtocol *protocol = [protocols openURL:url];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (protocol) {
                    [[[UIAlertView alloc] initWithTitle:@"New Protocol" message:@"Do you want to create a new survey file with this protocol?" delegate:nil cancelButtonTitle:@"Maybe Later" otherButtonTitles:@"Yes", nil] show];
                    //FIXME: read the response, and acta accordingly
                } else {
                    [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can't open file" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                }
            });
        }];
    }

    return success;
}

- (void)saveSurvey
{
    [self.survey saveWithCompletionHandler:nil];
}

- (void)closeSurvey
{
    [self closeOpenSurveyWithConcurrentOpen:NO];
}




#pragma mark - CLLocationManagerDelegate Protocol

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized)
    {
        self.locationServicesAvailable = YES;
        NSLog(@"Location services authorized");
        if (self.userWantsHeadingUpdates) {
            [self.locationManager startUpdatingHeading];
        }
        if (self.userWantsLocationUpdates) {
            [self.locationManager startUpdatingLocation];
        }
    } else {
        NSLog(@"Location services have been deauthorized");
        if (self.locationServicesAvailable) {
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
    //NSLog(@"locationManager: didUpdateLocations:%@",locations);

    //TODO: check how many locations might be returned (are we missing any?)
    CLLocation *location = [locations lastObject];
    //TODO: simulator returns -1 for speed, so ignore it for testing.  remove from production code.
    //if (!location || location.speed < 0)
    if (!location)
        return;

    if (self.isRecording) {
        if (![self isNewLocation:location]) {
            GpsPoint *gpsPoint = [self createGpsPoint:location];
            //[self drawGpsPoint:gpsPoint atMapPoint:self.mapView.locationDisplay.mapLocation];
            //requires a reprojection of the point, but i'm not sure mapLocation and CLlocation will be in sync.
            [self drawGpsPoint:gpsPoint];
        }
    }

    //use the speed to update the autorotation behavior
    [self.autoPanController speedUpdate:location.speed];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    //NSLog(@"locationManager: didUpdateHeading: %f",newHeading.trueHeading);

    //I get the headings to sync the north arrow with the maps rotation due to changes in the heading (when walking/standing)
    //The mapview provides no delegates or notifications when it rotates.
    //Unfortunately, subclassing AGSMapView didn't help, because it does the rotation in the c++ backend, not through the UIView or AGSMapView interface
    //Maybe I should try turning off the AutoRotate mode of the mapView LocationDisplay and do the rotations myself.

    //if we rotating the north arrow based on the current mapView rotation we will be late, due to the animated rotation of the mapview.
    [self rotateNorthArrow];
    //if we rotating the north arrow based on the current heading we will be early, due to the animated rotation of the mapview.
    //[self rotateNorthArrow:newHeading];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    //TODO: put up an alertview
    NSLog(@"Location Manager Failed: %@",error.localizedDescription);
}




#pragma mark - Delegate Methods: AGSLayerDelegate (all optional)

- (void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error
{
    // Tells the delegate that the layer failed to load with the specified error.
    NSLog(@"layer %@ failed to load with error %@", layer, error);
    [self decrementBusy];
    self.noMapLabel.hidden = NO;
    //TODO: put up an alertview
}

- (void) ayerDidLoad:(AGSLayer *)layer
{
    // Tells the delegate that the layer is loaded and ready to use.
    NSLog(@"layer %@ did load", layer);
    //real work will be done in mapView's delegate
}

- (void)layer:(AGSLayer *)layer didInitializeSpatialReferenceStatus:(BOOL)srStatusValid
{
    NSLog(@"layer %@ did%@ initialize Spatial Reference", layer, srStatusValid ? @"" : @" not");
}


#pragma mark - Delegate Methods: AGSMapViewLayerDelegate (all optional)

- (void)mapViewDidLoad:(AGSMapView*)mapView
{
    //Tells the delegate the map is loaded and ready for use. Fires when the map’s base layer loads.
    NSLog(@"mapViewDidLoad");
    self.noMapLabel.hidden = YES;
    [self initializeGraphicsLayer];
    [self reloadGraphics];
    [self setupGPS];
    [self decrementBusy];
}

- (BOOL)mapView:(AGSMapView *)mapView shouldFindGraphicsInLayer:(AGSGraphicsLayer *)graphicsLayer atPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint
{
    //Asks delegate whether to find which graphics in the specified layer intersect the tapped location. Default is YES.
    //This function may or may not be called on the main thread.
    NSLog(@"mapView:shouldFindGraphicsInLayer:(%f,%f)=(%@) with graphics Layer:%@", screen.x, screen.y, mappoint, graphicsLayer.name);
    return YES;
}


#pragma mark - Delegate Methods: AGSMapViewTouchDelegate (all optional)

- (BOOL)mapView:(AGSMapView*)mapView shouldProcessClickAtPoint:(CGPoint)screen mapPoint:(AGSPoint*)mappoint
{
    //Asks the delegate if the map should process the click at the given location. The default value if this method is not implemented is YES.
    NSLog(@"mapView:shouldProcessClickAtPoint:(%f,%f)=(%@)", screen.x, screen.y, mappoint);
    return YES;
}

- (void)mapView:(AGSMapView *)mapView didClickAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mapPoint graphics:(NSDictionary *)graphics
{
    //Tells the delegate the map was single-tapped at specified location.
    //The dictionary contains NSArrays of intersecting AGSGraphics keyed on the layer name
    NSLog(@"mapView:didClickAtPoint:(%f,%f)=(%@) with graphics:%@", screen.x, screen.y, mapPoint, graphics);
    if ([graphics count]) {
        NSLog(@"display graphic callout");
    }
    else
    {
        if (self.isObserving) {
            Observation *observation = [self createObservationAtGpsPoint:self.lastGpsPointSaved withAdhocLocation:mapPoint];
            [self drawObservation:observation atPoint:mapPoint];
            [self setAttributesForObservation:observation atPoint:mapPoint];
        }
    }
}

- (void)mapView:(AGSMapView *)mapView didTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint graphics:(NSDictionary *)graphics
{
    //Tells the delegate that a point on the map was tapped and held at specified location.
    //The dictionary contains NSArrays of intersecting AGSGraphics keyed on the layer name
    NSLog(@"mapView:didTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", screen.x, screen.y, mappoint, graphics);
}

- (void)mapView:(AGSMapView *)mapView didMoveTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint graphics:(NSDictionary *)graphics
{
    //Tells the delegate that the user moved his finger while tapping and holding on the map.
    //Sent continuously to allow tracking of the movement
    //The dictionary contains NSArrays of intersecting AGSGraphics keyed on the layer name
    NSLog(@"mapView:didMoveTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", screen.x, screen.y, mappoint, graphics);
    AGSGraphic *graphic = [graphics[@"observations"] lastObject];
    if (graphic) {
        [graphic setGeometry:mappoint];
    }
}

- (void)mapView:(AGSMapView *)mapView didEndTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint graphics:(NSDictionary *)graphics
{
    //Tells the delegate that a tap and hold event has ended.
    //The dictionary contains NSArrays of intersecting AGSGraphics keyed on the layer name
    NSLog(@"mapView:didEndTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", screen.x, screen.y, mappoint, graphics);
}

- (void)mapViewDidCancelTapAndHold:(AGSMapView *)mapView
{
    //Tells the delegate that a tap and hold event was cancelled. This may happen when you have the magnifier visible and attempt to take
    //a screenshot using the home/lock button combination.
    NSLog(@"mapViewDidCancelTapAndHold:");
}




#pragma mark - Delegate Methods: AGSCalloutDelegate (all optional)

- (BOOL)mapView:(AGSMapView *)mapView shouldShowCalloutForLocationDisplay:(AGSLocationDisplay *)ld
{
    //Asks the delegate whether to show a callout when the user taps the location display. Default is YES.
    NSLog(@"mapView:shouldShowCalloutForLocationDisplay:%@", ld);
    return YES;
}

- (void)mapView:(AGSMapView *)mapView didShowCalloutForLocationDisplay:(AGSLocationDisplay *)ld
{
    //Tells the delegate a callout was shown for the location display.
    NSLog(@"mapView:didShowCalloutForLocationDisplay%@", ld);
}

- (BOOL)mapView:(AGSMapView *)mapView shouldShowCalloutForGraphic:(AGSGraphic *)graphic
{
    //Asks delegate whether to show callout for a graphic that has been tapped on. Default is YES.
    NSLog(@"mapView:shouldShowCalloutForGraphic:%@", graphic);
    return YES;
}

- (void)mapView:(AGSMapView *)mapView didShowCalloutForGraphic:(AGSGraphic *)graphic
{
    //Tells the delegate callout was shown for a graphic that was tapped on.
    NSLog(@"mapView:didShowCalloutForGraphic:%@", graphic);
}

- (void)mapViewWillDismissCallout:(AGSMapView*)mapView
{
    //Tells the delegate that a callout will be dismissed.
    NSLog(@"mapViewWillDismissCallout:");
}

- (void)mapViewDidDismissCallout:(AGSMapView*)mapView
{
    //Tells the delegate that the callout was dismissed.
    NSLog(@"mapViewDidDismissCallout:");
}




#pragma mark - Delegate Methods: UIPopoverControllerDelegate

//This is not called if the popover is programatically dismissed.
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (popoverController == self.angleDistancePopoverController)
        self.angleDistancePopoverController = nil;
    if (popoverController == self.mapsPopoverController)
        self.mapsPopoverController = nil;
    if (popoverController == self.quickDialogPopoverController) {
        [self dismissQuickDialogPopover:popoverController];
    }
}




#pragma mark - Delegate Methods - UIAlertViewDelegate




#pragma mark - Private Properties

- (CLLocationManager *)locationManager
{
    if (!_locationManager) {
        self.locationServicesAvailable = NO;
        //create manager and register as a delegate even if service are unavailable to get changes in authorization (via settings)
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;

        if (![CLLocationManager locationServicesEnabled]) {
            NSLog(@"Location Services Not Enabled");
        } else {
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
                NSLog(@"Triggering a request for permission to use Location Services.");
                [_locationManager startUpdatingLocation];
                [_locationManager stopUpdatingLocation];
            }
            if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized)
            {
                self.locationServicesAvailable = YES;
                NSLog(@"Location Services Available and Authorized");
            } else {
                NSLog(@"Location Services NOT Authorized");
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

- (AGSGraphicsLayer *)observationsLayer
{
    if (!_observationsLayer)
        _observationsLayer = [[AGSGraphicsLayer alloc] init];
    return _observationsLayer;
}

- (AGSGraphicsLayer *)gpsPointsLayer
{
    if (!_gpsPointsLayer)
        _gpsPointsLayer = [[AGSGraphicsLayer alloc] init];
    return _gpsPointsLayer;
}

- (AGSGraphicsLayer *)gpsTracksLayer
{
    if (!_gpsTracksLayer)
        _gpsTracksLayer = [[AGSGraphicsLayer alloc] init];
    return _gpsTracksLayer;
}

- (AGSGraphicsLayer *)missionPropertiesLayer
{
    if (!_missionPropertiesLayer)
        _missionPropertiesLayer = [[AGSGraphicsLayer alloc] init];
    return _missionPropertiesLayer;
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
        NSLog(@"Looking for %@ in coredata",self.maps.selectedLocalMap);
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Map"];

        request.predicate = [NSPredicate predicateWithFormat:@"name == %@ AND author == %@ AND date == %@",
                             self.maps.selectedLocalMap.title, self.maps.selectedLocalMap.author, self.maps.selectedLocalMap.date];
        NSArray *results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
        _currentMapEntity = [results firstObject];
        if(!_currentMapEntity) {
            NSLog(@"  Map not found, creating new CoreData Entity");
            _currentMapEntity = [NSEntityDescription insertNewObjectForEntityForName:@"Map" inManagedObjectContext:self.context];
            _currentMapEntity.name = self.maps.selectedLocalMap.title;
            _currentMapEntity.author = self.maps.selectedLocalMap.author;
            _currentMapEntity.date = self.maps.selectedLocalMap.date;
        }
    }
    return _currentMapEntity;
}




#pragma mark - Private - UI configuration

- (void)configureView
{
    [self incrementBusy];
    self.surveys = [SurveyCollection sharedCollection];
    [self.surveys openWithCompletionHandler:^(BOOL success) {
        //do any other background work;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self changeSurvey];
            [self decrementBusy];
        });
    }];

    [self incrementBusy];
    self.maps = [MapCollection sharedCollection];
    [self.maps openWithCompletionHandler:^(BOOL success) {
        //do any other background work;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadBaseMap];
            [self decrementBusy];
        });
    }];
}

-(void)updateTitleBar
{
    self.selectSurveyButton.title = (self.survey ? self.survey.title : @"Select Survey");
}

-(void)disableControls
{
    self.selectMapButton.enabled = NO;
    self.selectSurveyButton.enabled = NO;

    self.panButton.enabled = NO;

    self.startStopRecordingBarButtonItem.enabled = NO;
    self.startStopObservingBarButtonItem.enabled = NO;
    self.editEnvironmentBarButton.enabled = NO;
    self.addObservationBarButton.enabled = NO;
    self.addGpsObservationBarButton.enabled = NO;
    self.addAdObservationBarButton.enabled = NO;
}

-(void)enableControls
{
    self.selectMapButton.enabled = self.maps != nil;
    self.selectSurveyButton.enabled = self.surveys != nil;

    self.panButton.enabled = self.mapView.loaded;

    NSDictionary *dialogs = self.survey.protocol.dialogs;
    self.startStopRecordingBarButtonItem.enabled = self.survey != nil;
    self.startStopObservingBarButtonItem.enabled = self.isRecording && self.survey;
    //TODO: if there are no mission properties, we should remove this button.
    self.editEnvironmentBarButton.enabled = self.isRecording && self.survey && dialogs[@"MissionProperty"] != nil;
    //TODO: support more than just one feature called "Observations"
    //TODO:can we support adding observations that have no attributes (no dialog)
    self.addObservationBarButton.enabled = self.isObserving && self.survey && dialogs[@"Observation"] != nil;
    self.addGpsObservationBarButton.enabled = self.isObserving && self.survey && dialogs[@"Observation"] != nil;
    self.addAdObservationBarButton.enabled = self.isObserving && self.maps.selectedLocalMap && self.survey && dialogs[@"Observation"] != nil;
}

- (void)incrementBusy
{
    if (self.busyCount == 0) {
        [self disableControls];
        [self.mapLoadingIndicator startAnimating];
    }
    self.busyCount++;
}

- (void)decrementBusy
{
    if (self.busyCount == 0) {
        return;
    }
    if (self.busyCount == 1) {
        [self enableControls];
        [self.mapLoadingIndicator stopAnimating];
    }
    self.busyCount--;
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
    //NSLog(@"Rotating compass icon to %f degrees", degrees);
    //angle in radians with positive being counterclockwise (on iOS)
    double radians = -1*degrees * M_PI / 180.0;
    self.northButton2.transform = CGAffineTransformMakeRotation(radians);
}

- (void)rotateNorthArrow:(CLHeading *)heading
{
    double degrees = 360 - heading.trueHeading;
    double radians = -1 * degrees * M_PI / 180.0;
    //TODO: use animation to keep the northarrow synced with the mapView
    //    CALayer *myLayer = self.northButton2.layer;
    //    NSNumber *rotationAtStart = [myLayer valueForKeyPath:@"transform.rotation"];
    //    CATransform3D myRotationTransform = CATransform3DRotate(myLayer.transform, radians, 0.0, 0.0, 1.0);
    //    myLayer.transform = myRotationTransform;
    //    CABasicAnimation *myAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    //    myAnimation.duration = 0.2;
    //    myAnimation.fromValue = rotationAtStart;
    //    myAnimation.toValue = [NSNumber numberWithFloat:([rotationAtStart floatValue] + radians)];
    //    [myLayer addAnimation:myAnimation forKey:@"transform.rotation"];
    self.northButton2.transform = CGAffineTransformMakeRotation(radians);
}

- (void)startRecording
{
    NSLog(@"start recording");
    self.isRecording = YES;
    self.startStopObservingBarButtonItem.enabled = YES;
    [self setBarButtonAtIndex:6 action:@selector(startStopRecording:) ToPlay:NO];
    [self startLocationUpdates];
    self.mission = [NSEntityDescription insertNewObjectForEntityForName:@"Mission"
                                                 inManagedObjectContext:self.context];
    //[self updateButtons];
}

- (void)stopRecording
{
    NSLog(@"stop recording");
    self.isRecording = NO;
    if (self.isObserving) {
        [self stopObserving];
    } else {
        [self enableControls];
    }
    self.startStopObservingBarButtonItem.enabled = NO;
    [self setBarButtonAtIndex:6 action:@selector(startStopRecording:) ToPlay:YES];
    [self stopLocationUpdates];
    [self.survey saveWithCompletionHandler:nil];
    self.mission = nil;
}

- (void)startObserving
{
    NSLog(@"start observing");
    self.isObserving = YES;
    self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:7 action:@selector(startStopObserving:) ToPlay:NO];
    //TDOO: populate the mission property dialog with the last/default dataset
    GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
    MissionProperty *mission = [self createMissionPropertyAtGpsPoint:gpsPoint];
    mission.observing = YES;
    AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
    [self setAttributesForMissionProperty:mission atPoint:mapPoint];
    [self drawMissionProperty:mission atPoint:mapPoint];
    [self enableControls];
}

- (void)stopObserving
{
    NSLog(@"stop observing");
    self.isObserving = NO;
    self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:7 action:@selector(startStopObserving:) ToPlay:YES];
    GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
    MissionProperty *mission = [self createMissionPropertyAtGpsPoint:gpsPoint];
    mission.observing = NO;
    AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
    [self drawMissionProperty:mission atPoint:mapPoint];
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
    return newBarButton;
}




#pragma mark - Private Methods - support for location delegate

- (void)startHeadingUpdates
{
    self.userWantsHeadingUpdates = YES;
    if (self.locationServicesAvailable) {
        [self.locationManager startUpdatingHeading];
    }
}

- (void)stopHeadingUpdates
{
    self.userWantsHeadingUpdates = NO;
    if (self.locationServicesAvailable) {
        [self.locationManager stopUpdatingHeading];
    }
}

- (void)startLocationUpdates
{
    self.userWantsLocationUpdates = YES;
    if (self.locationServicesAvailable) {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)stopLocationUpdates
{
    //I may try to stop for multiple reasons. Only stop if they all want to stop
    if (!self.isRecording && ![self isAutoRotating]) {
        self.userWantsLocationUpdates = NO;
        if (self.locationServicesAvailable) {
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
    //FIXME: is 10 seconds a good default?  do I want a user setting? this gets called a lot, so I don't want to slow down with a lookup
    if ([location.timestamp timeIntervalSinceDate:self.lastGpsPointSaved.timestamp] > 10.0)
        return YES;
    return NO;
}




#pragma mark - Private Methods - support for map delegate

- (void)loadBaseMap
{
    if (!self.maps.selectedLocalMap.tileCache)
    {
        self.noMapLabel.hidden = NO;
        [self decrementBusy];
    }
    else
    {
        //adding a layer is async. wait for AGSLayerDelegate layerDidLoad or layerDidFailToLoad
        self.maps.selectedLocalMap.tileCache.delegate = self;
        [self.mapView addMapLayer:self.maps.selectedLocalMap.tileCache withName:@"tilecache basemap"];
    }
    //[self.oldMapList addObserver:self forKeyPath:@"currentMap" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
}

- (void)resetBasemap
{
    //This is only called when the self.maps.currentMap has changed (usually by a user selection in a different view controller)
    //It is not called when the self.maps.currentMap is initialized.

    //A "loaded" mapview has an immutable SR and maxExtents based on the first layer loaded (not on the first layer in the mapView)
    //removing all layers from the mapview does not "unload" the mapview.
    //to reset the mapView extents/SR, we need to call reset, then re-add the layers.
    //first we need to get the layers, so we can re-add them after setting the new basemap
    NSLog(@"Reseting the basemap");
    self.currentMapEntity = nil;
    if (!self.maps.selectedLocalMap.tileCache)
    {
        self.noMapLabel.hidden = NO;
        [self decrementBusy];
    }
    else
    {
        self.noMapLabel.hidden = YES;
        [self incrementBusy];
        [self.mapView reset]; //remove all layers
                              //adding a layer is async. wait for AGSLayerDelegate layerDidLoad or layerDidFailToLoad
        self.maps.selectedLocalMap.tileCache.delegate = self;
        [self.mapView addMapLayer:self.maps.selectedLocalMap.tileCache withName:@"tilecache basemap"];
    }
}

- (void)initializeGraphicsLayer
{
    NSLog(@"Adding two graphics layers");
    AGSMarkerSymbol *symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[UIColor blueColor]];
    [symbol setSize:CGSizeMake(6,6)];
    [self.gpsPointsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:symbol]];
    [self.mapView addMapLayer:self.gpsPointsLayer withName:@"gpsPointsLayer"];

    symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor purpleColor] colorWithAlphaComponent:.5]];
    [symbol setSize:CGSizeMake(18,18)];
    [self.observationsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:symbol]];
    [self.mapView addMapLayer:self.observationsLayer withName:@"observations"];

    symbol = [AGSSimpleMarkerSymbol simpleMarkerSymbolWithColor:[[UIColor greenColor] colorWithAlphaComponent:.5]];
    [symbol setSize:CGSizeMake(14,14)];
    [self.missionPropertiesLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:symbol]];
    [self.mapView addMapLayer:self.missionPropertiesLayer withName:@"missionProperties"];
}

- (void)clearGraphics
{
    [self.observationsLayer removeAllGraphics];
    [self.gpsPointsLayer removeAllGraphics];
    [self.missionPropertiesLayer removeAllGraphics];
}

- (void)reloadGraphics
{
    if (!self.context || !self.mapView.loaded) {
        NSLog(@"Can't reload Graphics.  Context and/or map is not available.");
        return;
    }
    NSLog(@"Loading exisitng graphics from coredata");
    [self clearGraphics];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"GpsPoint"];
    NSError *error = [[NSError alloc] init];
    NSArray *results = [self.context executeFetchRequest:request error:&error];
    NSLog(@"Loading %d gpsPoints", results.count);
    if (!results && error.code)
        NSLog(@"Error Fetching GpsPoint %@",error);
    for (GpsPoint *gpsPoint in results) {
        [self drawGpsPoint:gpsPoint];
        if (gpsPoint.observation) {
            [self loadObservation:gpsPoint.observation];
        }
        if (gpsPoint.missionProperty) {
            [self loadMissionProperty:gpsPoint.missionProperty];
        }
    }

    //Get adhoc observations (gpsPoint is null and adhocLocation is non nil
    //TODO: support more than one Observation feature
    request = [NSFetchRequest fetchRequestWithEntityName:@"Observation"];
    request.predicate = [NSPredicate predicateWithFormat:@"gpsPoint == NIL AND adhocLocation != NIL"];
    results = [self.context executeFetchRequest:request error:&error];
    if (!results && error.code)
        NSLog(@"Error Fetching Observations %@",error);
    NSLog(@"Loading %d adhoc observations", results.count);
    for (Observation *observation in results) {
        [self loadObservation:observation];
    }
}

- (AGSPoint *)mapPointFromGpsPoint:(GpsPoint *)gpsPoint
{
    AGSPoint *point = [AGSPoint pointWithX:gpsPoint.longitude y:gpsPoint.latitude spatialReference:self.wgs84];
    point = (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:point toSpatialReference:self.mapView.spatialReference];
    return point;
}




#pragma mark - Private Methods - support for data model - Surveys

- (void)changeSurvey
{
    if (self.survey == self.surveys.selectedSurvey) {
        return;
    }

    [self closeOpenSurveyWithConcurrentOpen:(self.surveys.selectedSurvey != nil)];

    if (self.surveys.selectedSurvey) {
        self.selectSurveyButton.title = @"Loading Survey...";
        NSLog(@"Opening Survey document");
        [self incrementBusy];
        [self.surveys.selectedSurvey openDocumentWithCompletionHandler:^(BOOL success) {
            //do any other background work;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    self.survey = self.surveys.selectedSurvey;
                    self.context = self.survey.document.managedObjectContext;
                    [self logStats];
                    [self reloadGraphics];
                } else {
                    [[[UIAlertView alloc] initWithTitle:@"Fail" message:@"Unable to open the survey." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
                    self.survey = nil;

                }
                [self updateTitleBar];
                [self decrementBusy];
            });
        }];
    }
}

- (void)closeOpenSurveyWithConcurrentOpen:(BOOL)concurrentOpen
{
    //TODO: this works, but logs background errors when called after a active document is deleted.
    if (self.survey) {
        if (self.survey.document.documentState == UIDocumentStateNormal) {
            [self incrementBusy];
            self.selectSurveyButton.title = @"Closing Survey...";
            [self stopRecording];
            [self.survey closeWithCompletionHandler:^(BOOL success) {
                //do any other background work;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        if (!concurrentOpen) {
                            self.survey = nil;
                            [self updateTitleBar];
                        } //else similar actions will be performed when the concurrent open finishes
                    } else {
                        [[[UIAlertView alloc] initWithTitle:@"Fail" message:@"Unable to close the survey." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
                    }
                    [self decrementBusy];
                });
            }];
        } else if (self.survey.document.documentState != UIDocumentStateClosed) {
            NSLog(@"Survey is in an abnormal state: %d", self.survey.document.documentState);
            [[[UIAlertView alloc] initWithTitle:@"Oh No!" message:@"Survey is not in a closable state." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
        }
    }
}




#pragma mark - Private Methods - support for data model - gps points

- (GpsPoint *)createGpsPoint:(CLLocation *)gpsData
{
    if (!self.context) {
        NSLog(@"Can't create GPS point, there is no data context (file)");
        return nil;
    }
    if (self.lastGpsPointSaved && [self.lastGpsPointSaved.timestamp timeIntervalSinceDate:gpsData.timestamp] == 0) {
        return self.lastGpsPointSaved;
    }
    NSLog(@"Saving GpsPoint, Lat = %f, lon = %f, timestamp = %@", gpsData.coordinate.latitude, gpsData.coordinate.longitude, gpsData.timestamp);
    GpsPoint *gpsPoint = [NSEntityDescription insertNewObjectForEntityForName:@"GpsPoint"
                                                       inManagedObjectContext:self.context];
    gpsPoint.mission = self.mission;
    gpsPoint.altitude = gpsData.altitude;
    gpsPoint.course = gpsData.course;
    gpsPoint.horizontalAccuracy = gpsData.horizontalAccuracy;
    gpsPoint.latitude = gpsData.coordinate.latitude;
    gpsPoint.longitude = gpsData.coordinate.longitude;
    gpsPoint.speed = gpsData.speed;
    gpsPoint.timestamp = gpsData.timestamp ?: [NSDate date]; //FIXME - added for testing on simulator, remove for production
    gpsPoint.verticalAccuracy = gpsData.verticalAccuracy;
    self.lastGpsPointSaved = gpsPoint;
    return gpsPoint;
}

- (GpsPoint *)gpsPointAtTimestamp:(NSDate *)timestamp
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"GpsPoint"];
    request.predicate = [NSPredicate predicateWithFormat:@"timestamp = %@",timestamp];
    NSArray *results = [self.context executeFetchRequest:request error:nil];
    return (GpsPoint *)[results lastObject]; // will return null if there was an error, or no results
}

- (void)drawGpsPoint:(GpsPoint *)gpsPoint
{
    if (!gpsPoint)
        return;

    AGSPoint *point = [self mapPointFromGpsPoint:gpsPoint];
    [self drawGpsPoint:gpsPoint atMapPoint:point];
}

- (void)drawGpsPoint:(GpsPoint *)gpsPoint atMapPoint:(AGSPoint *)mapPoint
{
    if (!gpsPoint || !mapPoint) {
        NSLog(@"Cannot draw gpsPoint (%@) @ mapPoint (%@)",gpsPoint, mapPoint);
        return;
    }
    //FIXME: figure out which attributes to show with GPS points
    NSDictionary *attributes = @{@"date":gpsPoint.timestamp?:[NSNull null]};
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attributes];
    [self.gpsPointsLayer addGraphic:graphic];

    //FIXME: draw a tracklog polyline, vary symbology based on self.isObserving
}




#pragma mark - Private Methods - support for data model - observations

- (Observation *)createObservation
{
    if (!self.context) {
        NSLog(@"Can't create Observation, there is no data context (file)");
        return nil;
    }
    NSLog(@"Creating Observation managed object");
    //FIXME: support more than one type of observation
    Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation"
                                                             inManagedObjectContext:self.context];
    observation.mission = self.mission;
    //We don't have any attributes yet, that will get created/added later depending on the protocol
    return observation;
}

- (Observation *)createObservationAtGpsPoint:(GpsPoint *)gpsPoint
{
    if (!gpsPoint) {
        NSLog(@"Can't save Observation at GPS point without a GPS Point");
        return nil;
    }
    NSLog(@"Creating Observation at GPS point");
    Observation *observation = [self createObservation];
    observation.gpsPoint = gpsPoint;
    return observation;
}

- (Observation *)createObservationAtGpsPoint:(GpsPoint *)gpsPoint withAdhocLocation:(AGSPoint *)mapPoint
{
    if (!mapPoint) {
        NSLog(@"Can't save Observation at Adhoc Location without a Map Point");
        return nil;
    }
    Observation *observation = [self createObservation];
    if (!observation) {
        return nil;
    }
    NSLog(@"Adding Adhoc Location to Observation");
    AdhocLocation *adhocLocation = [NSEntityDescription insertNewObjectForEntityForName:@"AdhocLocation"
                                                                 inManagedObjectContext:self.context];
    //mapPoint is in the map coordinates, convert to WGS84
    AGSPoint *wgs84Point = (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:mapPoint toSpatialReference:self.wgs84];
    adhocLocation.latitude = wgs84Point.y;
    adhocLocation.longitude = wgs84Point.x;
    if (gpsPoint) {
        observation.gpsPoint = gpsPoint; //optional
    } else {
        adhocLocation.timestamp = [NSDate date];
    }
    adhocLocation.map = self.currentMapEntity;
    observation.adhocLocation = adhocLocation;
    return observation;
}

- (Observation *)createObservationAtGpsPoint:(GpsPoint *)gpsPoint withAngleDistanceLocation:(LocationAngleDistance *)location
{
    if (!gpsPoint) {
        NSLog(@"Can't save Observation at Angle/Distance without a GPS Point");
        return nil;
    }
    Observation *observation = [self createObservationAtGpsPoint:gpsPoint];
    if (!observation) {
        return nil;
    }
    NSLog(@"Adding Angle = %f, Distance = %f, Course = %f to observation",
          location.absoluteAngle, location.distanceMeters, location.deadAhead);

    AngleDistanceLocation *angleDistance = [NSEntityDescription insertNewObjectForEntityForName:@"AngleDistanceLocation"
                                                                         inManagedObjectContext:self.context];
    angleDistance.angle = location.absoluteAngle;
    angleDistance.distance = location.distanceMeters;
    angleDistance.direction = location.deadAhead;
    observation.angleDistanceLocation = angleDistance;
    return observation;
}

- (void)loadObservation:(Observation *)observation
{
    AGSPoint *point;
    if (observation.angleDistanceLocation) {
        LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:observation.angleDistanceLocation.direction
                                                                                  protocol:self.survey.protocol
                                                                             absoluteAngle:observation.angleDistanceLocation.angle
                                                                                  distance:observation.angleDistanceLocation.distance];
        //The point must be in a projected coordinate system to apply an angle and distance
        point = [location pointFromPoint:[self mapPointFromGpsPoint:observation.gpsPoint]];
    }
    else if (observation.adhocLocation) {
        point = [AGSPoint pointWithX:observation.adhocLocation.longitude y:observation.adhocLocation.latitude spatialReference:self.wgs84];
        point = (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:point toSpatialReference:self.mapView.spatialReference];
    }
    else if (observation.gpsPoint) {
        point = [self mapPointFromGpsPoint:observation.gpsPoint];
    }
    [self drawObservation:observation atPoint:point];
}

- (void)drawObservation:(Observation *)observation atPoint:(AGSPoint *)mapPoint
{
    if (!observation || !mapPoint) {
        NSLog(@"Cannot draw observation (%@).  It has no location", observation);
        return;
    }
    //The graphic is drawn before we get the attributes, so set them to nil
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:nil];
    [self.observationsLayer addGraphic:graphic];
}

- (void)setAttributesForObservation:(Observation *)observation atPoint:(AGSPoint *)mapPoint
{
    //TODO: support more than just one feature called Observations
    NSDictionary *config = self.surveys.selectedSurvey.protocol.dialogs[@"Observation"];
    QRootElement *root = [[QRootElement alloc] initWithJSON:config andData:nil];
    AttributeViewController *dialog = [[AttributeViewController alloc] initWithRoot:root];
    dialog.managedObject = observation;
    self.modalAttributeCollector = [[UINavigationController alloc] initWithRootViewController:dialog];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(saveAttributes:)];
    dialog.toolbarItems = @[doneButton];
    self.modalAttributeCollector.toolbarHidden = NO;
    self.modalAttributeCollector.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:self.modalAttributeCollector animated:YES completion:nil];
}




#pragma mark - Private Methods - support for data model - mission properties

- (MissionProperty *)createMissionProperty
{
    if (!self.context) {
        NSLog(@"Can't create MissionProperty, there is no data context (file)");
        return nil;
    }
    NSLog(@"Creating MissionProperty managed object");
    //FIXME: support more than one type of observation
    MissionProperty *missionProperty = [NSEntityDescription insertNewObjectForEntityForName:@"MissionProperty" inManagedObjectContext:self.context];
    missionProperty.mission = self.mission;
    //We don't have any attributes yet, that will get created/added later depending on the protocol
    return missionProperty;
}

- (MissionProperty *)createMissionPropertyAtGpsPoint:(GpsPoint *)gpsPoint
{
    if (!gpsPoint) {
        NSLog(@"Can't save MissionProperty at GPS point without a GPS Point");
        return nil;
    }
    NSLog(@"Creating MissionProperty at GPS point");
    MissionProperty *missionProperty = [self createMissionProperty];
    missionProperty.gpsPoint = gpsPoint;
    return missionProperty;
}

- (void)loadMissionProperty:(MissionProperty *)missionProperty
{
    AGSPoint *point;
    if (missionProperty.gpsPoint) {
        point = [self mapPointFromGpsPoint:missionProperty.gpsPoint];
    }
    [self drawMissionProperty:missionProperty atPoint:point];
}

- (void)drawMissionProperty:(MissionProperty *)missionProperty atPoint:(AGSPoint *)mapPoint
{
    if (!missionProperty || !mapPoint) {
        NSLog(@"Cannot draw missionProperty (%@).  It has no location", missionProperty);
        return;
    }
    //The graphic is drawn before we get the attributes, so set them to nil
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:nil];
    [self.missionPropertiesLayer addGraphic:graphic];
}

- (void)setAttributesForMissionProperty:(MissionProperty *)missionProperty atPoint:(AGSPoint *)mapPoint
{
    if (self.modalAttributeCollector) {
        return;
    }
    NSDictionary *config = self.surveys.selectedSurvey.protocol.dialogs[@"MissionProperty"];
    QRootElement *root = [[QRootElement alloc] initWithJSON:config andData:nil];
    AttributeViewController *dialog = [[AttributeViewController alloc] initWithRoot:root];
    dialog.managedObject = missionProperty;
    self.modalAttributeCollector = [[UINavigationController alloc] initWithRootViewController:dialog];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(saveAttributes:)];
    dialog.toolbarItems = @[doneButton];
    self.modalAttributeCollector.toolbarHidden = NO;
    self.modalAttributeCollector.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:self.modalAttributeCollector animated:YES completion:nil];
}




#pragma mark - Private Methods - misc support

// Called by done button on attribute dialogs
- (void)saveAttributes:(UIBarButtonItem *)sender
{
    NSLog(@"saving attributes");
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    AttributeViewController *dialog = [self.modalAttributeCollector.viewControllers firstObject];
    [dialog.root fetchValueUsingBindingsIntoObject:dict];
    NSManagedObject *obj = dialog.managedObject;
    for (NSString *aKey in dict){
        //TODO: do I need to add error checking, respondsToSelector did not work
        //if ([obj respondsToSelector:NSSelectorFromString(aKey)]) {
        [obj setValue:[dict valueForKey:aKey] forKey:aKey];
        //}
    }
    [self.modalAttributeCollector dismissViewControllerAnimated:YES completion:nil];
    self.modalAttributeCollector = nil;
}




#pragma mark - Diagnostic Aids - to be removed

//FIXME: Rob some of the following code for deleting an individual observation
//- (void)clearData
//{
//    if (!self.context) {
//        return;
//    }
//
//    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Observation"];
//    NSError *error = [[NSError alloc] init];
//    NSArray *results = [self.context executeFetchRequest:request error:&error];
//    if (!results && error.code)
//        NSLog(@"Error Fetching Observation %@",error);
//    for (Observation *observation in results) {
//        [self.context deleteObject:observation];
//    }
//    request = [NSFetchRequest fetchRequestWithEntityName:@"GpsPoint"];
//    results = [self.context executeFetchRequest:request error:&error];
//    if (!results && error.code)
//        NSLog(@"Error Fetching GpsPoints%@",error);
//    for (GpsPoint *gpsPoint in results) {
//        [self.context deleteObject:gpsPoint];
//    }
//    self.lastGpsPointSaved = nil;
//}


//TODO: this is the dictionary of atttributes attached to the AGSGraphic.  not used at this point
- (NSDictionary *)createAttributesFromObservation:(Observation *)observation
{
    NSDictionary *attributes = @{@"date":self.locationManager.location.timestamp?:[NSNull null]};
    return attributes;
}

// not called when popover is dismissed programatically - use callbacks instead
- (void)dismissQuickDialogPopover:(UIPopoverController *)popoverController
{
    UIViewController * vc = popoverController.contentViewController;
    QuickDialogController *qd;
    //[self updateTitle];
    self.quickDialogPopoverController = nil;
    if ([vc isKindOfClass:[QuickDialogController class]]) {
        qd = (QuickDialogController *)vc;
    }
    if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)vc;
        if ([[nav.viewControllers firstObject] isKindOfClass:[QuickDialogController class]]) {
            qd = [nav.viewControllers firstObject];
        }
    }
    if (!qd) {
        return;
    }
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [qd.root fetchValueUsingBindingsIntoObject:dict];

    NSString *msg = @"Form Values:";
    for (NSString *aKey in dict){
        msg = [msg stringByAppendingFormat:@"\n %@ = %@", aKey, [dict valueForKey:aKey]];
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Testing Info"
                                                    message:msg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}

- (void)logStats
{
    NSLog(@"survey document open");
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"GpsPoint"];
    NSArray *results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    NSLog(@"There are %d GpsPoints", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:@"Observation"];
    results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    NSLog(@"There are %d Observations", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:@"MissionProperty"];
    results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    NSLog(@"There are %d MissionYroperties", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:@"Mission"];
    results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    NSLog(@"There are %d Missions", results.count);
    request = [NSFetchRequest fetchRequestWithEntityName:@"Map"];
    results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
    NSLog(@"There are %d Maps", results.count);
}

@end
