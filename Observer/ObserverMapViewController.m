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

//FIXME - if basemap is in a geographic projection, then angle and distance calculations will not work, so disable angle/distance button

#import "ObserverMapViewController.h"
#import "LocalMapsTableViewController.h"
#import "AngleDistanceViewController.h"
#import "SurveyCollection.h"
#import "MapCollection.h"
#import "ProtocolCollection.h"

#define MINIMUM_NAVIGATION_SPEED 1.0  //speed in meters per second (1mps = 2.2mph) at which to switch map orientation from compass heading to course direction

typedef enum {
    LocationStyleOff,
    LocationStyleNormal,
    LocationStyleNaviagation,
    LocationStyleMagnetic
} LocationStyle;

@interface ObserverMapViewController ()

@property (strong, nonatomic) BaseMapManager *oldMapList;
@property (strong, nonatomic) SurveyProtocol *protocol;
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *mapLoadingIndicator;
@property (weak, nonatomic) IBOutlet UILabel *noMapLabel;

//@property (weak, nonatomic) IBOutlet UIBarButtonItem *gpsButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *panButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *panStyleButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *recordButton;
@property (weak, nonatomic) IBOutlet UIButton *northButton2;

@property (nonatomic) BOOL userWantsAutoPanOn;
@property (nonatomic) AGSLocationDisplayAutoPanMode savedAutoPanMode;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) AGSGraphicsLayer *observationsLayer;
@property (strong, nonatomic) AGSGraphicsLayer *gpsPointsLayer;
@property (strong, nonatomic) AGSGraphicsLayer *gpsTracksLayer;
@property (strong, nonatomic) UIPopoverController *angleDistancePopoverController;
@property (strong, nonatomic) UIPopoverController *mapsPopoverController;
@property (strong, nonatomic) GpsPoint *lastGpsPointSaved;
@property (strong, nonatomic) AGSSpatialReference *wgs84;
@property (nonatomic) int busyCount;

@property (strong, nonatomic) SurveyCollection* surveys;
@property (strong, nonatomic) MapCollection* maps;
@property (strong, nonatomic) UIPopoverController *quickDialogPopoverController;

@end

@implementation ObserverMapViewController


#pragma mark - Public Properties

- (void) setContext:(NSManagedObjectContext *)context
{
    NSLog(@"Context Set");
    _context = context;
    [self reloadGraphics];
}

- (void) setBusy:(BOOL)busy
{
    if (busy) {
        self.busyCount++;
    } else {
        self.busyCount--;
    }
    if (self.busyCount < 0)
        self.busyCount = 0;
    _busy = self.busyCount;
    if (_busy) {
        [self.mapLoadingIndicator startAnimating];
    } else {
        [self.mapLoadingIndicator stopAnimating];
    }
}

#pragma mark - Private Properties

//lazy instantiation
- (BaseMapManager *)oldMapList
{
    if (!_oldMapList) {
        _oldMapList = [BaseMapManager sharedManager];
    }
    return _oldMapList;
}

