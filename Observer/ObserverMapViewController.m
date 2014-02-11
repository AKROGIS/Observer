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


#define kGpsPointsLayer            @"gpsPointsLayer"
#define kObservationLayer          @"observationsLayer"
#define kMissionPropertiesLayer    @"missionPropertiesLayer"
#define kObservingTracksLayer      @"observingTracksLayer"
#define kNotObservingTracksLayer   @"notObservingTracksLayer"


@interface ObserverMapViewController () {
    CGFloat _initialRotationOfViewAtGestureStart;
}

//Model
@property (strong, nonatomic) SurveyCollection* surveys;
@property (strong, nonatomic) MapCollection* maps;
@property (weak,   nonatomic, readonly) Survey *survey; //short cut to self.surveys.selectedSurvey
@property (weak,   nonatomic, readonly) NSManagedObjectContext *context; //shortcut to self.survey.document.managedObjectContext

//Views
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *noMapLabel;
@property (weak, nonatomic) IBOutlet UIButton *compassRoseButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *mapLoadingIndicator;

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
@property (strong, nonatomic) SProtocol *protocolForSurveyCreation;

//FIXME: remove this property, it is a hack to make things compile while testing
@property (strong, nonatomic) ProtocolFeature *currentProtocolFeature;

@property (strong, nonatomic) AGSSpatialReference *wgs84;
@property (strong, nonatomic) NSMutableDictionary *graphicsLayers; // of AGSGraphicsLayer

