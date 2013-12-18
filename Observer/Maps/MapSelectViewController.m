//
//  MapSelectViewController.m
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "MapSelectViewController.h"
#import "Map.h"
#import "NSIndexSet+indexPath.h"

#import "MapDetailViewController.h"
//#import "FSEntryCell.h"
#import "MapTableViewCell.h"


@interface MapSelectViewController ()
@property (nonatomic) BOOL showRemoteItems;
@property (nonatomic) BOOL isBackgroundRefreshing;
@property (nonatomic, strong) UITableViewHeaderFooterView *footerView;
@end

@implementation MapSelectViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(420.0, 580.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    //FIXME: use setting manager in observer
    //self.showRemoteItems = [Settings manager].showRemoteItems
    self.showRemoteItems = [[NSUserDefaults standardUserDefaults] boolForKey:@"showRemoteMaps"];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    self.footerView = [UITableViewHeaderFooterView new];
    self.tableView.tableFooterView = self.footerView;
    if (self.items.refreshDate) {
        [self setFooterText];
    } else {
        ((UITableViewHeaderFooterView *)self.tableView.tableFooterView).textLabel.text = @"Pull to refresh.";
    }
}

-(void)viewWillAppear:(BOOL)animated
{
}

-(void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES animated:NO];
    //FIXME: use setting manager in observer
    //[Settings manager].showRemoteItems = self.showRemoteItems
    [[NSUserDefaults standardUserDefaults] setBool:self.showRemoteItems forKey:@"showRemoteMaps"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    self.detailViewController = nil;
}

#pragma mark - lazy property initializers

- (MapDetailViewController *)detailViewController
{
    if (!_detailViewController) {
        _detailViewController = (MapDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    }
    return _detailViewController;
}

- (void) setItems:(MapCollection *)items
{
    _items = items;
    items.delegate = self;
}

#pragma mark - CollectionChanged

//These delegates will be called on the main queue whenever the datamodel has changed
- (void) collection:(id)collection addedLocalItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:0];
    [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:YES];
}

- (void) collection:(id)collection addedRemoteItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:1];
    if (self.showRemoteItems) {
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:YES];
    }
}

- (void) collection:(id)collection removedLocalItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:0];
    [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:YES];
}

- (void) collection:(id)collection removedRemoteItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:1];
    if (self.showRemoteItems) {
        [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:YES];
    }
}

- (void) collection:(id)collection changedLocalItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:0];
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:YES];
}

