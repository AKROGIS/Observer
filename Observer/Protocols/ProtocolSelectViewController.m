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
#import "ProtocolCollection.h"
#import "ProtocolDetailViewController.h"
#import "NSIndexSet+indexPath.h"
#import "NSDate+Formatting.h"
#import "Settings.h"
#import "NSIndexPath+unsignedAccessors.h"

@interface ProtocolSelectViewController ()
@property (strong, nonatomic) ProtocolCollection *items; //Model
@property (nonatomic) BOOL showRemoteProtocols;
@property (nonatomic) BOOL isBackgroundRefreshing;
@property (weak, nonatomic) IBOutlet UILabel *refreshLabel;
@property (strong, nonatomic) ProtocolDetailViewController *detailViewController;
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
    self.showRemoteProtocols = ![Settings manager].hideRemoteProtocols;
    self.refreshControl = [UIRefreshControl new];
}

-(void)viewWillAppear:(BOOL)animated
{
}

-(void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES animated:NO];
    [Settings manager].hideRemoteProtocols = !self.showRemoteProtocols;
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

- (ProtocolCollection *)items
{
    if (!_items) {
        _items = [ProtocolCollection sharedCollection];
        _items.delegate = self;
        ProtocolCollection *protocols = [ProtocolCollection sharedCollection];
        [protocols openWithCompletionHandler:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.items = protocols;
                [self.tableView reloadData];
                [self setFooterText];
                [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
            });
        }];
    }
    return _items;
}



#pragma mark - Public Methods

- (void) addProtocol:(SProtocol *)protocol
{
    [self.items insertLocalProtocol:protocol atIndex:0];
    [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
}



#pragma mark - CollectionChanged

//These delegates will be called on the main queue whenever the datamodel has changed
- (void) collection:(id)collection addedLocalItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:0];
    [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void) collection:(id)collection addedRemoteItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:1];
    if (self.showRemoteProtocols) {
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void) collection:(id)collection removedLocalItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:0];
    [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void) collection:(id)collection removedRemoteItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:1];
    if (self.showRemoteProtocols) {
        [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void) collection:(id)collection changedLocalItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:0];
    [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void) collection:(id)collection changedRemoteItemsAtIndexes:(NSIndexSet *)indexSet
{
    NSArray *indexPaths = [indexSet indexPathsWithSection:1];
    if (self.showRemoteProtocols) {
        [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
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
        return (NSInteger)self.items.numberOfLocalProtocols;
    }
    if (section == 1 && self.showRemoteProtocols) {
        return (NSInteger)self.items.numberOfRemoteProtocols;
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
        SProtocol *item = (indexPath.section == 0) ? [self.items localProtocolAtIndex:indexPath.urow] : [self.items remoteProtocolAtIndex:indexPath.urow];
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
        [tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)] withRowAnimation:UITableViewRowAnimationAutomatic];
        return;
    }

    if (indexPath.section == 1) {
        if (self.isBackgroundRefreshing)
        {
            [[[UIAlertView alloc] initWithTitle:@"Try Again" message:@"Can not download while refreshing.  Please try again when refresh is complete." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        } else {
            [self downloadItem:indexPath];
        }
        return;
    }

    if (indexPath.section == 0) {
        if (self.protocolSelectedAction) {
            self.protocolSelectedAction([self.items localProtocolAtIndex:indexPath.urow]);
        }
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
        [self.items moveLocalProtocolAtIndex:fromIndexPath.urow toIndex:toIndexPath.urow];
    }
    if (fromIndexPath.section == 1) {
        [self.items moveRemoteProtocolAtIndex:fromIndexPath.urow toIndex:toIndexPath.urow];
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
        [self.items removeLocalProtocolAtIndex:indexPath.urow];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

-(void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationAutomatic];
}

-(void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    //This is called _during_ the swipe to delete CommitEditing, and is ignored unless we dispatch it for later
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setEditing:NO animated:YES];
    });
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"Protocol Details"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        SProtocol *item = indexPath.section == 0 ? [self.items localProtocolAtIndex:indexPath.urow] :  [self.items remoteProtocolAtIndex:indexPath.urow];
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
    self.items.delegate = self;
    [self.items refreshWithCompletionHandler:^(BOOL success) {
        //on background thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];
            self.isBackgroundRefreshing = NO;
            if (success) {
                if (!self.showRemoteProtocols) {
                    self.showRemoteProtocols = YES;
                    [self.tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            } else {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can't connect to server" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }
            [self setFooterText];
            self.items.delegate = nil;
        });
    }];
}

- (void) downloadItem:(NSIndexPath *)indexPath
{
    [self.items prepareToDownloadProtocolAtIndex:indexPath.urow];
    UITableView *tableView = self.tableView;
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    self.items.delegate = self;
    [self.items downloadProtocolAtIndex:indexPath.urow WithCompletionHandler:^(BOOL success) {
        //on background thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) {
               [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Can't download protocol" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
                [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            } else {
                // updates are done by delegate calls
            }
            self.items.delegate = nil;
        });
    }];
}

- (void)setFooterText
{
    if (self.items.refreshDate) {
        if ([self.items.refreshDate isToday]) {
            self.refreshLabel.text = [NSString stringWithFormat:@"Updated %@",[self.items.refreshDate stringWithMediumTimeFormat]];
        } else {
            self.refreshLabel.text = [NSString stringWithFormat:@"Updated %@",[self.items.refreshDate stringWithMediumDateFormat]];
        }
    }
}


@end