@property (strong, nonatomic) UIPopoverController *angleDistancePopoverController;
@property (strong, nonatomic) UIPopoverController *mapsPopoverController;
@property (strong, nonatomic) UIPopoverController *surveysPopoverController;
@property (strong, nonatomic) UIPopoverController *quickDialogPopoverController;
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
    [self configureObservationButton];
    [self initializeData];
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
    UIViewController *vc1 = [segue destinationViewController];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UINavigationController *nav = [segue destinationViewController];
        vc1 = [nav.viewControllers firstObject];
    }

    if ([[segue identifier] isEqualToString:@"AngleDistancePopOver"])
    {
        AngleDistanceViewController *vc = (AngleDistanceViewController*)vc1;

        //create/save current GpsPoint, because it may take a while for the user to enter an angle/distance
        GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
        AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
        double currentCourse = gpsPoint.course;

        LocationAngleDistance *location;
        if (0 <= currentCourse) {
            location = [[LocationAngleDistance alloc] initWithDeadAhead:currentCourse protocolFeature:self.currentProtocolFeature];
        }
        else {
            double currentHeading = self.locationManager.heading.trueHeading;
            if (0 <= currentHeading) {
                location = [[LocationAngleDistance alloc] initWithDeadAhead:currentHeading protocolFeature:self.currentProtocolFeature];
            }
            else {
                location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocolFeature:self.currentProtocolFeature];
            }
        }
        vc.location = location;

        if ([segue isKindOfClass:[UIStoryboardPopoverSegue class]]) {
            self.angleDistancePopoverController = ((UIStoryboardPopoverSegue *)segue).popoverController;
            vc.popover = self.angleDistancePopoverController;
            vc.popover.delegate = self;
        }
        vc.completionBlock = ^(AngleDistanceViewController *controller) {
            self.angleDistancePopoverController = nil;
            Observation *observation = [self createObservation:self.currentProtocolFeature atGpsPoint:gpsPoint withAngleDistanceLocation:controller.location];
            [self drawObservation:observation atPoint:[controller.location pointFromPoint:mapPoint]];
            [self setAttributesForFeatureType:self.currentProtocolFeature entity:observation defaults:nil atPoint:mapPoint];
        };
        vc.cancellationBlock = ^(AngleDistanceViewController *controller) {
            self.angleDistancePopoverController = nil;
        };
    }

    if ([segue.identifier isEqualToString:@"Select Survey"]){
        SurveySelectViewController *vc = (SurveySelectViewController *)vc1;
        vc.title = segue.identifier;
        vc.items = self.surveys;
        vc.selectedSurveyChanged = ^(Survey *oldSurvey, Survey *newSurvey){
            if (oldSurvey != newSurvey) {
                [self closeSurvey:oldSurvey withConcurrentOpen:YES];
                [self openSurvey];
            }
        };
        vc.popoverDismissed = ^{
            self.surveysPopoverController = nil;
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
        MapSelectViewController *vc = (MapSelectViewController *)vc1;
        vc.title = segue.identifier;
        vc.items = self.maps;
        vc.rowSelectedCallback = ^(NSIndexPath*indexPath){
            [self resetBasemap];
            self.mapsPopoverController = nil;
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
    AKRLog(@"Add Mission Property");
    //FIXME: populate form with prior values or defaults
    //FIXME: if gps, then add at GPS else add adhoc at current location
    //launch pop up to enter attributes, use existing as defaults

    if (self.quickDialogPopoverController) {
        return;
    }
    //create VC from QDialog json in protocol, add newController to popover, display popover
    NSDictionary *dialog = self.survey.protocol.missionFeature.dialogJSON;
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
    Observation *observation = [self createObservation:self.currentProtocolFeature atGpsPoint:gpsPoint];
    AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
    [self drawObservation:observation atPoint:mapPoint];
    [self setAttributesForFeatureType:self.currentProtocolFeature entity:observation defaults:nil atPoint:mapPoint];
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
    Observation *observation = [self createObservation:self.currentProtocolFeature atGpsPoint:gpsPoint withAdhocLocation:self.mapView.mapAnchor];
    [self drawObservation:observation atPoint:self.mapView.mapAnchor];
    [self setAttributesForFeatureType:self.currentProtocolFeature entity:observation defaults:nil atPoint:self.mapView.mapAnchor];
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
        [protocols openWithCompletionHandler:^(BOOL openSuccess) {
            SProtocol *protocol = [protocols openURL:url];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (openSuccess && protocol.isValid) {
                    self.protocolForSurveyCreation = protocol;
                    [[[UIAlertView alloc] initWithTitle:@"New Protocol" message:@"Do you want to open a new survey file with this protocol?" delegate:nil cancelButtonTitle:@"Maybe Later" otherButtonTitles:@"Yes", nil] show];
                    // handle response in UIAlertView delegate method
                } else {
                    [[[UIAlertView alloc] initWithTitle:@"Protocol Problem" message:@"Can't open/read the protocol file" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                }
            });
        }];
    }

    return success;
}

- (void)closeSurvey
{
    [self closeSurvey:self.survey withConcurrentOpen:NO];
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

    //TODO: check how many locations might be returned (are we missing any?)
    CLLocation *location = [locations lastObject];
    //TODO: simulator returns -1 for speed, so ignore it for testing.  remove from production code.
    //if (!location || location.speed < 0)
    if (!location)
        return;

    if (self.isRecording) {
        if (![self isNewLocation:location]) {
            GpsPoint *gpsPoint = [self createGpsPoint:location];
            //this requires a reprojection of the gpsPoint to the map's coordinate system.
            [self drawGpsPoint:gpsPoint];
            //I could use the following, however i'm not sure mapLocation and CLlocation will be in sync.
            //[self drawGpsPointAtMapPoint:self.mapView.locationDisplay.mapLocation];
        }
    }

    //use the speed to update the autorotation behavior
    [self.autoPanController speedUpdate:location.speed];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    //AKRLog(@"locationManager: didUpdateHeading: %f",newHeading.trueHeading);
    [self rotateNorthArrow];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    //TODO: put up an alertview
    AKRLog(@"Location Manager Failed: %@",error.localizedDescription);
}




#pragma mark - Delegate Methods: AGSLayerDelegate (all optional)

- (void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error
{
    // Tells the delegate that the layer failed to load with the specified error.
    AKRLog(@"layer %@ failed to load with error %@", layer, error);
    [self decrementBusy];
    self.noMapLabel.hidden = NO;
    //TODO: put up an alertview
}




#pragma mark - Delegate Methods: AGSMapViewLayerDelegate (all optional)

- (void)mapViewDidLoad:(AGSMapView*)mapView
{
    //Tells the delegate the map is loaded and ready for use. Fires when the map’s base layer loads.
    AKRLog(@"Basemap has been loaded");
    self.noMapLabel.hidden = YES;
    [self initializeGraphicsLayer];
    [self reloadGraphics];
    [self setupGPS];
    [self decrementBusy];
}

- (BOOL)mapView:(AGSMapView *)mapView shouldHitTestLayer:(AGSLayer *)layer atPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint
{
    //Asks delegate whether to find which graphics in the specified layer intersect the tapped location. Default is YES.
    //This function may or may not be called on the main thread.
    //AKRLog(@"mapView:shouldFindGraphicsInLayer:(%f,%f)=(%@) with graphics Layer:%@", screen.x, screen.y, mappoint, graphicsLayer.name);
    BOOL findableLayer = !([layer.name isEqualToString:kGpsPointsLayer] ||
                           [layer.name isEqualToString:kObservingTracksLayer] ||
                           [layer.name isEqualToString:kNotObservingTracksLayer]);
    return findableLayer;
}




#pragma mark - Delegate Methods: AGSMapViewTouchDelegate (all optional)

- (void)mapView:(AGSMapView *)mapView didClickAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint features:(NSDictionary *)features
{
    //Tells the delegate the map was single-tapped at specified location.
    //features: id<AGSFeature> objects from all hit-testable layers in the map that intersect or contain the location.
    //The dictionary contains layer name (key) : Array of id<AGSFeature> (value)

    AKRLog(@"mapView:didClickAtPoint:(%f,%f)=(%@) with graphics:%@", screen.x, screen.y, mappoint, features);

    switch (features.count) {  //Number of layers with selected features
        case 0:
            if (self.isObserving) {
                switch (self.survey.protocol.featuresWithLocateByTouch.count) {
                    case 0:
                        break;
                    case 1:
                        [self addFeature:self.survey.protocol.featuresWithLocateByTouch[0] atMapPoint:mappoint];
                        break;
                    default:
                        [self presentProtocolFeatureSelector:self.survey.protocol.featuresWithLocateByTouch atPoint:screen mapPoint:mappoint];
                        break;
                }
            }
            break;
        case 1: {
            NSString *layerName = (NSString *)[features.keyEnumerator nextObject];
            NSArray *featureList = features[layerName];
            if (featureList.count == 1) {  //Number of selected features in layer
                [self presentFeature:featureList[0] fromLayer:layerName atPoint:screen];
            } else {
                [self presentAGSFeatureSelector:features atPoint:screen];
            }
            break;
        }
        default:
            [self presentAGSFeatureSelector:features atPoint:screen];
            break;
    }
}




#pragma mark - move these 4 methods

- (void)presentProtocolFeatureSelector:(NSArray *)features atPoint:(CGPoint)screenpoint mapPoint:(AGSPoint *)mappoint
{
    //FIXME: implement
    //present popover at screenpoint with table view controller (1 section, rows = feature.names),
    //send selected feature to     [self addFeature:feature atMapPoint:mappoint];
    [features enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *name = ((ProtocolFeature *)obj).name;
        AKRLog(@"Found features %@", name);
    }];
    [self addFeature:[features lastObject] atMapPoint:mappoint];
}

- (void)addFeature:(ProtocolFeature *)feature atMapPoint:(AGSPoint *)mappoint
{
    Observation *observation = [self createObservation:feature atGpsPoint:self.lastGpsPointSaved withAdhocLocation:mappoint];
    [self drawObservation:observation atPoint:mappoint];
    [self setAttributesForFeatureType:feature entity:observation defaults:nil atPoint:mappoint];
}

- (void)presentAGSFeatureSelector:(NSDictionary *)features atPoint:(CGPoint)screen
{
    //FIXME: implement
    //present popover with table view controller (layernames = sections, features = rows),
    //send selected feature to
    //[self presentFeature:feature[layerName] fromLayer:layerName];
    __block NSString *layerName;
    __block id<AGSFeature> graphic;
    [features enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        layerName = (NSString *)key;
        NSArray *graphics = (NSArray *)obj;
        graphic = [graphics lastObject];
        AKRLog(@"Found %u features in %@",[graphics count], layerName);
    }];
    [self presentFeature:graphic fromLayer:layerName atPoint:screen];
}

