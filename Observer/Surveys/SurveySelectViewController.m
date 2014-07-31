//
//  SurveySelectViewController.m
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "SurveySelectViewController.h"
#import "SurveyCollection.h"
#import "SurveyDetailViewController.h"
#import "SurveyTableViewCell.h"
#import "ProtocolSelectViewController.h"
#import "SurveyUploadTableViewController.h"
#import "SProtocol.h"
#import "Survey.h"
#import "NSIndexPath+unsignedAccessors.h"

@interface SurveySelectViewController ()
@property (nonatomic, strong) SurveyCollection *items; //Model
@property (strong, nonatomic) UIBarButtonItem *addButton;
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
    [self configureControlsEnableAddButton:YES];
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
    [super viewWillAppear:animated];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self.navigationController setToolbarHidden:NO animated:NO];
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self.navigationController setToolbarHidden:YES animated:NO];
    }
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Releasing the collection will save memory, but will also take time to recreate collection on each VC load
- (void)dealloc
{
    [SurveyCollection releaseSharedCollection];
}




#pragma mark - lazy property initializers

- (SurveyCollection *)items
{
    if (!_items) {
        SurveyCollection *surveys = [SurveyCollection sharedCollection];
        [surveys openWithCompletionHandler:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.items = surveys;
                [self.tableView reloadData];
            });
        }];
    }
    return _items;
}

- (void) addSurvey:(Survey *)survey
{
    [self.items insertSurvey:survey atIndex:0];
    [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
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
    return (NSInteger)self.items.numberOfSurveys;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SurveyTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SurveyCell" forIndexPath:indexPath];
    id<AKRTableViewItem> item = [self.items surveyAtIndex:indexPath.urow];
    cell.titleTextField.text = item.title;
    cell.protocolLabel.text = item.subtitle;
    cell.detailsLabel.text = item.subtitle2;
    cell.thumbnailImageView.image = item.thumbnail;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.surveySelectedAction) {
        self.surveySelectedAction([self.items surveyAtIndex:indexPath.urow]);
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
    [self.items moveSurveyAtIndex:fromIndexPath.urow toIndex:toIndexPath.urow];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Survey *surveyToDelete = [self.items surveyAtIndex:indexPath.urow];
        self.indexPathToDelete = indexPath;
        if (surveyToDelete.state == kModified) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unsaved Changes"
                                                            message:@"You will lose your unsaved data.  This cannot be undone."
                                                           delegate:self
                                                  cancelButtonTitle:@"Keep"
                                                  otherButtonTitles:@"Delete",nil];
            [alert show];
        } else {
            [self deleteSurvey];
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
        Survey *survey = [self.items surveyAtIndex:indexPath.urow];
        ((SurveyDetailViewController *)segue.destinationViewController).survey = survey;
        //if we are in a popover, we want the new vc to stay the same size.
        [[segue destinationViewController] setPreferredContentSize:self.preferredContentSize];
    }
    if ([[segue identifier] isEqualToString:@"Upload Survey"]) {
        //superview^3 hack to get the UITableViewCell from the upload button
        NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)[[[sender superview] superview] superview]];
        Survey *survey = [self.items surveyAtIndex:indexPath.urow];
        ((SurveyUploadTableViewController *)segue.destinationViewController).survey = survey;
        [[segue destinationViewController] setPreferredContentSize:self.preferredContentSize];
    }
    if ([[segue identifier] isEqualToString:@"Select Protocol"]) {
        ProtocolSelectViewController *vc = (ProtocolSelectViewController *)segue.destinationViewController;
        vc.title = segue.identifier;
        vc.protocolSelectedAction = ^(SProtocol *protocol){
            [self newSurveyWithProtocol:protocol];
            [self.navigationController popViewControllerAnimated:YES];
        };
        //if we are in a popover, we want the new vc to stay the same size.
        [[segue destinationViewController] setPreferredContentSize:self.preferredContentSize];
    }
}

- (void) newSurveyWithProtocol:(SProtocol *)protocol
{
    AKRLog(@"New survey with protocol %@", protocol.title);
    Survey *newSurvey = [[Survey alloc] initWithProtocol:protocol];
    if (newSurvey.isValid) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.items insertSurvey:newSurvey atIndex:0];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [[[UIAlertView alloc] initWithTitle:nil message:@"New survey could not be created." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    }
}



#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([alertView.title isEqualToString:@"Unsaved Changes"]) {
        if (buttonIndex == 1) {
            [self deleteSurvey];
        } else {
            self.editing = NO;
        }
    } else {
        AKRLog(@"Unexpected AlertView in SurveySelectViewController");
    }
}

- (void)deleteSurvey
{
    if(self.indexPathToDelete) {
        Survey *survey = [self.items surveyAtIndex:self.indexPathToDelete.urow];
        //give the invoker notice, so they can cleanup/close before we remove the file.
        if (self.surveyDeletedAction) {
            self.surveyDeletedAction(survey);
        }
        [self.items removeSurveyAtIndex:self.indexPathToDelete.urow];
        [self.tableView deleteRowsAtIndexPaths:@[self.indexPathToDelete] withRowAnimation:UITableViewRowAnimationAutomatic];
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
    Survey *survey = [self.items surveyAtIndex:indexPath.urow];
    AKRLog(@"Going to rename %@ to %@", survey.title, textField.text);
    survey.title = textField.text;
    if (self.surveyUpdatedAction) {
        self.surveyUpdatedAction(survey);
    }
}

@end