- (CLLocationManager *)locationManager
{
    if (!_locationManager)
        _locationManager = [[CLLocationManager alloc] init];
    return _locationManager;
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

@synthesize savedAutoPanMode = _savedAutoPanMode;

- (AGSLocationDisplayAutoPanMode) savedAutoPanMode
{
    if (!_savedAutoPanMode)
    {
        _savedAutoPanMode = [Settings manager].autoPanMode;
        if (_savedAutoPanMode < 1 || 3 < _savedAutoPanMode)
            _savedAutoPanMode = 1;
    }
    return _savedAutoPanMode;
}

- (void) setSavedAutoPanMode:(AGSLocationDisplayAutoPanMode)savedAutoPanMode
{
    if (savedAutoPanMode != _savedAutoPanMode)
    {
        _savedAutoPanMode = savedAutoPanMode;
        [Settings manager].autoPanMode = savedAutoPanMode;
        [self checkIfMapIsRotated];
    }
}

//FIXME - Used for testing, get from SurveyFile
- (SurveyProtocol *)protocol
{
    if (!_protocol) {
        _protocol = [[SurveyProtocol alloc] init];
        _protocol.distanceUnits = AGSSRUnitMeter;
        _protocol.angleBaseline = 180;
        _protocol.angleDirection = AngleDirectionClockwise;
        _protocol.definesAngleDistanceMeasures = YES;
        _protocol.delegate = self;
        //_protocol = nil;
    }
    return _protocol;
}

- (AGSSpatialReference *) wgs84
{
    if (!_wgs84) {
        _wgs84 = [AGSSpatialReference wgs84SpatialReference];
    }
    return _wgs84;
}


#pragma mark - IBActions

- (IBAction)tap:(UITapGestureRecognizer *)sender {
    NSLog(@"User Tap");
}

- (IBAction)togglePanMode:(UIBarButtonItem *)sender {
    self.userWantsAutoPanOn = !self.userWantsAutoPanOn;
}

- (void) setUserWantsAutoPanOn:(BOOL)userWantsAutoPanOn
{
    if (userWantsAutoPanOn)
    {
        self.mapView.locationDisplay.autoPanMode = self.savedAutoPanMode;
        self.panButton.style = UIBarButtonItemStyleDone;
        self.panStyleButton.enabled = YES;
    }
    else
    {
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
        self.panButton.style = UIBarButtonItemStyleBordered;        
        self.panStyleButton.enabled = NO;
    }
    [self checkIfMapIsRotated];
    _userWantsAutoPanOn = userWantsAutoPanOn;

    [Settings manager].autoPanEnabled = userWantsAutoPanOn;
}

- (IBAction)toggleRecordMode:(UIBarButtonItem *)sender {
    if (sender.style == UIBarButtonItemStyleDone) {
        NSLog(@"stop recording");
        sender.style = UIBarButtonItemStyleBordered;
        [self stopMission];
    }
    else{
        NSLog(@"start recording");
        sender.style = UIBarButtonItemStyleDone;
        [self startMission];
    }
}

- (IBAction)resetNorth:(UIButton *)sender {
    NSLog(@"Reset North");
    [self.mapView setRotationAngle:0 animated:YES];
    CATransition *animation = [CATransition animation];
    animation.type = kCATransitionFade;
    animation.duration = 0.4;
    [sender.layer addAnimation:animation forKey:nil];
    sender.hidden = YES;
}

- (IBAction)togglePanStyle:(UIBarButtonItem *)sender {
    // if not autopan off, then loop through 1,2,3
    if (self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeOff)
        return;
    self.mapView.locationDisplay.autoPanMode = 1 + (self.mapView.locationDisplay.autoPanMode%3);
    self.savedAutoPanMode = self.mapView.locationDisplay.autoPanMode;
    self.panStyleButton.title = [NSString stringWithFormat:@"Mode%u",self.savedAutoPanMode];    
}

- (IBAction)addMissionProperty:(UIBarButtonItem *)sender {
    NSLog(@"Add Mission Property");
    //FIXME
    //if gps, then add at GPS else add adhoc at current location
    //launch pop up to enter attributes, use existing as defaults
}

- (IBAction)addAdhocObservation:(UIBarButtonItem *)sender
{
    GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
    //ignore the gpsPoint if it is over a second old
    if ([gpsPoint.timestamp timeIntervalSinceNow] < -2.0)
        gpsPoint = nil;
    Observation *observation = [self createObservationAtGpsPoint:gpsPoint withAdhocLocation:self.mapView.mapAnchor];
    [self drawObservation:observation atPoint:self.mapView.mapAnchor];
    //FIXME - seque to popover to populate observation.attributes
}

- (IBAction)addGpsObservation:(UIBarButtonItem *)sender
{
    GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
    Observation *observation = [self createObservationAtGpsPoint:gpsPoint];
    AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
    [self drawObservation:observation atPoint:mapPoint];
    //FIXME - seque to popover to populate observation.attributes
}

- (IBAction)clearData:(UIBarButtonItem *)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Delete Data" message:@"This will delete all observations and tracklogs, and cannot be undone." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
    [alert show];
}

#pragma mark - Public Methods: Initializers

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"currentMap"];
}


#pragma mark - Public Methods: Super class methods