- (void)presentFeature:(id<AGSFeature>)agsFeature fromLayer:(NSString *)layerName atPoint:(CGPoint)screen
{
    NSDate *timestamp = (NSDate *)[agsFeature safeAttributeForKey:@"timestamp"];

    AKRLog(@"Presenting feature for layer %@ with timestamp %@", layerName, timestamp);

    //Note: entityNamed:atTimestamp: only works with layers that have a gpspoint or an adhoc, so missionProperties and Observations
    //Note: gpsPoints do not have a QuickDialog definition; tracklogs would need to use the related missionProperty
    //TODO: expand to work on gpsPoints and tracklog segments
    for (NSString *badName in @[kGpsPointsLayer,
                                [NSString stringWithFormat:@"%@_On", kMissionPropertyEntityName],
                                [NSString stringWithFormat:@"%@_Off", kMissionPropertyEntityName]]) {
        if ([layerName isEqualToString:badName]) {
            AKRLog(@"  Bailing. layer type is not supported");
            return;
        }
    }

    //get the feature type from the layername
    ProtocolFeature * feature = nil;
    if ([layerName isEqualToString:self.survey.protocol.missionFeature.name]) {
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
    NSManagedObject *entity = [self entityNamed:layerName atTimestamp:timestamp];

    if (!feature || !entity) {
        AKRLog(@"  Bailing. Could not find the dialog configuration, and/or the feature");
        return;
    }

    //get data from entity attributes (unobscure the key names)
    [self setAttributesForFeatureType:feature entity:entity defaults:entity atPoint:nil];

    //FIXME: if this is an angle distance location, provide button for angle distance editor
    //FIXME: if the feature was changed, save the changes.  (non-editable features i.e. gps points should have a special non-editable dialog)
    //FIXME: can I support a readonly survey, and just look at the attributes with editing disabled??
    //FIXME: if feature is deletable, provide a delete button.
}









- (void)mapView:(AGSMapView *)mapView didTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint features:(NSDictionary *)features
{
    //Tells the delegate that a point on the map was tapped and held at specified location.
    //The dictionary contains NSArrays of intersecting AGSGraphics keyed on the layer name
    AKRLog(@"mapView:didTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", screen.x, screen.y, mappoint, features);
    if (0 < [features count]) {
        AKRLog(@"Try to move selected graphic - if allowed");
        //if feature is an adhoc location (no need to check if adhoc is allowed, as it must be since the user created one)
        //   then just move it
        //if feature is an angle distance feature
        //   then flash the gps observation point and open the angle distance dialog on that point (try not to hide observation)
        //   move the feature when the dialog is dismissed.
        //ignore GPS locations
    }
}

- (void)mapView:(AGSMapView *)mapView didMoveTapAndHoldAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint features:(NSDictionary *)features
{
    //Tells the delegate that the user moved his finger while tapping and holding on the map.
    //Sent continuously to allow tracking of the movement
    //The dictionary contains NSArrays of intersecting AGSGraphics keyed on the layer name
    AKRLog(@"mapView:didMoveTapAndHoldAtPoint:(%f,%f)=(%@) with Graphics:%@", screen.x, screen.y, mappoint, features);
    AGSGraphic *graphic = [features[kObservationLayer] lastObject];
    if (graphic) {
        [graphic setGeometry:mappoint];
    }
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
    if (popoverController == self.quickDialogPopoverController) {
        [self dismissQuickDialogPopover:popoverController];
    }
}




#pragma mark - Delegate Methods: UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"New Protocol"]) {
        if (buttonIndex == 1) {  //Yes to create/open a new survey
            if (self.surveysPopoverController) {
                UIViewController *vc = self.surveysPopoverController.contentViewController;
                if ([vc isKindOfClass:[UINavigationController class]]) {
                    vc = ((UINavigationController *)vc).visibleViewController;
                }
                if ([vc isKindOfClass:[SurveySelectViewController class]]) {
                    //This method will put up its own alert if it cannot create the survey
                    [(SurveySelectViewController *)vc newSurveyWithProtocol:self.protocolForSurveyCreation];
                    //since the survey select view is up, let the user decide which survey they want to select
                }
            } else {
                NSUInteger indexOfNewSurvey = [self.surveys newSurveyWithProtocol:self.protocolForSurveyCreation];
                if (indexOfNewSurvey != NSNotFound) {
                    [self closeSurvey:self.survey withConcurrentOpen:YES];
                    [self.surveys setSelectedSurvey:indexOfNewSurvey];
                    [self openSurvey];
                } else {
                    [[[UIAlertView alloc] initWithTitle:@"Survey Problem" message:@"Can't create a survey with this protocol" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                }
            }
        }
    }
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
        AKRLog(@"Looking for %@ in coredata",self.maps.selectedLocalMap);
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kMapEntityName];

        request.predicate = [NSPredicate predicateWithFormat:@"name == %@ AND author == %@ AND date == %@",
                             self.maps.selectedLocalMap.title, self.maps.selectedLocalMap.author, self.maps.selectedLocalMap.date];
        NSArray *results = [self.survey.document.managedObjectContext executeFetchRequest:request error:nil];
        _currentMapEntity = [results firstObject];
        if(!_currentMapEntity) {
            AKRLog(@"  Map not found, creating new CoreData Entity");
            _currentMapEntity = [NSEntityDescription insertNewObjectForEntityForName:kMapEntityName inManagedObjectContext:self.context];
            _currentMapEntity.name = self.maps.selectedLocalMap.title;
            _currentMapEntity.author = self.maps.selectedLocalMap.author;
            _currentMapEntity.date = self.maps.selectedLocalMap.date;
        }
    }
    return _currentMapEntity;
}