- (void) collection:(id)collection changedRemoteItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:1];
    if (self.showRemoteItems) {
        [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:YES];
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.items.numberOfLocalMaps;
    }
    if (section == 1 && self.showRemoteItems) {
        return self.items.numberOfRemoteMaps;
    }
    if (section == 2) {
        return tableView.isEditing ? 0 : 1;
    }
    return 0;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return @"On this device";
    }
    if (section == 1 && self.showRemoteItems ) {
        return @"In the cloud";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 2) ? 40 : 75;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 2) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MapButtonCell" forIndexPath:indexPath];
        cell.textLabel.textColor = cell.tintColor;
        cell.textLabel.text = self.showRemoteItems ? @"Show Only Downloaded Maps" : @"Show All Maps";
        return cell;
    } else {
        Map *item = (indexPath.section == 0) ? [self.items localMapAtIndex:indexPath.row] : [self.items remoteMapAtIndex:indexPath.row];
        NSString *identifier = (indexPath.section == 0) ? @"LocalMapCell" : @"RemoteMapCell";
        MapTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
        cell.titleLabel.text = item.title;
        [item openThumbnailWithCompletionHandler:^(BOOL success) {
            //on background thread
            dispatch_async(dispatch_get_main_queue(), ^{
                cell.thumbnailImageView.image = item.thumbnail;
            });
        }];
        cell.subtitle1Label.text = item.subtitle;
        cell.subtitle2Label.text = item.subtitle2;
        cell.downloadImageView.hidden = item.isDownloading;
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{

    if (indexPath.section == 2) {
        self.showRemoteItems = ! self.showRemoteItems;
        [tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)] withRowAnimation:YES];
        return;
    }

    if (indexPath.section == 1) {
        if (self.isBackgroundRefreshing)
        {
            [[[UIAlertView alloc] initWithTitle:@"Try Again" message:@"Can not download while refreshing.  Please try again when refresh is complete." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            return;
        } else {
            [self downloadItem:indexPath];
            return;
        }
    }

    [self.items setSelectedLocalMap:indexPath.row];
    if (self.popover) {
        [self.popover dismissPopoverAnimated:YES];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
    if (self.rowSelectedCallback) {
        self.rowSelectedCallback(indexPath);
    }
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section < 2;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section < 2;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    return (proposedDestinationIndexPath.section == sourceIndexPath.section) ? proposedDestinationIndexPath : sourceIndexPath;
}

-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == 0  ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    if (fromIndexPath.section != toIndexPath.section) {
        return;
    }
    if (self.isBackgroundRefreshing)
    {
        [[[UIAlertView alloc] initWithTitle:@"Try Again" message:@"Could not make changes while refreshing.  Please try again when refresh is complete." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        return;
    }
    if (fromIndexPath.section == 0) {
        [self.items moveLocalMapAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
    }
    if (fromIndexPath.section == 1) {
        [self.items moveRemoteMapAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isBackgroundRefreshing)
    {
        [[[UIAlertView alloc] initWithTitle:@"Try Again" message:@"Could not make changes while refreshing.  Please try again when refresh is complete." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        return;
    }
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.items removeLocalMapAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

-(void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    if (self.isEditing) {
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:2]] withRowAnimation:YES];
    } else {
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:2]] withRowAnimation:YES];
    }
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"Map Details"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        Map *item = indexPath.section == 0 ? [self.items localMapAtIndex:indexPath.row] :  [self.items remoteMapAtIndex:indexPath.row];
        MapDetailViewController *vc = (MapDetailViewController *)[segue destinationViewController];
        vc.title = segue.identifier;
        vc.map = item;
        //if we are in a popover, we want the popover to stay the same size.
        [vc setPreferredContentSize:self.preferredContentSize];
    }
}

- (void) refresh:(id)sender
{
    [self.refreshControl beginRefreshing];
    self.footerView.textLabel.text = @"Checking for new protocols.";
    self.isBackgroundRefreshing = YES;
    [self.items refreshWithCompletionHandler:^(BOOL success) {
        //on abackground thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];
            self.isBackgroundRefreshing = NO;
            if (success) {
                if (!self.showRemoteItems) {
                    self.showRemoteItems = YES;
                    [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)] withRowAnimation:YES];
                }
            } else {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can't get the map list from the server" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }
            [self setFooterText];
        });
    }];
}

- (void) downloadItem:(NSIndexPath *)indexPath
{
    MapTableViewCell *cell = (MapTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
    if (cell.downloadView.downloading) {
        cell.downloadImageView.hidden = NO;
        cell.downloadView.downloading = NO;
        [self.items cancelDownloadMapAtIndex:indexPath.row];
    } else {
        [self.items prepareToDownloadMapAtIndex:indexPath.row];
        cell.downloadView.percentComplete = 0;
        cell.downloadImageView.hidden = YES;
        cell.downloadView.downloading = YES;
        Map *map = [self.items remoteMapAtIndex:indexPath.row];
        map.progressAction = ^(double bytesWritten, double bytesExpected) {
            dispatch_async(dispatch_get_main_queue(), ^{
                cell.downloadView.percentComplete =  bytesWritten/bytesExpected;
            });
        };
        map.completionAction = ^(NSURL *imageUrl, BOOL success) {
            //on background thread
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self.items moveRemoteMapAtIndex:indexPath.row toLocalMapAtIndex:0];
                } else {
                    [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can't download map" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
                    cell.downloadView.downloading = NO;
                    cell.downloadImageView.hidden = NO;
                }
            });
        };
        [map startDownload];
    }
}

- (void) stopDownloadItem:(NSIndexPath *)indexPath
{
    Map *map = [self.items remoteMapAtIndex:indexPath.row];
    [map stopDownload];
}

- (void)setFooterText
{
    self.footerView.textLabel.text = [NSString stringWithFormat:@"Updated %@",self.items.refreshDate];
}

@end