- (void)viewDidLoad
{
    NSLog(@"View Did Load");
    [super viewDidLoad];
    self.noMapLabel.hidden = YES;
    self.busy = YES;
    self.mapView.layerDelegate = self;
    self.mapView.touchDelegate = self;
    self.mapView.calloutDelegate = self;
    self.mapView.allowRotationByPinching = YES;
    dispatch_queue_t loadQueue = dispatch_queue_create("loadLocalMaps", NULL);
    dispatch_async(loadQueue, ^{
        [self.oldMapList loadLocalMaps];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadBaseMap];
        });
    });
}

- (void) viewDidAppear:(BOOL)animated {
    NSLog(@"View Did Appear");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mapDidPan:) name:AGSMapViewDidEndPanningNotification object:self.mapView];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mapDidZoom:) name:AGSMapViewDidEndZoomingNotification object:self.mapView];
    [super viewDidAppear:animated];
}

- (void) viewDidDisappear:(BOOL)animated
{
    NSLog(@"View Did Disappear");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AGSMapViewDidEndPanningNotification object:self.mapView];
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    NSLog(@"Observer Map ViewController did recieve memory warning");
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL) shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"Push Local Map Table"])
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

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"Push Local Map Table"])
    {
        UINavigationController *nav1 = [segue destinationViewController];
        LocalMapsTableViewController *dvc = (LocalMapsTableViewController *)nav1.viewControllers[0];
        dvc.maps = self.oldMapList;
        UIStoryboardPopoverSegue *pop = (UIStoryboardPopoverSegue*)segue;
        self.mapsPopoverController = pop.popoverController;
        self.mapsPopoverController.delegate = self;
        //FIXME - need to clear self.mapsPopoverController when popover is dismissed programatically.
        dvc.popover = pop.popoverController;
    }
    if ([[segue identifier] isEqualToString:@"AngleDistancePopOver"])
    {
        UINavigationController *nav = [segue destinationViewController];
        AngleDistanceViewController *vc = (AngleDistanceViewController *)nav.viewControllers[0];

        //create/save current GpsPoint, because it may take a while for the user to enter an angle/distance
        GpsPoint *gpsPoint = [self createGpsPoint:self.locationManager.location];
        AGSPoint *mapPoint = [self mapPointFromGpsPoint:gpsPoint];
        double currentCourse = gpsPoint.course;
        
        LocationAngleDistance *location;
        if (0 <= currentCourse) {
            location = [[LocationAngleDistance alloc] initWithDeadAhead:currentCourse protocol:self.protocol];
        }
        else {
            double currentHeading = self.locationManager.heading.trueHeading;
            if (0 <= currentHeading) {
                location = [[LocationAngleDistance alloc] initWithDeadAhead:currentHeading protocol:self.protocol];
            }
            else {
                location = [[LocationAngleDistance alloc] initWithDeadAhead:0.0 protocol:self.protocol];
            }
        }
        vc.location = location;
        
        UIStoryboardPopoverSegue *pop = (UIStoryboardPopoverSegue*)segue;
        self.angleDistancePopoverController = pop.popoverController;
        self.angleDistancePopoverController.delegate = self;
        vc.popover = pop.popoverController;
        vc.completionBlock = ^(AngleDistanceViewController *sender) {
            self.angleDistancePopoverController = nil;
            Observation *observation = [self createObservationAtGpsPoint:gpsPoint withAngleDistanceLocation:sender.location];
            [self drawObservation:observation atPoint:[sender.location pointFromPoint:mapPoint]];
            //FIXME - seque to popover to populate observation.attributes
        };
        vc.cancellationBlock = ^(AngleDistanceViewController *sender) {
            self.angleDistancePopoverController = nil;
        };
    }
}


#pragma mark - Public Methods: Call backs for KVO and notifications

- (void) mapDidPan:(NSNotification *)notification
{
    //user panning will turn off the autopan mode, so I need to update the toolbar button.
    if (self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeOff)
        self.userWantsAutoPanOn = NO;
}

//FIXME - KVO callbacks will happen on whichever thread made the change!
//Use receptionist pattern: http://developer.apple.com/library/ios/#documentation/general/conceptual/CocoaEncyclopedia/ReceptionistPattern/ReceptionistPattern.html
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (self.oldMapList == object && [keyPath isEqualToString:@"currentMap"])
    {
        NSLog(@"self.oldMapList.currentMap has changed; old: %@, new: %@", change[NSKeyValueChangeOldKey], change[NSKeyValueChangeNewKey]);
        if (change[NSKeyValueChangeOldKey] != change[NSKeyValueChangeNewKey])
            [self resetBasemap];
    }
}