@synthesize survey = _survey;

- (Survey *)survey
{
    return self.surveys.selectedSurvey;
}

@synthesize context = _context;

- (NSManagedObjectContext *)context
{
    return self.surveys.selectedSurvey.document.managedObjectContext;
}



#pragma mark - Private - UI configuration

- (void)configureMapView
{
    self.mapView.layerDelegate = self;
    self.mapView.touchDelegate = self;
    self.mapView.callout.delegate = self;
    self.mapView.locationDisplay.interfaceOrientation = self.interfaceOrientation;
}

- (void)configureGpsButton
{
    self.autoPanController = [[AutoPanStateMachine alloc] init];
    self.autoPanController.mapView = self.mapView;
    self.autoPanController.compassRoseButton = self.compassRoseButton;
    self.autoPanController.autoPanModeButton = self.panButton;
}

- (void)configureObservationButton
{

}

- (void)initializeData
{
    [self incrementBusy];
    self.surveys = [SurveyCollection sharedCollection];
    [self.surveys openWithCompletionHandler:^(BOOL success) {
        //do any other background work;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openSurvey];
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
    self.addObservationBarButton.enabled = NO;
    self.addGpsObservationBarButton.enabled = NO;
    self.addAdObservationBarButton.enabled = NO;
}

-(void)enableControls
{
    self.selectMapButton.enabled = self.maps != nil;
    self.selectSurveyButton.enabled = self.surveys != nil;

    self.panButton.enabled = self.mapView.loaded;

    self.startStopRecordingBarButtonItem.enabled = self.survey != nil;
    self.startStopObservingBarButtonItem.enabled = self.isRecording && self.survey;
    //TODO: if there are no mission properties, we should remove this button.
    self.editEnvironmentBarButton.enabled = self.isRecording && self.survey && self.survey.protocol.missionFeature.attributes.count > 0;
    //TODO: support more than just one feature called "Observations"
    //TODO:can we support adding observations that have no attributes (no dialog)
    self.addObservationBarButton.enabled = self.isObserving && self.survey && self.survey.protocol.features.count > 0;
    self.addGpsObservationBarButton.enabled = self.isObserving && self.survey &&self.survey.protocol.features.count > 0;
    //TODO: if basemap is in a geographic projection, then angle and distance calculations will not work, so disable angle/distance button
    //TODO: availability of the Angle Distance button is dependent on protocol
    self.addAdObservationBarButton.enabled = self.isObserving && self.maps.selectedLocalMap && self.survey && self.survey.protocol.features.count > 0;
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
    self.compassRoseButton.transform = CGAffineTransformMakeRotation(radians);
}

- (void)startRecording
{
    AKRLog(@"start recording");
    self.isRecording = YES;
    self.startStopObservingBarButtonItem.enabled = YES;
    [self setBarButtonAtIndex:5 action:@selector(startStopRecording:) ToPlay:NO];
    [self startLocationUpdates];
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
    //[self.survey saveWithCompletionHandler:nil];
    self.mission = nil;
}

- (void)startObserving
{
    AKRLog(@"start observing");
    self.isObserving = YES;
    self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:6 action:@selector(startStopObserving:) ToPlay:NO];
    //TDOO: populate the mission property dialog with the last/default dataset
    GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
    MissionProperty *mission = [self createMissionPropertyAtGpsPoint:gpsPoint];
    mission.observing = YES;
    AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
    [self setAttributesForFeatureType:self.survey.protocol.missionFeature entity:mission defaults:self.currentMissionProperty atPoint:mapPoint];
    [self drawMissionProperty:mission atPoint:mapPoint];
    [self enableControls];
}

- (void)stopObserving
{
    AKRLog(@"stop observing");
    self.isObserving = NO;
    self.startStopObservingBarButtonItem = [self setBarButtonAtIndex:6 action:@selector(startStopObserving:) ToPlay:YES];
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
    //FIXME: is 10 seconds a good default?  do I want a user setting? this gets called a lot, so I don't want to slow down with a lookup
    if ([location.timestamp timeIntervalSinceDate:self.lastGpsPointSaved.timestamp] > 10.0)
        return YES;
    return NO;
}




#pragma mark - Private Methods - support for map delegate

- (void)loadBaseMap
{
    AKRLog(@"Loading the basemap");
    [self incrementBusy];
    if (!self.maps.selectedLocalMap.tileCache)
    {
        self.noMapLabel.hidden = NO;
        [self decrementBusy];
    }
    else
    {
        self.maps.selectedLocalMap.tileCache.delegate = self;
        [self.mapView addMapLayer:self.maps.selectedLocalMap.tileCache withName:@"tilecache basemap"];
        //adding a layer is async. wait for AGSLayerDelegate layerDidLoad or layerDidFailToLoad
    }
}

- (void)resetBasemap
{
    //This is only called when the self.maps.currentMap has changed (usually by a user selection in a different view controller)
    //It is not called when the self.maps.currentMap is initialized.

    //A "loaded" mapview has an immutable SR and maxExtents based on the first layer loaded (not on the first layer in the mapView)
    //removing all layers from the mapview does not "unload" the mapview.
    //to reset the mapView extents/SR, we need to call reset, then re-add the layers.
    //first we need to get the layers, so we can re-add them after setting the new basemap
    AKRLog(@"Changing the basemap");
    [self incrementBusy];
    self.currentMapEntity = nil;
    if (!self.maps.selectedLocalMap.tileCache)
    {
        self.noMapLabel.hidden = NO;
        [self decrementBusy];
    }
    else
    {
        [self.mapView reset]; //remove all layers, clear SR, envelope, etc.
        self.maps.selectedLocalMap.tileCache.delegate = self;
        [self.mapView addMapLayer:self.maps.selectedLocalMap.tileCache withName:@"tilecache basemap"];
        //adding a layer is async. wait for AGSLayerDelegate layerDidLoad or layerDidFailToLoad
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
        [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:feature.symbology.agsSymbol]];
        [self.mapView addMapLayer:graphicsLayer withName:feature.name];
        self.graphicsLayers[feature.name] = graphicsLayer;
    }

    //Mission Property points
    ProtocolMissionFeature *feature = self.survey.protocol.missionFeature;
    graphicsLayer = [[AGSGraphicsLayer alloc] init];
    [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:feature.symbology.agsSymbol]];
    [self.mapView addMapLayer:graphicsLayer withName:kMissionPropertyEntityName];
    self.graphicsLayers[kMissionPropertyEntityName] = graphicsLayer;
    //Mission Property observing tracks
    NSString * name = [NSString stringWithFormat:@"%@_On", kMissionPropertyEntityName];
    graphicsLayer = [[AGSGraphicsLayer alloc] init];
    [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:feature.observingymbology.agsSymbol]];
    [self.mapView addMapLayer:graphicsLayer withName:name];
    self.graphicsLayers[name] = graphicsLayer;
    //Mission Property not observing track
    name = [NSString stringWithFormat:@"%@_Off", kMissionPropertyEntityName];
    graphicsLayer = [[AGSGraphicsLayer alloc] init];
    [graphicsLayer setRenderer:[AGSSimpleRenderer simpleRendererWithSymbol:feature.notObservingymbology.agsSymbol]];
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
    [self initializeGraphicsLayer];
}

