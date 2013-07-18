//
//  ObserverMapViewController.m
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "ObserverMapViewController.h"
#import "LocalMapsTableViewController.h"
#import "BaseMapManager.h"

#define DEFAULTS_KEY_WANTS_AUTOPAN @"wants_autopan"
#define DEFAULTS_KEY_AUTOPAN_MODE @"autopan_mode"


typedef enum {
    LocationStyleOff,
    LocationStyleNormal,
    LocationStyleNaviagation,
    LocationStyleMagnetic
} LocationStyle;

@interface ObserverMapViewController ()

@property (strong, nonatomic) BaseMapManager *maps;
@property (strong, nonatomic) AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *mapLabel;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *gpsButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *panButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *recordButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *northButton;
@property (nonatomic) BOOL userWantsAutoPanOn;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *panStyleButton;
@property (nonatomic) AGSLocationDisplayAutoPanMode savedAutoPanMode;

@end

@implementation ObserverMapViewController


#pragma mark - Public Properties


#pragma mark - Private Properties

//lazy instantiation

- (BaseMapManager *)maps
{
    if (!_maps)
        _maps = [BaseMapManager sharedManager];
    return _maps;
}

- (IBAction)toggleGps:(UIBarButtonItem *)sender {
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
    self.gpsButton.style = UIBarButtonItemStyleDone;
    self.panButton.enabled = YES;
    self.northButton.enabled = NO;
    self.recordButton.enabled = YES;
    
    self.userWantsAutoPanOn = [[NSUserDefaults standardUserDefaults] boolForKey:DEFAULTS_KEY_WANTS_AUTOPAN];
    
    self.panStyleButton.title = [NSString stringWithFormat:@"Mode%u",self.savedAutoPanMode];
}

- (void) turnOffGPS
{
    [self.mapView.locationDisplay stopDataSource];
    self.gpsButton.style = UIBarButtonItemStyleBordered;
    self.panButton.enabled = NO;
    self.panStyleButton.enabled = NO;
    self.recordButton.enabled = NO;
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

    [[NSUserDefaults standardUserDefaults] setBool:userWantsAutoPanOn forKey:DEFAULTS_KEY_WANTS_AUTOPAN];
}

- (IBAction)toggleRecordMode:(UIBarButtonItem *)sender {
    if (sender.style == UIBarButtonItemStyleDone) {
        NSLog(@"stop recording");
        sender.style = UIBarButtonItemStyleBordered;
    }
    else{
        NSLog(@"start recording");
        sender.style = UIBarButtonItemStyleDone;
    }
}

- (IBAction)setNorthUp:(UIBarButtonItem *)sender {
    [self.mapView setRotationAngle:0 animated:YES];
    sender.enabled = NO;
}

- (IBAction)togglePanStyle:(UIBarButtonItem *)sender {
    // if not autopan off, then loop through 1,2,3
    if (self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeOff)
        return;
    self.mapView.locationDisplay.autoPanMode = 1 + (self.mapView.locationDisplay.autoPanMode%3);
    self.savedAutoPanMode = self.mapView.locationDisplay.autoPanMode;
    self.panStyleButton.title = [NSString stringWithFormat:@"Mode%u",self.savedAutoPanMode];    
}

@synthesize savedAutoPanMode = _savedAutoPanMode;

- (AGSLocationDisplayAutoPanMode) savedAutoPanMode
{
    if (!_savedAutoPanMode)
    {
        _savedAutoPanMode = [[NSUserDefaults standardUserDefaults] integerForKey:DEFAULTS_KEY_AUTOPAN_MODE];
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
        [[NSUserDefaults standardUserDefaults] setInteger:savedAutoPanMode forKey:DEFAULTS_KEY_AUTOPAN_MODE];
        [self checkIfMapIsRotated];
    }
}

- (void) checkIfMapIsRotated
{
    if (self.mapView.rotationAngle != 0)
        self.northButton.enabled = YES;

    if (self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeNavigation ||
        self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeCompassNavigation)
    {
        self.northButton.enabled = NO;
    }
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.mapView.locationDisplay.interfaceOrientation = toInterfaceOrientation;
}

- (AGSMapView *)mapView
{
    if (!_mapView)
    {
        _mapView = [[AGSMapView alloc] initWithFrame:self.view.bounds];
        _mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        _mapView.layerDelegate = self;
        _mapView.touchDelegate = self;
        _mapView.calloutDelegate = self;
        [self.view insertSubview:_mapView aboveSubview:self.mapLabel];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mapDidPan:) name:AGSMapViewDidEndPanningNotification object:_mapView];
    }
    return _mapView;
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


#pragma mark - Public Methods: Super class methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setOrResetBasemap:self.maps.currentMap];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //see http://robsprogramknowledge.blogspot.com/2012/05/back-segues.html for handling 'reverse seques'
    
    [self setOrResetBasemap:self.maps.currentMap];
}

- (void) viewDidDisappear:(BOOL)animated
{
    //don't check self.mapview, because that will create a new mapview
    if (_mapView)
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AGSMapViewDidEndPanningNotification object:self.mapView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"Push Local Map Table"])
    {
        LocalMapsTableViewController *dvc = [segue destinationViewController];
        dvc.maps = self.maps;
    }
}


#pragma mark - Public Methods: Mine

- (void) mapDidPan:(NSNotification *)notification
{
    //panning may turn off the autopan mode, so I need to update the toolbar button.
    if (self.mapView.locationDisplay.autoPanMode == AGSLocationDisplayAutoPanModeOff)
        self.userWantsAutoPanOn = NO;

    //done automatically
    //self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
    //FIXME need to distiguish between a user touch and a system pan (due to changing autopan mode
    //self.locationButton.title = @"off";
}


#pragma mark - Delegate Methods: AGSMapViewLayerDelegate (all optional)

-(void) mapViewDidLoad:(AGSMapView*)mapView
{
    //Tells the delegate the map is loaded and ready for use. Fires when the map’s base layer loads.    
    NSLog(@"mapViewDidLoad");
    [self turnOnGPS];
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
}

- (void)mapView:(AGSMapView *)mapView :(CGPoint)screen mapPoint:(AGSPoint *)mappoint graphics:(NSDictionary *)graphics
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



#pragma mark - Private Methods

- (void) setOrResetBasemap:(BaseMap *)baseMap
{
    //A "loaded" mapview has an immutable SR and maxExtents based on the first layer loaded (not on the first layer in the mapView)
    //removing all layers from the mapview does not "unload" the mapview.
    //to reset the mapView extents/SR, we need to create a new mapview.
    //first we need to get the layers, so we can re-add them after setting the new basemap.
    if (!baseMap.tileCache)
    {
        self.mapLabel.text = @"No background map selected. Click the Maps button to select one.";
    }
    else
    {
        if (!self.mapView.loaded)
        {
            [self.mapView addMapLayer:baseMap.tileCache];
        }
        else
        {
            if ([self.mapView.mapLayers count] == 0 || baseMap.tileCache != self.mapView.mapLayers[0])
            {
                NSMutableArray *layers = [NSMutableArray arrayWithArray: self.mapView.mapLayers];
                layers[0] = baseMap.tileCache;
                [self.mapView removeFromSuperview];
                self.mapView = nil;
                //FIXME - remove self from notification observer (do it in the setter)
                for (AGSLayer *layer in layers)
                    [self.mapView addMapLayer:layer];
            }
        }
    }
}


@end
