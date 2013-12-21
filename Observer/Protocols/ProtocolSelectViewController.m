//
//  ProtocolSelectViewController.m
//  Observer
//
//  Created by Regan Sarwas on 11/20/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "ProtocolSelectViewController.h"
#import "ProtocolTableViewCell.h"
#import "SProtocol.h"
#import "NSIndexSet+indexPath.h"
#import "NSDate+Formatting.h"
#import "Settings.h"

@interface ProtocolSelectViewController ()
@property (nonatomic) BOOL showRemoteProtocols;
@property (nonatomic) BOOL isBackgroundRefreshing;
@property (weak, nonatomic) IBOutlet UILabel *refreshLabel;
@end

@implementation ProtocolSelectViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(380.0, 480.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.showRemoteProtocols = [Settings manager].showRemoteProtocols;
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    if (self.items.refreshDate) {
        [self setFooterText];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
}

-(void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES animated:NO];
    [Settings manager].showRemoteProtocols = self.showRemoteProtocols;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    self.detailViewController = nil;
}

#pragma mark - lazy property initializers

- (ProtocolDetailViewController *)detailViewController
{
    if (!_detailViewController) {
        _detailViewController = (ProtocolDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    }
    return _detailViewController;
}

- (void) setItems:(ProtocolCollection *)items
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
    if (self.showRemoteProtocols) {
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
    if (self.showRemoteProtocols) {
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
    if (self.showRemoteProtocols) {
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
        return self.items.numberOfLocalProtocols;
    }
    if (section == 1 && self.showRemoteProtocols) {
        return self.items.numberOfRemoteProtocols;
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
    if (section == 1 && self.showRemoteProtocols ) {
        return @"In the cloud";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 2) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ProtocolButtonCell" forIndexPath:indexPath];
        cell.textLabel.textColor = cell.tintColor;
        cell.textLabel.text = self.showRemoteProtocols ? @"Show Only Downloaded Protocols" : @"Show All Protocols";
        return cell;
    } else {
        SProtocol *item = (indexPath.section == 0) ? [self.items localProtocolAtIndex:indexPath.row] : [self.items remoteProtocolAtIndex:indexPath.row];
        NSString *identifier = (indexPath.section == 0) ? @"LocalProtocolCell" : @"RemoteProtocolCell";
        ProtocolTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
        cell.titleLabel.text = item.title;
        cell.subtitleLabel.text = item.subtitle;
        cell.downloadImageView.hidden = item.isDownloading;
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    if (indexPath.section == 2) {
        self.showRemoteProtocols = ! self.showRemoteProtocols;
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

    [self.items setSelectedLocalProtocol:indexPath.row];
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
        [self.items moveLocalProtocolAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
    }
    if (fromIndexPath.section == 1) {
        [self.items moveRemoteProtocolAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
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
        [self.items removeLocalProtocolAtIndex:indexPath.row];
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
    if ([segue.identifier isEqualToString:@"Protocol Details"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        SProtocol *item = indexPath.section == 0 ? [self.items localProtocolAtIndex:indexPath.row] :  [self.items remoteProtocolAtIndex:indexPath.row];
        ProtocolDetailViewController *vc = (ProtocolDetailViewController *)[segue destinationViewController];
        vc.title = segue.identifier;
        vc.protocol = item;
        //if we are in a popover, we want the popover to stay the same size.
        [vc setPreferredContentSize:self.preferredContentSize];
    }
}

- (void) refresh:(id)sender
{
    self.refreshLabel.text = @"Looking for new protocols...";
    [self.refreshControl beginRefreshing];
    self.isBackgroundRefreshing = YES;
    [self.items refreshWithCompletionHandler:^(BOOL success) {
        //on abackground thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];
            self.isBackgroundRefreshing = NO;
            if (success) {
                if (!self.showRemoteProtocols) {
                    self.showRemoteProtocols = YES;
                    [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)] withRowAnimation:YES];
                }
            } else {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can't connect to server" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }
            [self setFooterText];
        });
    }];
}

- (void) downloadItem:(NSIndexPath *)indexPath
{
    [self.items prepareToDownloadProtocolAtIndex:indexPath.row];
    UITableView *tableView = self.tableView;
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [self.items downloadProtocolAtIndex:indexPath.row WithCompletionHandler:^(BOOL success) {
        //on background thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
               [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can't download protocol" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
                [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:YES];
            } else {
                // updates are done by delegate calls
            }
        });
    }];
}

- (void)setFooterText
{
    if ([self.items.refreshDate isToday]) {
        self.refreshLabel.text = [NSString stringWithFormat:@"Updated %@",[self.items.refreshDate stringWithMediumTimeFormat]];
    } else {
        self.refreshLabel.text = [NSString stringWithFormat:@"Updated %@",[self.items.refreshDate stringWithMediumDateFormat]];
    }
}


@end
