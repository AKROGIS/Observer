//
//  AngleDistanceViewController.m
//  Observer
//
//  Created by Regan Sarwas on 7/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AngleDistanceViewController.h"
#import "AngleDistanceSettingsTableViewController.h"

#define TEXTMARGINS 60  //2*30pts

@interface AngleDistanceViewController ()

@property (weak, nonatomic) IBOutlet UILabel *detailsLabel;
@property (weak, nonatomic) IBOutlet UIButton *basisButton;
@property (weak, nonatomic) IBOutlet UITextField *angleTextField;
@property (weak, nonatomic) IBOutlet UITextField *distanceTextField;
@property (strong, nonatomic) NSPredicate *angleRegex;
@property (strong, nonatomic) NSPredicate *distanceRegex;
@property (strong, nonatomic) NSNumberFormatter *parser;
@property (strong, nonatomic) NSArray * textFields; //of UITextField

@property (strong, nonatomic) NSString *initialAngle;
@property (strong, nonatomic) NSString *initialDistance;
@property (nonatomic) BOOL isViewLayout;

@end

@implementation AngleDistanceViewController

- (void)awakeFromNib
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.preferredContentSize = CGSizeMake(320.0, 216.0);
    }
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateView];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];
    self.detailsLabel.preferredMaxLayoutWidth = self.preferredContentSize.width - TEXTMARGINS;
    [self resizeView];
    [[self.view viewWithTag:1] becomeFirstResponder];
}

- (void) viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    [super viewDidDisappear:animated];
}

- (void) viewDidLayoutSubviews
{
    self.isViewLayout = YES;
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"PushAngleDistanceSettings"]) {
        self.modalInPopover = YES; //disable tap outside popover when sub VC is shown
        AngleDistanceSettingsTableViewController *vc = (AngleDistanceSettingsTableViewController *)segue.destinationViewController;
        vc.completionBlock = ^(AngleDistanceSettingsTableViewController *sender) {
            BOOL userHasProgressed = self.location.isValid && [self anyInputFieldHasChanged];
            self.modalInPopover = userHasProgressed;
            [self updateLabel];
            [self resizeView];
            //If the view size doesn't change, thenwe will be stuck at the sub VC size, this will ensure we are resized.
            [self.popover setPopoverContentSize:self.preferredContentSize animated:YES];
        };
    }
}


#pragma mark - IBActions

- (IBAction)done:(UIBarButtonItem *)sender {
    if (self.completionBlock) {
        self.completionBlock(self);
    }
    [self.popover dismissPopoverAnimated:YES];
}

- (IBAction)cancel:(id)sender {
    if (self.cancellationBlock) {
        self.cancellationBlock(self);
    }
    [self.popover dismissPopoverAnimated:YES];
}

- (IBAction)textFieldEditingDidChange:(UITextField *)sender {
    self.location.angle = [self.parser numberFromString:self.angleTextField.text];
    self.location.distance = [self.parser numberFromString:self.distanceTextField.text];
    [self updateControlState:sender];
}


#pragma mark - UITextField Delegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (4 < newText.length)
        return NO;
    if ([newText isEqualToString:@""])
        return YES;
    if (textField == self.angleTextField) {
        if ([newText isEqualToString:@"-"])
            return YES;
        return [self.angleRegex evaluateWithObject:newText];
    }
    if (textField == self.distanceTextField) {
        return [self.distanceRegex evaluateWithObject:newText];
    }
    return NO;
}

//See the IBAction for the textDidChangeEvent

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField.returnKeyType == UIReturnKeyNext) {
        NSInteger nextTag = textField.tag + 1;
        if (nextTag > self.textFields.count)
            nextTag = 1;
        [[self.view viewWithTag:nextTag] becomeFirstResponder];
        return NO;
    }
    if (textField.returnKeyType == UIReturnKeyDone) {
        [textField resignFirstResponder];
        [self done:nil];
        return NO;
    }
    return YES;
}


#pragma mark - Public Properties

- (void) setLocation:(LocationAngleDistance *)location {
    _location = location;
    [self updateView];
    if (self.isViewLayout) {
        [self resizeView];
    }
}


#pragma mark - Private Methods

- (NSPredicate *) angleRegex
{
    if (!_angleRegex)
        _angleRegex = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^-?\\d+$"];
    return _angleRegex;
}

- (NSPredicate *) distanceRegex
{
    if (!_distanceRegex)
        _distanceRegex = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^\\d*$"];
    return _distanceRegex;
}