- (void)reloadGraphics
{
    BOOL surveyReady = self.survey.document.documentState == UIDocumentStateNormal;
    if (!surveyReady || !self.mapView.loaded) {
        AKRLog(@"Loading graphics - can't because %@.", surveyReady ? @"map isn't loaded" : (self.mapView.loaded ? @"survey isn't loaded" : @"map AND survey are null! - how did that happen?"));
        return;
    }
    AKRLog(@"Loading graphics from coredata");
    [self clearGraphics];
    AKRLog(@"  Fetching gpsPoints");
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
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
        //draw the GPS tracks
        //TODO: draw a polyline instead of single lines
        [self drawTrackObserving:observing From:previousPoint to:gpsPoint];

        previousPoint = gpsPoint;
    }

    //Get adhoc observations - these are the only observations where gpsPoint might be null
    AKRLog(@"  Fetching observations");
    request = [NSFetchRequest fetchRequestWithEntityName:kObservationEntityName];
    results = [self.context executeFetchRequest:request error:&error];
    if (!results && error.code)
        AKRLog(@"Error Fetching Observations %@",error);
    AKRLog(@"  Drawing %d observations", results.count);
    for (Observation *observation in results) {
        [self loadObservation:observation];
    }
    //Get MissionProperties were gpsPoint is null
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
    AGSPoint *point = [AGSPoint pointWithX:gpsPoint.longitude y:gpsPoint.latitude spatialReference:self.wgs84];
    point = (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:point toSpatialReference:self.mapView.spatialReference];
    return point;
}