#pragma mark - Delegate Methods: UIPopoverControllerDelegate

//This is not called if the popover is programatically dismissed.
- (void) popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
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

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Delete Data"] && buttonIndex == 1) {
        self.busy = YES;
        //FIXME - Clear data on a background thread if it takes some time.
        [self clearData];
        [self clearGraphics];
        self.busy = NO;
    }
}

#pragma mark - Delegate Methods: AGSLayerDelegate (all optional)

-(void) layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error
{
    // Tells the delegate that the layer failed to load with the specified error.
    NSLog(@"layer %@ failed to load with error %@", layer, error);
    self.busy = NO;
    self.noMapLabel.hidden = NO;
}

- (void) layerDidLoad:(AGSLayer *)layer
{
    // Tells the delegate that the layer is loaded and ready to use.
    NSLog(@"layer %@ did load", layer);
    //real work will be done in mapView's delegate
}

- (void) layer:(AGSLayer *)layer didInitializeSpatialReferenceStatus:(BOOL)srStatusValid
{
    NSLog(@"layer %@ did%@ initialize Spatial Reference", layer, srStatusValid ? @"" : @" not");
}


#pragma mark - Delegate Methods: AGSMapViewLayerDelegate (all optional)

-(void) mapViewDidLoad:(AGSMapView*)mapView
{
    //Tells the delegate the map is loaded and ready for use. Fires when the map’s base layer loads.
    NSLog(@"mapViewDidLoad");
    self.noMapLabel.hidden = YES;
    [self initializeGraphicsLayer];
    [self reloadGraphics];
    [self turnOnGPS];
    self.busy = NO;
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
 
- (void)mapView:(AGSMapView *)mapView didClickAtPoint:(CGPoint)screen mapPoint:(AGSPoint *)mappoint graphics:(NSDictionary *)graphics
{
    //Tells the delegate the map was single-tapped at specified location.
    //The dictionary contains NSArrays of intersecting AGSGraphics keyed on the layer name
    NSLog(@"mapView:didClickAtPoint:(%f,%f)=(%@) with graphics:%@", screen.x, screen.y, mappoint, graphics);
    if ([graphics count]) {
        NSLog(@"display graphic callout");
    }
    else
    {
        Observation *observation = [self createObservationAtGpsPoint:self.lastGpsPointSaved withAdhocLocation:mappoint];
        [self drawObservation:observation atPoint:mappoint];
        //FIXME - seque to popover to populate observation.attributes
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


#pragma mark - Delegate Methods: AGSMapViewCalloutDelegate (all optional)

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


#pragma mark - CLLocationManagerDelegate Protocol

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [self rotateNorthArrow];

    //monitor the velocity to auto switch between AGSLocation Auto Pan Mode between navigation and heading
    CLLocation *location = [locations lastObject];
#pragma warn - simulator returns -1 for speed, so ignore it for testing.  remove from production code.
    //if (!location || location.speed < 0)
    if (!location)
        return;
    
    if (![self isNewLocation:location])
        return;
    
    GpsPoint *gpsPoint = [self createGpsPoint:location];
    //[self drawGpsPoint:gpsPoint atMapPoint:self.mapView.locationDisplay.mapLocation];
    //requires a reprojection of the point, but i'm not sure mapLocation and CLlocation will be in sync.
    [self drawGpsPoint:gpsPoint];
    
    //NSLog(@"Got a new location %@",location);
    
    if (location.speed < MINIMUM_NAVIGATION_SPEED &&
        self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeNavigation)
    {
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
        self.savedAutoPanMode = self.mapView.locationDisplay.autoPanMode;
    }
    if (MINIMUM_NAVIGATION_SPEED <= location.speed &&
        self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeCompassNavigation)
    {
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeNavigation;
        self.savedAutoPanMode = self.mapView.locationDisplay.autoPanMode;
    }

}

- (void) locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    //This is choppy, because it isn't synchronized with the map rotation.  Unfortunately, subclassing AGSMapView
    //didn't help, because it does the rotation in the c++ backend, not through the UIView or AGSMapView interface
    //Maybe I should try turning off the AutoRotate mode of the mapView LocationDisplay and do the
    //rotations myself.
    [self rotateNorthArrow];
}

#pragma mark - Private Methods

- (void) toggleGps:(UIBarButtonItem *)sender {
    if (sender.style == UIBarButtonItemStyleDone)
        [self turnOffGPS];
    else
        [self turnOnGPS];
}

- (void) turnOnGPS
{
    self.mapView.locationDisplay.navigationPointHeightFactor = 0.5;
    self.mapView.locationDisplay.wanderExtentFactor = 0.0;
    [self.mapView.locationDisplay startDataSource];
    //self.gpsButton.style = UIBarButtonItemStyleDone;
    self.panButton.enabled = YES;
    self.recordButton.enabled = YES;
    
    self.userWantsAutoPanOn = [Settings manager].autoPanEnabled;
    
    self.panStyleButton.title = [NSString stringWithFormat:@"Mode%u",self.savedAutoPanMode];
    
    //AGSLocationDisplay does not have a delegate or provide notifications,  If we want location events we need our own CLLocationManager
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized)
    {
        self.locationManager.delegate = self;
        [self.locationManager startUpdatingLocation];
    }
}

