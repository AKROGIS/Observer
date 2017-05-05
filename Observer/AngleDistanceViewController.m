//
//  AngleDistanceViewController.m
//  Observer
//
//  Created by Regan Sarwas on 7/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AngleDistanceViewController.h"


@interface AngleDistanceViewController ()

@property (weak, nonatomic) IBOutlet UILabel *detailsLabel;
@property (weak, nonatomic) IBOutlet UITextField *angleTextField;
@property (weak, nonatomic) IBOutlet UITextField *distanceTextField;
@property (strong, nonatomic) NSPredicate *angleRegex;
@property (strong, nonatomic) NSPredicate *distanceRegex;
@property (strong, nonatomic) NSNumberFormatter *parser;
@property (strong, nonatomic) NSArray * textFields; //of UITextField

@property (strong, nonatomic) NSString *initialAngle;
@property (strong, nonatomic) NSString *initialDistance;

@end

@implementation AngleDistanceViewController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateView];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[self.view viewWithTag:1] becomeFirstResponder];
}

- (void) viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    [super viewDidDisappear:animated];
}



#pragma mark - IBActions

- (IBAction)done:(UIBarButtonItem *)sender {
    if (self.completionBlock) {
        self.completionBlock(self);
    }
}

- (IBAction)cancel:(id)sender {
    if (self.cancellationBlock) {
        self.cancellationBlock(self);
    }
}

- (IBAction)textFieldEditingDidChange:(UITextField *)sender {
    NSString *angleText = self.angleTextField.text;
    NSString *distanceText = self.distanceTextField.text;
    self.location.angle = (angleText == nil) ? nil : [self.parser numberFromString:angleText];
    self.location.distance = (distanceText == nil) ? nil : [self.parser numberFromString:distanceText];
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
        if (nextTag < 0 || (NSUInteger)nextTag > self.textFields.count)
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
        _parser.numberStyle = NSNumberFormatterDecimalStyle;
        _parser.locale = [NSLocale currentLocale];
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

- (void) updateView
{
    [self updateDefaultValues];
    [self updateLabel];
    [self updateControlState:self.textFields.lastObject];
}

- (void) updateDefaultValues
{
    if (self.location.defaultAngle != nil) {
        self.initialAngle = [NSString stringWithFormat:@"%@", self.location.angle];
    } else {
        self.initialAngle = nil;
    }
    self.angleTextField.text = self.initialAngle;
    
    if (self.location.defaultDistance != nil) {
        self.initialDistance = [NSString stringWithFormat:@"%@", self.location.distance];
    } else {
        self.initialDistance = nil;
    }
    self.distanceTextField.text = self.initialDistance;
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
}

- (void) updateControlState:(UITextField *)textField
{
    BOOL inputIsComplete = self.location.isComplete;
    BOOL canBeDone = self.location.isValid && inputIsComplete;
    self.navigationItem.rightBarButtonItem.enabled = canBeDone;
    textField.returnKeyType = canBeDone ? UIReturnKeyDone : UIReturnKeyNext;
    //TODO: #178 keyboard view does not update until focus changes to new view
    //TODO: #178 other textfields should also be updated to UIReturnKeyDone without requiring a text changed event
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
