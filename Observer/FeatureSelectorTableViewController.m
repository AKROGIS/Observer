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
#import "CommonDefines.h"

#define kPopoverMaxHeight 500
#define kPopoverWidth     320

@interface FeatureSelectorTableViewController ()

@property (strong, nonatomic) NSMutableArray *layerNames;
@property (strong, nonatomic) NSMutableArray *graphics;

@end

@implementation FeatureSelectorTableViewController

#pragma mark - properties

- (void)setFeatures:(NSDictionary *)features
{
    _features = features;
    self.layerNames = [NSMutableArray new];
    self.graphics = [NSMutableArray new];
    NSEnumerator *keyEnumerator = features.keyEnumerator;
    id key;
    while ((key = [keyEnumerator nextObject])) {
        [self.layerNames addObject:key];
        id feature = features[key];
        if (feature != nil) {
            [self.graphics addObject:feature];
        }
    }
    self.preferredContentSize = CGSizeMake(kPopoverWidth, [self heightForTableContents]);
}




#pragma mark - UITableView DataSource

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
    id<AGSGeoElement> graphic = (id<AGSGeoElement>)graphics[indexPath.urow];
    NSString *layerName = self.layerNames[indexPath.usection];
    ProtocolFeature *feature = [self.protocol featureWithName:layerName];
    if (feature.labelSpec && feature.labelSpec.field) {
        cell.textLabel.text = [NSString stringWithFormat:@"%@", graphic.attributes[feature.labelSpec.field]];
    } else if (feature.hasUniqueId) {
        NSString *cleanName = [feature.uniqueIdName stringByReplacingOccurrencesOfString:kAttributePrefix withString:@""];
        cell.textLabel.text = [NSString stringWithFormat:@"%@", graphic.attributes[cleanName]];
    } else {
        id item = graphic.attributes[@"timestamp"];
        NSDate *timestamp = nil;
        if ([item isKindOfClass:[NSDate class]]) {
            timestamp = (NSDate *)item;
        }
        if (timestamp) {
            if (timestamp.today) {
                cell.textLabel.text = timestamp.stringWithMediumTimeFormat;
            } else {
                cell.textLabel.text = timestamp.stringWithMediumDateTimeFormat;
            }
        } else {
            cell.textLabel.text = @"Unknown timestamp";
        }
    }
    return cell;
}




#pragma mark - UITableView Delegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.featureSelectedCallback) {
        NSString *layerName = self.layerNames[indexPath.usection];
        NSArray *graphics = (NSArray *)self.graphics[indexPath.usection];
        id graphic = graphics[indexPath.urow];
        self.featureSelectedCallback(layerName, graphic);
    }
}




#pragma mark - private methods

- (CGFloat)heightForTableContents
{
    CGFloat height = 0;
    NSInteger sections = [self numberOfSectionsInTableView:self.tableView];
    height = self.tableView.sectionHeaderHeight * sections;
    for (NSInteger i = 0; i < sections; i++) {
        NSInteger rows = [self tableView:self.tableView numberOfRowsInSection:i];
        //height += self.tableView.rowHeight * rows;
        //despite row height being set in IB, it is coming back as -1
        height += 44 * rows;
    }
    return kPopoverMaxHeight < height ? kPopoverMaxHeight : height;
}

@end