- (void) turnOffGPS
{
    [self.mapView.locationDisplay stopDataSource];
    //self.gpsButton.style = UIBarButtonItemStyleBordered;
    self.panButton.enabled = NO;
    self.panStyleButton.enabled = NO;
    self.recordButton.enabled = NO;
}

- (void) checkIfMapIsRotated
{
    //FIXME - there is too much delay before the compass appears 
    if (self.mapView.rotationAngle != 0)
    {
        if (self.northButton2.hidden)
        {
            //CATransition *animation = [CATransition animation];
            //animation.type = kCATransitionFade;
            //animation.duration = 0.4;
            //[self.northButton2.layer addAnimation:animation forKey:nil];
            self.northButton2.hidden = NO;
        }
    }
    //FIXME - what was I trying to do here?
    if (self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeNavigation ||
        self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeCompassNavigation)
    {
        //self.northButton2.enabled = NO;
    }
}

- (void) rotateNorthArrow
{
    double degrees = -1*self.mapView.rotationAngle;
    NSLog(@"Rotating compass icon to %f degrees", degrees);
    double radians = degrees * M_PI / 180.0;
    //angle in radians with positive being counterclockwise (on iOS)
    self.northButton2.transform = CGAffineTransformMakeRotation(radians);
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.mapView.locationDisplay.interfaceOrientation = toInterfaceOrientation;
}

- (void) loadBaseMap
{
    if (!self.oldMapList.currentMap.tileCache)
    {
        self.noMapLabel.hidden = NO;
        self.busy = NO;
    }
    else
    {
        //adding a layer is async. wait for AGSLayerDelegate layerDidLoad or layerDidFailToLoad
        self.oldMapList.currentMap.tileCache.delegate = self;
        [self.mapView addMapLayer:self.oldMapList.currentMap.tileCache withName:@"tilecache basemap"];
    }
    [self.oldMapList addObserver:self forKeyPath:@"currentMap" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:nil];
}

- (void) resetBasemap
{
    //This is only called when the self.maps.currentMap has changed (usually by a user selection in a different view controller)
    //It is not called when the self.maps.currentMap is initialized.
    
    //A "loaded" mapview has an immutable SR and maxExtents based on the first layer loaded (not on the first layer in the mapView)
    //removing all layers from the mapview does not "unload" the mapview.
    //to reset the mapView extents/SR, we need to call reset, then re-add the layers.
    //first we need to get the layers, so we can re-add them after setting the new basemap
    NSLog(@"Reseting the basemap");
    if (!self.oldMapList.currentMap.tileCache)
    {
        self.noMapLabel.hidden = NO;
        self.busy = NO;
    }
    else
    {
        self.noMapLabel.hidden = YES;
        self.busy = YES;
        [self.mapView reset]; //remove all layers
        //adding a layer is async. wait for AGSLayerDelegate layerDidLoad or layerDidFailToLoad
        self.oldMapList.currentMap.tileCache.delegate = self;
        [self.mapView addMapLayer:self.oldMapList.currentMap.tileCache withName:@"tilecache basemap"];
    }
}