- (NSNumberFormatter *)parser
{
    if (!_parser)
    {
        _parser = [[NSNumberFormatter alloc] init];
        [_parser setNumberStyle:NSNumberFormatterDecimalStyle];
        [_parser setLocale:[NSLocale currentLocale]];
    }
    return _parser;
}

- (NSArray *) textFields
{
    if (!_textFields) {
        NSMutableArray *textFields = [[NSMutableArray alloc] init];
        for (UIView *view in self.view.subviews) {
            if ([view isKindOfClass:[UITextField class]]) {
                [textFields addObject:view];
            }
        }
        _textFields = [textFields copy];
    }
    return _textFields;
}

- (void) settingsDidChange:(NSNotification *)notification
{
    [self updateLabel];
    [self resizeView];
}

- (void) updateView
{
    [self updateDefaultValues];
    [self updateBasisButton];
    [self updateLabel];
    [self updateControlState:[self.textFields lastObject]];
}

- (void) updateDefaultValues
{
    if (self.location.defaultAngle) {
        self.initialAngle = [NSString stringWithFormat:@"%@", self.location.angle];
    } else {
        self.initialAngle = nil;
    }
    self.angleTextField.text = self.initialAngle;
    
    if (self.location.defaultDistance) {
        self.initialDistance = [NSString stringWithFormat:@"%@", self.location.distance];
    } else {
        self.initialDistance = nil;
    }
    self.distanceTextField.text = self.initialDistance;
}

- (void) updateBasisButton
{
    if (self.location.usesProtocol) {
        if ([self.basisButton isDescendantOfView:self.view]) {
            [self removeButton];
        }
    }
    else {
        if (![self.basisButton isDescendantOfView:self.view]) {
            [self addButton];
        }
    }
}

- (void) addButton
{
    //FIXME: add button to view heiracrcy
    //FIXME: add constraints??
    //FIXME: resize view
}

- (void) removeButton
{
    [self.basisButton removeFromSuperview];
}

- (void) updateLabel
{
    if (!self.location.isValid)
    {
        self.detailsLabel.text = @"Give up.  The current location and/or heading is unknown";
        self.detailsLabel.textColor = [UIColor redColor];
    }
    else
    {
        self.detailsLabel.text = self.location.basisDescription;
        self.detailsLabel.textColor = [UIColor darkTextColor];
    }
    [self.detailsLabel sizeToFit];
}

- (void) updateControlState:(UITextField *)textField
{
    BOOL userHasProgressed = self.location.isValid && [self anyInputFieldHasChanged];
    self.modalInPopover = userHasProgressed;
    
    BOOL inputIsComplete = self.location.isComplete;
    BOOL canBeDone = self.location.isValid && inputIsComplete;
    self.navigationItem.rightBarButtonItem.enabled = canBeDone;
    textField.returnKeyType = canBeDone ? UIReturnKeyDone : UIReturnKeyNext;
    //FIXME: keyboard view does not update until focus changes to new view
    //FIXME: other textfields should also be updated to UIReturnKeyDone without requiring a text changed event
}

- (void) resizeView
{
    [self.view layoutSubviews];
    CGRect frame = self.view.frame;
    CGFloat height;
    if ([self.basisButton isDescendantOfView:self.view]) {
        height = self.basisButton.frame.origin.y + self.basisButton.frame.size.height + 20;
    }
    else {
        height = self.detailsLabel.frame.origin.y + self.detailsLabel.frame.size.height + 20;
    }
    frame.size.height = height;
    self.view.frame = frame;
    //only if contentSizeForViewInPopover values change will the popover will resize
    self.preferredContentSize = self.view.frame.size;
}

- (BOOL) anyInputFieldHasChanged
{
    
    NSString *angle = self.angleTextField.text;
    NSString *distance = self.angleTextField.text;
    
    //Caution: nils require special consideration
    return (!angle && self.initialAngle) ||
           (angle && (!self.initialAngle || ![angle isEqualToString:self.initialAngle])) ||
           (!distance && self.initialDistance) ||
           (distance && (!self.initialDistance || ![distance isEqualToString:self.initialDistance]));
}

/*
- (BOOL) xvalidTextField:(UITextField *)textField
{
    switch (textField.tag) {
        case 1:
            return self.location.angle ? YES : NO;
        case 2:
            return self.location.distance ? YES : NO;
        default:
            return NO;
    }
}
*/
@end