#pragma mark - Private Methods - support for data model - Surveys

- (void)openSurvey
{
    if (self.survey) {
        AKRLog(@"Opening survey document (%@)", self.survey.title);
        self.selectSurveyButton.title = @"Loading survey...";
        [self incrementBusy];
        [self.survey openDocumentWithCompletionHandler:^(BOOL success) {
            //do any other background work;
            dispatch_async(dispatch_get_main_queue(), ^{
                //AKRLog(@"Start OpenSurvey completion handler");
                if (success) {
                    [self logStats];
                    [self reloadGraphics];
                } else {
                    [[[UIAlertView alloc] initWithTitle:@"Fail" message:@"Unable to open the survey." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];

                }
                [self updateTitleBar];
                [self decrementBusy];
            });
        }];
    }
}

- (void)closeSurvey:(Survey *)survey withConcurrentOpen:(BOOL)concurrentOpen
{
    //TODO: this works, but logs background errors when called after a active document is deleted.
    if (survey) {
        AKRLog(@"Closing survey document (%@)", survey.title);
        [self incrementBusy];  //loading the survey document may block
        if (survey.document.documentState == UIDocumentStateNormal) {
            self.selectSurveyButton.title = @"Closing survey...";
            self.currentMapEntity = nil;
            if (self.isRecording) {
                [self stopRecording];
            }
            [survey closeDocumentWithCompletionHandler:^(BOOL success) {
                //this completion handler runs on the main queue;
                //AKRLog(@"Start CloseSurvey completion handler");
                [self decrementBusy];
                if (success) {
                    if (!concurrentOpen) {
                        [self updateTitleBar];
                    } //else similar actions will be performed when the concurrent open finishes
                } else {
                    [[[UIAlertView alloc] initWithTitle:@"Fail" message:@"Unable to close the survey." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
                }
            }];
        } else if (self.survey.document.documentState != UIDocumentStateClosed) {
            AKRLog(@"Survey (%@) is in an abnormal state: %d", survey.title, survey.document.documentState);
            [self decrementBusy];
            [[[UIAlertView alloc] initWithTitle:@"Oh No!" message:@"Survey is not in a closable state." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil] show];
        }
    }
}




#pragma mark - Private Methods - support for data model - gps points

- (GpsPoint *)createGpsPoint:(CLLocation *)gpsData
{
    if (!self.context) {
        AKRLog(@"Can't create GPS point, there is no data context (file)");
        return nil;
    }
    if (self.lastGpsPointSaved && [self.lastGpsPointSaved.timestamp timeIntervalSinceDate:gpsData.timestamp] == 0) {
        return self.lastGpsPointSaved;
    }
    AKRLog(@"Saving GpsPoint, Lat = %f, lon = %f, timestamp = %@", gpsData.coordinate.latitude, gpsData.coordinate.longitude, gpsData.timestamp);
    GpsPoint *gpsPoint = [NSEntityDescription insertNewObjectForEntityForName:kGpsPointEntityName
                                                       inManagedObjectContext:self.context];
    gpsPoint.mission = self.mission;
    gpsPoint.altitude = gpsData.altitude;
    gpsPoint.course = gpsData.course;
    gpsPoint.horizontalAccuracy = gpsData.horizontalAccuracy;
    gpsPoint.latitude = gpsData.coordinate.latitude;
    gpsPoint.longitude = gpsData.coordinate.longitude;
    gpsPoint.speed = gpsData.speed;
    gpsPoint.timestamp = gpsData.timestamp ? gpsData.timestamp : [NSDate date]; //FIXME: added for testing on simulator, remove for production
    gpsPoint.verticalAccuracy = gpsData.verticalAccuracy;
    self.lastGpsPointSaved = gpsPoint;
    return gpsPoint;
}

- (void)drawGpsPoint:(GpsPoint *)gpsPoint
{
    if (!gpsPoint)
        return;

    AGSPoint *point = [self mapPointFromGpsPoint:gpsPoint];
    [self drawGpsPointAtMapPoint:point];
}

- (void)drawGpsPointAtMapPoint:(AGSPoint *)mapPoint
{
    if (!mapPoint) {
        AKRLog(@"Cannot draw gpsPoint at mapPoint (%@)", mapPoint);
        return;
    }
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:nil];
    [self.graphicsLayers[kGpsPointEntityName] addGraphic:graphic];
    //TODO: Add segment to polyline
}




#pragma mark - Private Methods - support for data model - observations

- (Observation *)createObservation:(ProtocolFeature *)feature
{
    if (!self.context) {
        AKRLog(@"Can't create Observation, there is no data context (file)");
        return nil;
    }
    AKRLog(@"Creating Observation managed object");
    NSString *entityName = [NSString stringWithFormat:@"%@%@",kObservationPrefix,feature.name];
    Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                             inManagedObjectContext:self.context];
    observation.mission = self.mission;
    return observation;
}

- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint
{
    if (!gpsPoint) {
        AKRLog(@"Can't save Observation at GPS point without a GPS Point");
        return nil;
    }
    AKRLog(@"Creating Observation at GPS point");
    Observation *observation = [self createObservation:feature];
    observation.gpsPoint = gpsPoint;
    return observation;
}

- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint withAdhocLocation:(AGSPoint *)mapPoint
{
    if (!mapPoint) {
        AKRLog(@"Can't save Observation at Adhoc Location without a Map Point");
        return nil;
    }
    Observation *observation = [self createObservation:feature];
    if (!observation) {
        return nil;
    }
    AKRLog(@"Adding Adhoc Location to Observation");
    AdhocLocation *adhocLocation = [NSEntityDescription insertNewObjectForEntityForName:kAdhocLocationEntityName
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

- (Observation *)createObservation:(ProtocolFeature *)feature atGpsPoint:(GpsPoint *)gpsPoint withAngleDistanceLocation:(LocationAngleDistance *)location
{
    if (!gpsPoint) {
        AKRLog(@"Can't save Observation at Angle/Distance without a GPS Point");
        return nil;
    }
    Observation *observation = [self createObservation:feature atGpsPoint:gpsPoint];
    if (!observation) {
        return nil;
    }
    AKRLog(@"Adding Angle = %f, Distance = %f, Course = %f to observation",
          location.absoluteAngle, location.distanceMeters, location.deadAhead);

    AngleDistanceLocation *angleDistance = [NSEntityDescription insertNewObjectForEntityForName:kAngleDistanceLocationEntityName
                                                                         inManagedObjectContext:self.context];
    angleDistance.angle = location.absoluteAngle;
    angleDistance.distance = location.distanceMeters;
    angleDistance.direction = location.deadAhead;
    observation.angleDistanceLocation = angleDistance;
    return observation;
}

- (void)loadObservation:(Observation *)observation
{
    //AKRLog(@"    Loading observation");
    AGSPoint *point;
    if (observation.angleDistanceLocation) {
        LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:observation.angleDistanceLocation.direction
                                                                           protocolFeature:self.currentProtocolFeature
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
        AKRLog(@"Cannot draw observation (%@).  It has no location", observation);
        return;
    }
    NSDictionary *attribs;
    NSDate *timestamp = nil;
    if (observation.gpsPoint) {
        timestamp = observation.gpsPoint.timestamp;
    } else {
        timestamp = observation.adhocLocation.timestamp;
    }
    if (timestamp) {
        attribs = @{@"timestamp":timestamp};
    } else {
        attribs = @{@"timestamp":[NSNull null]};
    }
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attribs];
    //AKRLog(@"    Drawing observation type %@",observation.entity.name);
    NSString * name = [observation.entity.name stringByReplacingOccurrencesOfString:kObservationPrefix withString:@""];
    [self.graphicsLayers[name] addGraphic:graphic];
}




#pragma mark - Private Methods - support for data model - mission properties

- (MissionProperty *)createMissionProperty
{
    if (!self.context) {
        AKRLog(@"Can't create MissionProperty, there is no data context (file)");
        return nil;
    }
    AKRLog(@"Creating MissionProperty managed object");
    MissionProperty *missionProperty = [NSEntityDescription insertNewObjectForEntityForName:kMissionPropertyEntityName inManagedObjectContext:self.context];
    missionProperty.mission = self.mission;
    return missionProperty;
}

- (MissionProperty *)createMissionPropertyAtGpsPoint:(GpsPoint *)gpsPoint
{
    if (!gpsPoint) {
        AKRLog(@"Can't save MissionProperty at GPS point without a GPS Point");
        return nil;
    }
    AKRLog(@"Creating MissionProperty at GPS point");
    MissionProperty *missionProperty = [self createMissionProperty];
    missionProperty.gpsPoint = gpsPoint;
    return missionProperty;
}

- (void)loadMissionProperty:(MissionProperty *)missionProperty
{
    //AKRLog(@"    Loading missionProperty");
    AGSPoint *point;
    if (missionProperty.gpsPoint) {
        point = [self mapPointFromGpsPoint:missionProperty.gpsPoint];
    }
    [self drawMissionProperty:missionProperty atPoint:point];
}

- (void)drawMissionProperty:(MissionProperty *)missionProperty atPoint:(AGSPoint *)mapPoint
{
    if (!missionProperty || !mapPoint) {
        AKRLog(@"Cannot draw missionProperty (%@).  It has no location", missionProperty);
        return;
    }
    NSDictionary *attribs = @{@"timestamp":missionProperty.gpsPoint.timestamp};
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attribs];
    [self.graphicsLayers[kMissionPropertyEntityName] addGraphic:graphic];
}




#pragma mark - Private Methods - support for data model - mission properties

- (void)drawTrackObserving:(BOOL)observing From:(GpsPoint *)fromPoint to:(GpsPoint *)toPoint
{
    AGSPoint *point1 = [self mapPointFromGpsPoint:fromPoint];
    AGSPoint *point2 = [self mapPointFromGpsPoint:toPoint];
    AGSMutablePolyline *line = [[AGSMutablePolyline alloc] init];
    [line addPathToPolyline];
    [line addPointToPath:point1];
    [line addPointToPath:point2];
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:line symbol:nil attributes:nil];
    NSString *name = [NSString stringWithFormat:@"%@_%@", kMissionPropertyEntityName, (observing ? @"On" : @"Off")];
    [self.graphicsLayers[name] addGraphic:graphic];
}

