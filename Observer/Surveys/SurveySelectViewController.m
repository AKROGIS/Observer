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
@property (strong, nonatomic) UIBarButtonItem *addButton;
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
    [self configureControlsEnableAddButton:NO];
    self.protocols = [ProtocolCollection sharedCollection];
    [self.protocols openWithCompletionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self configureControlsEnableAddButton:YES];
        });
    }];
}

- (void)configureControlsEnableAddButton:(BOOL)enableAdd
{
    if (enableAdd) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            self.navigationItem.leftBarButtonItem = self.addButton;
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
        } else {
            UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
            self.toolbarItems = @[self.editButtonItem,spacer,self.addButton];
        }
    } else {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            self.navigationItem.leftBarButtonItem = nil;
            self.navigationItem.rightBarButtonItem = self.editButtonItem;
        } else {
            self.toolbarItems = @[self.editButtonItem];
        }

    }
}

-(void)viewWillAppear:(BOOL)animated
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self.navigationController setToolbarHidden:NO animated:NO];
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self.navigationController setToolbarHidden:YES animated:NO];
    }
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
    [self performSegueWithIdentifier:@"Select Protocol" sender:sender];
}

-(UIBarButtonItem *)addButton {
    if (!_addButton) {
        _addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    }
    return _addButton;
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
        if (self.selectedSurveyChanged) {
            self.selectedSurveyChanged();
        }
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
            if (self.selectedSurveyChanged) {
                self.selectedSurveyChanged();
            }
        }
    }
}

-(void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    [self configureControlsEnableAddButton:!editing];
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
    AKRLog(@"New survey with protocol %@", protocol.title);
    NSInteger row = [self.items newSurveyWithProtocol:protocol];
    if (0 <= row) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Error"
                                    message:@"The new survey could not be created."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}



#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Unsaved Changes"]) {
        if (buttonIndex == 1 && self.indexPathToDelete) {
            [self.items removeSurveyAtIndex:self.indexPathToDelete.row];
            [self.tableView deleteRowsAtIndexPaths:@[self.indexPathToDelete] withRowAnimation:UITableViewRowAnimationFade];
            self.indexPathToDelete = nil;
            if (self.selectedSurveyChanged) {
                self.selectedSurveyChanged();
            }
        }
    } else {
        AKRLog(@"Unexpected AlertView in SurveySelectViewController");
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
    AKRLog(@"Going to rename %@ to %@", survey.title, textField.text);
    survey.title = textField.text;
    if (survey == self.items.selectedSurvey && self.selectedSurveyChangedName) {
        self.selectedSurveyChangedName();
    }
}

@end