- (void) reloadGraphics
{
    if (!self.context || !self.mapView.loaded) {
        NSLog(@"Can't load Graphics now context and/or map is not available.");
        return;
    }
    [self clearGraphics];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"GpsPoint"];
    NSError *error = [[NSError alloc] init];
    NSArray *results = [self.context executeFetchRequest:request error:&error];
    if (!results && error.code)
        NSLog(@"Error Fetching GpsPoint %@",error);
    for (GpsPoint *gpsPoint in results) {
        [self drawGpsPoint:gpsPoint];
        if (gpsPoint.observation) {
            [self loadObservation:gpsPoint.observation];
        }
    }
    //Get adhoc observations (gpsPoint is null and adhocLocation is non nil
    request = [NSFetchRequest fetchRequestWithEntityName:@"Observation"];
    request.predicate = [NSPredicate predicateWithFormat:@"gpsPoint == NIL AND adhocLocation != NIL"];
    results = [self.context executeFetchRequest:request error:&error];
    if (!results && error.code)
        NSLog(@"Error Fetching Observations %@",error);
    for (Observation *observation in results) {
        [self loadObservation:observation];
    }    
}

- (void) initializeGraphicsLayer
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
}

- (void) loadObservation:(Observation *)observation
{
    AGSPoint *point;
    if (observation.angleDistanceLocation) {
        LocationAngleDistance *location = [[LocationAngleDistance alloc] initWithDeadAhead:observation.angleDistanceLocation.direction
                                                                                  protocol:self.protocol
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


- (void) drawObservation:(Observation *)observation atPoint:(AGSPoint *)mapPoint
{
    if (!observation || !mapPoint) {
        NSLog(@"Cannot draw observation (%@).  It has no location", observation);
        return;
    }
    NSDictionary *attributes = observation.attributeSet ? [self createAttributesFromObservation:observation] : nil;
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attributes infoTemplateDelegate:nil];
    [self.observationsLayer addGraphic:graphic];
}

- (NSDictionary *) createAttributesFromObservation:(Observation *)observation
{
    //FIXME - need to define the attributes
    NSDictionary *attributes = @{@"date":self.locationManager.location.timestamp?:[NSNull null]};
    return attributes;
}

- (void) drawGpsPoint:(GpsPoint *)gpsPoint
{
    if (!gpsPoint)
        return;

    AGSPoint *point = [self mapPointFromGpsPoint:gpsPoint];
    [self drawGpsPoint:gpsPoint atMapPoint:point];
}

- (void) drawGpsPoint:(GpsPoint *)gpsPoint atMapPoint:(AGSPoint *)mapPoint
{
    if (!gpsPoint || !mapPoint) {
        NSLog(@"Cannot draw gpsPoint (%@) @ mapPoint (%@)",gpsPoint, mapPoint);
        return;
    }
    //FIXME - figure out which attributes to show with GPS points
    NSDictionary *attributes = @{@"date":gpsPoint.timestamp?:[NSNull null]};
    AGSGraphic *graphic = [[AGSGraphic alloc] initWithGeometry:mapPoint symbol:nil attributes:attributes infoTemplateDelegate:nil];
    [self.gpsPointsLayer addGraphic:graphic];
    
    //FIXME draw a tracklog polyline
}

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
    gpsPoint.altitude = gpsData.altitude;
    gpsPoint.course = gpsData.course;
    gpsPoint.horizontalAccuracy = gpsData.horizontalAccuracy;
    gpsPoint.latitude = gpsData.coordinate.latitude;
    gpsPoint.longitude = gpsData.coordinate.longitude;
    gpsPoint.speed = gpsData.speed;
    gpsPoint.timestamp = gpsData.timestamp;
    gpsPoint.verticalAccuracy = gpsData.verticalAccuracy;
    self.lastGpsPointSaved = gpsPoint;
    return gpsPoint;
}

- (Observation *)createObservation
{
    if (!self.context) {
        NSLog(@"Can't create Observation, there is no data context (file)");
        return nil;
    }
    NSLog(@"Saving Observation");
    Observation *observation = [NSEntityDescription insertNewObjectForEntityForName:@"Observation"
                                                              inManagedObjectContext:self.context];
    //We don't have any attributes yet, that will get created/added later depending on the protocol
    return observation;
}

- (Observation *)createObservationAtGpsPoint:(GpsPoint *)gpsPoint
{
    if (!gpsPoint) {
        NSLog(@"Can't save Observation at GPS point without a GPS Point");
        return nil;
    }
    NSLog(@"Saving Observation at GPS point");
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

- (GpsPoint *)gpsPointAtTimestamp:(NSDate *)timestamp
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"GpsPoint"];
    request.predicate = [NSPredicate predicateWithFormat:@"timestamp = %@",timestamp];
    NSArray *results = [self.context executeFetchRequest:request error:nil];
    return (GpsPoint *)[results lastObject]; // will return null if there was an error, or no results
}