- (void)setAttributesForFeatureType:(ProtocolFeature *)feature entity:(NSManagedObject *)entity defaults:(NSManagedObject *)template atPoint:mappoint
{
    //get data from entity attributes (unobscure the key names)
    NSMutableDictionary *data;
    if (template) {
        data = [[NSMutableDictionary alloc] init];
        for (NSAttributeDescription *attribute in feature.attributes) {
            NSString *cleanName = [attribute.name stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
            data[cleanName] = [template valueForKey:attribute.name];
        }
        //AKRLog(@"default data attributes %@", data);
    }
    NSDictionary *config = feature.dialogJSON;
    QRootElement *root = [[QRootElement alloc] initWithJSON:config andData:data];
    AttributeViewController *dialog = [[AttributeViewController alloc] initWithRoot:root];
    dialog.managedObject = entity;
    self.modalAttributeCollector = [[UINavigationController alloc] initWithRootViewController:dialog];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(saveAttributes:)];
    dialog.toolbarItems = @[doneButton];
    self.modalAttributeCollector.toolbarHidden = NO;
    self.modalAttributeCollector.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:self.modalAttributeCollector animated:YES completion:nil];
}

// Called by done button on attribute dialogs
- (void)saveAttributes:(UIBarButtonItem *)sender
{
    AKRLog(@"saving attributes");
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    AttributeViewController *dialog = [self.modalAttributeCollector.viewControllers firstObject];
    [dialog.root fetchValueUsingBindingsIntoObject:dict];
    NSManagedObject *obj = dialog.managedObject;
    for (NSString *aKey in dict){
        //This will throw an exception if the key is not valid. This will only happen with a bad protocol file - catch problem in testing, or protocol load
        NSString *obscuredKey = [NSString stringWithFormat:@"%@%@",kAttributePrefix,aKey];
        //AKRLog(@"Saving Attributes from Dialog key:%@ (%@) Value:%@", aKey, obscuredKey, [dict valueForKey:aKey]);
        [obj setValue:[dict valueForKey:aKey] forKey:obscuredKey];
    }
    [self.modalAttributeCollector dismissViewControllerAnimated:YES completion:nil];
    self.modalAttributeCollector = nil;
}






