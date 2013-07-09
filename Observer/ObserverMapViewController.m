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
	// Do any additional setup after loading the view.
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    //see http://robsprogramknowledge.blogspot.com/2012/05/back-segues.html

    BaseMap *currentMap = [self.maps currentMap];
    if (currentMap)
        self.mapLabel.text = currentMap.name;    
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
