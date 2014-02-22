//
//  FeatureSelectorTableViewController.m
//  Observer
//
//  Created by Regan Sarwas on 2/21/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "FeatureSelectorTableViewController.h"
#import "NSIndexPath+unsignedAccessors.h"
#import "NSDate+Formatting.h"

@interface FeatureSelectorTableViewController ()

@property (strong, nonatomic) NSMutableArray *layerNames;
@property (strong, nonatomic) NSMutableArray *graphics;

@end

@implementation FeatureSelectorTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return (NSInteger)self.layerNames.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *graphics = (NSArray *)self.graphics[(NSUInteger)section];
    return (NSInteger)graphics.count;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.layerNames[(NSUInteger)section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSArray *graphics = (NSArray *)self.graphics[indexPath.usection];
    id<AGSFeature> graphic = (id<AGSFeature>)graphics[indexPath.urow];
    id item = [graphic safeAttributeForKey:@"timestamp"];
    NSDate *timestamp = nil;
    if ([item isKindOfClass:[NSDate class]]) {
        timestamp = (NSDate *)item;
    }
    if (timestamp) {
        //TODO: display a better timestamp
        //cell.textLabel.text = [timestamp stringWithRelativeTimeFormat];
        cell.textLabel.text = [NSString stringWithFormat:@"%@", timestamp];
    } else {
        cell.textLabel.text = @"Unknown timestamp";
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.featureSelectedCallback) {
        NSString *layerName = self.layerNames[indexPath.usection];
        NSArray *graphics = (NSArray *)self.graphics[indexPath.usection];
        id graphic = graphics[indexPath.urow];
        self.featureSelectedCallback(layerName, graphic);
    }
}

- (void)setFeatures:(NSDictionary *)features
{
    _features = features;
    self.layerNames = [NSMutableArray new];
    self.graphics = [NSMutableArray new];
    NSEnumerator *keyEnumerator = features.keyEnumerator;
    id key;
    while ((key = [keyEnumerator nextObject])) {
        [self.layerNames addObject:key];
        [self.graphics addObject:features[key]];
    }
}

@end