#pragma mark - Private Methods - misc support

- (NSManagedObject *)entityNamed:(NSString *)name atTimestamp:(NSDate *)timestamp
{
    if (!name || !timestamp) {
        return nil;
    }
    for (NSString *badName in @[kGpsPointsLayer,
                                [NSString stringWithFormat:@"%@_On", kMissionPropertyEntityName],
                                [NSString stringWithFormat:@"%@_Off", kMissionPropertyEntityName]]) {
        if ([name isEqualToString:badName]) {
            return nil;
        }
    }

    //Deal with ESRI graphic date bug
    NSDate *start = [timestamp dateByAddingTimeInterval:-0.01];
    NSDate *end = [timestamp dateByAddingTimeInterval:+0.01];
    NSString *obscuredName = [NSString stringWithFormat:@"%@%@",kObservationPrefix, name];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:obscuredName];
    request.predicate = [NSPredicate predicateWithFormat:@"(%@ <= gpsPoint.timestamp AND gpsPoint.timestamp <= %@) || (%@ <= adhocLocation.timestamp AND adhocLocation.timestamp <= %@)",start,end,start,end];
    NSArray *results = [self.context executeFetchRequest:request error:nil];
    return (NSManagedObject *)[results lastObject]; // will return nil if there was an error, or no results
}



#pragma mark - Diagnostic Aids - to be removed

//TODO: not used - use or remove

//ESRI BUG - date returned from graphic is not the same as the date that is provided
//    NSDate *t1 = (NSDate *)attribs[@"timestamp"];
//    NSDate *t2 = [graphic attributeAsDateForKey:@"timestamp"];
//    AKRLog(@"dict-graphic: DateIn: %@ (%f) dateOut: %@ (%f) equal:%u",t1,[t1 timeIntervalSince1970],t2, [t2 timeIntervalSince1970], [t1 isEqualToDate:t2]);


//FIXME: Rob some of the following code for deleting an individual observation
//- (void)clearData
//{
//    if (!self.context) {
//        return;
//    }
//
//    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kObservationEntityName];
//    NSError *error = [[NSError alloc] init];
//    NSArray *results = [self.context executeFetchRequest:request error:&error];
//    if (!results && error.code)
//        AKRLog(@"Error Fetching Observation %@",error);
//    for (Observation *observation in results) {
//        [self.context deleteObject:observation];
//    }
//    request = [NSFetchRequest fetchRequestWithEntityName:kGpsPointEntityName];
//    results = [self.context executeFetchRequest:request error:&error];
//    if (!results && error.code)
//        AKRLog(@"Error Fetching GpsPoints%@",error);
//    for (GpsPoint *gpsPoint in results) {
//        [self.context deleteObject:gpsPoint];
//    }
//    self.lastGpsPointSaved = nil;
//}


//TODO: this is the dictionary of atttributes attached to the AGSGraphic.  not used at this point
- (NSDictionary *)createAttributesFromObservation:(Observation *)observation
{
    NSDate *date = self.locationManager.location.timestamp;
    NSDictionary *attributes = @{ @"date":(date ? date : [NSNull null]) };
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
}

@end