- (BOOL) isNewLocation:(CLLocation *)location
{
    if (!self.lastGpsPointSaved)
        return YES;
    //0.0001 deg in latitude is about 18cm (<1foot) assuming a mean radius of 6371m, and less in longitude away from the equator. 
    if (fabs(location.coordinate.latitude - self.lastGpsPointSaved.latitude) > 0.0001)
        return YES;
    if (fabs(location.coordinate.latitude - self.lastGpsPointSaved.latitude) > 0.0001)
        return YES;
    //FIXME is 10 seconds a good default?  do I want a user setting? this gets called a lot, so I don't want to slow down with a lookup
    if ([location.timestamp timeIntervalSinceDate:self.lastGpsPointSaved.timestamp] > 10.0)
        return YES;
    return NO;
}

- (AGSPoint *) mapPointFromGpsPoint:(GpsPoint *)gpsPoint
{
    AGSPoint *point = [AGSPoint pointWithX:gpsPoint.longitude y:gpsPoint.latitude spatialReference:self.wgs84];
    point = (AGSPoint *)[[AGSGeometryEngine defaultGeometryEngine] projectGeometry:point toSpatialReference:self.mapView.spatialReference];
    return point;
}

- (void) clearGraphics
{
    [self.observationsLayer removeAllGraphics];
    [self.gpsPointsLayer removeAllGraphics];    
}

- (void) clearData
{
    if (!self.context) {
        return;
    }
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Observation"];
    NSError *error = [[NSError alloc] init];
    NSArray *results = [self.context executeFetchRequest:request error:&error];
    if (!results && error.code)
        NSLog(@"Error Fetching Observation %@",error);
    for (Observation *observation in results) {
        [self.context deleteObject:observation];
    }
    request = [NSFetchRequest fetchRequestWithEntityName:@"GpsPoint"];
    results = [self.context executeFetchRequest:request error:&error];
    if (!results && error.code)
        NSLog(@"Error Fetching GpsPoints%@",error);
    for (GpsPoint *gpsPoint in results) {
        [self.context deleteObject:gpsPoint];        
    }
    self.lastGpsPointSaved = nil;
}

- (void) startMission
{
    
}

- (void) stopMission
{
    
}

- (void) openModel
{
    [self.protocol openModel];
}

- (void) saveModel
{
    [self.protocol saveModel];
}

- (void) closeModel
{
    [self.protocol closeModel];
}


- (BOOL) openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
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

#pragma mark - Support for Testing Quick Dialog

- (IBAction)changeEnvironment:(UIBarButtonItem *)sender
{
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

- (IBAction)collectObservation:(UIBarButtonItem *)sender
{
    if (self.quickDialogPopoverController) {
        return;
    }
    //create VC from QDialog json in protocol, add newController to popover, display popover
    //TODO: support more than just one feature called Observations
    NSDictionary *dialog = self.surveys.selectedSurvey.protocol.dialogs[@"Observation"];
    QRootElement *root = [[QRootElement alloc] initWithJSON:dialog andData:nil];
    QuickDialogController *viewController = [QuickDialogController controllerForRoot:root];

    //MapDetailViewController *vc = [[MapDetailViewController alloc] init];
    //vc.map = self.maps.selectedLocalMap;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    self.quickDialogPopoverController = [[UIPopoverController alloc] initWithContentViewController:navigationController];
    self.quickDialogPopoverController.delegate = self;
    //self.popover.popoverContentSize = CGSizeMake(644, 425);
    [self.quickDialogPopoverController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

// not called when popover is dismissed programatically - use callbacks instead
-(void)dismissQuickDialogPopover:(UIPopoverController *)popoverController
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


@end
