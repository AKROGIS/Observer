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
@property (weak, nonatomic) IBOutlet UIBarButtonItem *locationButton;

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

- (AGSMapView *)mapView
{
    if (!_mapView)
    {
        _mapView = [[AGSMapView alloc] initWithFrame:self.view.bounds];
        _mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        _mapView.layerDelegate = self;
        //_mapView.touchDelegate = self;
        //_mapView.calloutDelegate = self;
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

- (IBAction)toggleLocationServices:(UIBarButtonItem *)sender
{
    if ([sender.title isEqualToString:@"off"])
    {
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeDefault;
        
        self.locationButton.title = @"1";
    }
    else if ([sender.title isEqualToString:@"1"])
    {
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeNavigation;
        self.locationButton.title = @"2";
    }
    else if ([sender.title isEqualToString:@"2"])
    {
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeCompassNavigation;
        self.locationButton.title = @"3";
    }
    else
    {
        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
        self.locationButton.title = @"off";
    }
}

- (void) mapDidPan:(NSNotification *)notification
{
    //done automatically
    //self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanModeOff;
    //FIXME need to distiguish between a user touch and a system pan (due to changing autopan mode
    //self.locationButton.title = @"off";
}

#pragma mark - Delegate Methods: AGSMap

-(void) mapViewDidLoad:(AGSMapView*)mapView
{
 	[self.mapView.locationDisplay startDataSource];
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
