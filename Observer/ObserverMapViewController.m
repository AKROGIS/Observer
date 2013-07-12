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

@interface ObserverMapViewController ()

@property (strong, nonatomic) BaseMapManager *maps;
@property (strong, nonatomic) AGSMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *mapLabel;

@end

@implementation ObserverMapViewController

- (BaseMapManager *)maps {
    if (!_maps) _maps = [BaseMapManager sharedManager];
    return _maps;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setOrResetBasemap:self.maps.currentMap];
}

//lazy instantiation
- (AGSMapView *)mapView
{
    if (!_mapView)
    {
        _mapView = [[AGSMapView alloc] initWithFrame:self.view.bounds];
        _mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self.view insertSubview:_mapView aboveSubview:self.mapLabel];
    }
    return _mapView;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    //see http://robsprogramknowledge.blogspot.com/2012/05/back-segues.html for handling 'reverse seques'
    
    [self setOrResetBasemap:self.maps.currentMap];
}

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
                for (AGSLayer *layer in layers)
                    [self.mapView addMapLayer:layer];
            }
        }
    }
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

@end
