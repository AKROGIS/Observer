//
//  SurveySelectViewController.m
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveyDetailViewController.h"
#import "SurveyTableViewCell.h"
#import "ProtocolSelectViewController.h"
#import "SurveySelectViewController.h"
#import "SProtocol.h"
#import "Survey.h"

@interface SurveySelectViewController ()
@property (nonatomic) BOOL isBackgroundRefreshing;
@property (strong, nonatomic) ProtocolCollection* protocols;
@property (strong, nonatomic) NSIndexPath *indexPathToDelete;
@end

@implementation SurveySelectViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

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

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.toolbarItems = @[self.editButtonItem,spacer,addButton];

    self.detailViewController = (SurveyDetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];

    addButton.enabled = NO;
    self.protocols = [ProtocolCollection sharedCollection];
    [self.protocols openWithCompletionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            addButton.enabled = YES;
        });
    }];
}

- (void) configureView
{
}

-(void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:NO animated:NO];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:YES animated:NO];
    [ProtocolCollection releaseSharedCollection];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)insertNewObject:(id)sender
{
    if (!self.items) {
        return;
    }
    //[self insertNewObject];
    [self performSegueWithIdentifier:@"Select Protocol" sender:sender];
}


#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.numberOfSurveys;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SurveyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SurveyCell" forIndexPath:indexPath];
    id<AKRTableViewItem> item = [self.items surveyAtIndex:indexPath.row];
    cell.titleTextField.text = item.title;
    cell.protocolLabel.text = item.subtitle;
    cell.detailsLabel.text = item.subtitle2;
    cell.thumbnailImageView.image = item.thumbnail;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.items setSelectedSurvey:indexPath.row];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self.popover dismissPopoverAnimated:YES];
        self.popoverDismissedCallback();
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    [self.items moveSurveyAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Survey *survey = self.items.selectedSurvey;
        if (survey.state == kModified) {
            self.indexPathToDelete = indexPath;
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unsaved Changes"
                                                            message:@"You will lose your unsaved data.  This cannot be undone."
                                                           delegate:self
                                                  cancelButtonTitle:@"Keep"
                                                  otherButtonTitles:@"Delete",nil];
            [alert show];
        } else {
            [self.items removeSurveyAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}


- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"Show Detail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        id<AKRTableViewItem> item = [self.items surveyAtIndex:indexPath.row];
        [[segue destinationViewController] setDetailItem:item];
        //if we are in a popover, we want the new vc to stay the same size.
        [[segue destinationViewController] setPreferredContentSize:self.preferredContentSize];
    }
    if ([[segue identifier] isEqualToString:@"Select Protocol"]) {
        ProtocolSelectViewController *vc = (ProtocolSelectViewController *)segue.destinationViewController;
        vc.title = segue.identifier;
        vc.items = self.protocols;
        vc.rowSelectedCallback = ^(NSIndexPath *indexPath){
            [self newSurveyWithProtocol:[self.protocols localProtocolAtIndex:indexPath.row]];
        };
        //if we are in a popover, we want the new vc to stay the same size.
        [[segue destinationViewController] setPreferredContentSize:self.preferredContentSize];
    }
}


- (void) newSurveyWithProtocol:(SProtocol *)protocol
{
    NSLog(@"New survey with protocol %@", protocol.title);
    NSInteger row = [self.items newSurveyWithProtocol:protocol];
    if (0 <= row) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        //TODO: alert unable to create new survey
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1 && self.indexPathToDelete) {
        [self.items removeSurveyAtIndex:self.indexPathToDelete.row];
        [self.tableView deleteRowsAtIndexPaths:@[self.indexPathToDelete] withRowAnimation:UITableViewRowAnimationFade];
        self.indexPathToDelete = nil;
    }
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self textChanged:textField];
}

- (void)textChanged:(UITextField *)textField
{
    UIView * view = textField.superview;
    while( ![view isKindOfClass: [SurveyTableViewCell class]]){
        view = view.superview;
    }
    SurveyTableViewCell *cell = (SurveyTableViewCell *) view;
    NSIndexPath * indexPath = [self.tableView indexPathForCell:cell];
    Survey *survey = [self.items surveyAtIndex:indexPath.row];
    NSLog(@"Going to rename %@ to %@", survey.title, textField.text);
    survey.title = textField.text;
}

@end
