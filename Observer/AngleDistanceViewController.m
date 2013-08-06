//
//  AngleDistanceViewController.m
//  Observer
//
//  Created by Regan Sarwas on 7/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AngleDistanceViewController.h"
#import "AGSPoint+AKRAdditions.h"
#import "Settings.h"
#import "AngleDistanceSettingsTableViewController.h"

@interface AngleDistanceViewController ()

@property (weak, nonatomic) IBOutlet UILabel *detailsLabel;
@property (weak, nonatomic) IBOutlet UIButton *basisButton;
@property (weak, nonatomic) IBOutlet UITextField *angleTextField;
@property (weak, nonatomic) IBOutlet UITextField *distanceTextField;
@property (strong, nonatomic) NSPredicate *angleRegex;
@property (strong, nonatomic) NSPredicate *distanceRegex;
@property (strong, nonatomic) NSNumberFormatter *parser;
@property (strong, nonatomic) NSArray * textFields; //of UITextField

@end

@implementation AngleDistanceViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self hideControls];
    [self updateControlState:[self.textFields lastObject]];
    //FIXME remove the basisButton if there is using protocol
}

- (void) viewWillAppear:(BOOL)animated
{
    [self settingsDidChange:nil];
    //FIXME - do a better job resizing.
    self.contentSizeForViewInPopover = CGSizeMake(320,250.0);
    self.navigationController.contentSizeForViewInPopover = self.contentSizeForViewInPopover;
    [super viewWillAppear:animated];
}

- (void) viewDidAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];
    [super viewDidAppear:animated];
    //FIXME - may need a resize if protocol changes or if settings change.
    [self.popover setPopoverContentSize:self.contentSizeForViewInPopover animated:YES];
    [[self.view viewWithTag:1] becomeFirstResponder];
}

- (void) viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"PushAngleDistanceSettings"]) {
        AngleDistanceSettingsTableViewController *vc = (AngleDistanceSettingsTableViewController *)segue.destinationViewController;
        //FIXME - does this VC need a protocol? only open the VC it if is appropriate for the protocol.
        vc.protocol = self.protocol;
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
    [self.popover dismissPopoverAnimated:YES];
}

- (IBAction)textFieldEditingDidChange:(UITextField *)sender {
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

- (void) setProtocol:(SurveyProtocol *)protocol
{
    _protocol = protocol;
    [self settingsDidChange:nil];
    [self hideControls];
}

- (void) setDefaultAngle:(NSNumber *)defaultAngle
{
    if (defaultAngle) {
        self.angleTextField.text = [NSString stringWithFormat:@"%@", defaultAngle];
    }
}

- (void) setDefaultDistance:(NSNumber *)defaultDistance
{
    if (defaultDistance) {
        double distance = [defaultDistance doubleValue];
        if (distance > 0)
        self.distanceTextField.text = [NSString stringWithFormat:@"%f", distance];
    }
}

- (NSNumber *) angle
{
    NSNumber *number = [self.parser numberFromString:self.angleTextField.text];
    return number;
}

- (NSNumber *) distance
{
    NSNumber *number = [self.parser numberFromString:self.distanceTextField.text];
    if ([number doubleValue] <= 0)
        return nil;
    return number;
}

- (AGSPoint *)observationPoint
{
    if (self.missingReferenceFrame || !self.distance || !self.angle)
        return nil;
    
    double referenceAngle = self.usesProtocol ? self.protocol.angleBaseline : [Settings manager].angleDistanceDeadAhead;
    AGSSRUnit distanceUnits = self.usesProtocol ? self.protocol.distanceUnits : [Settings manager].distanceUnitsForSightings;
    AngleDirection angleDirection = self.usesProtocol ? self.protocol.angleDirection : [Settings manager].angleDistanceAngleDirection;

    double course = [self.deadAhead doubleValue];
    double direction = angleDirection == AngleDirectionClockwise ? 1.0 : -1.0;
    double angle  = course + direction * ([self.angle doubleValue]- referenceAngle);
    return [self.gpsPoint pointWithAngle:angle distance:[self.distance doubleValue] units:distanceUnits];
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

- (void) hideControls
{
    //FIXME remove the basisButton if there is using protocol
    self.basisButton.hidden = self.usesProtocol;
    //FIXME - resize the view/popover
}

- (BOOL) usesProtocol
{
    return self.protocol && self.protocol.definesAngleDistanceMeasures;
}

- (void) settingsDidChange:(NSNotification *)notification
{
    [self updateLabel];
}

- (void) updateLabel
{
    if (self.missingReferenceFrame)
    {
        self.detailsLabel.text = @"Give up.  The current location and/or heading is unknown";
        self.detailsLabel.textColor = [UIColor redColor];
    }
    else
    {
        double referenceAngle = self.usesProtocol ? self.protocol.angleBaseline : [Settings manager].angleDistanceDeadAhead;
        AGSSRUnit distanceUnits = self.usesProtocol ? self.protocol.distanceUnits : [Settings manager].distanceUnitsForSightings;
        AngleDirection angleDirection = self.usesProtocol ? self.protocol.angleDirection : [Settings manager].angleDistanceAngleDirection;
        
        self.detailsLabel.text =
        [NSString stringWithFormat:@"Angle increases %@ with dead ahead equal to %u degrees. Distance is in %@.",
           angleDirection == 0 ? @"clockwise" : @"counter-clockwise",
           (int)referenceAngle,
           distanceUnits == AGSSRUnitMeter ? @"meters" :
           distanceUnits == AGSSRUnitFoot ? @"feet" :
           distanceUnits == AGSSRUnitInternationalYard ? @"yards" : @"unknown units"
           ];
        self.detailsLabel.textColor = [UIColor darkTextColor];
    }
    [self.detailsLabel sizeToFit];
    //FIXME - resize the view/popover
}

- (void) updateControlState:(UITextField *)textField
{
    BOOL userHasProgressed = [self anyInputFieldHasChanged] && !self.missingReferenceFrame ;
    self.modalInPopover = userHasProgressed;
    
    BOOL inputIsComplete = self.angle && self.distance;
    BOOL canBeDone = inputIsComplete && !self.missingReferenceFrame;
    self.navigationItem.rightBarButtonItem.enabled = canBeDone;
    textField.returnKeyType = canBeDone ? UIReturnKeyDone : UIReturnKeyNext;
    //FIXME - keyboard view does not update until focus changes to new view
    //FIXME - other textfields should also be updated to UIReturnKeyDone without requiring a text changed event
}

- (BOOL) missingReferenceFrame
{
    return !self.gpsPoint || !self.deadAhead;
}

- (BOOL) anyInputFieldHasChanged
{
    NSNumber *angle = self.angle; //cached so that I do not parse the text field multiple times
    NSNumber *distance = self.distance; //cached so that I do not parse the text field multiple times
    
    //Caution: nils require special consideration
    return (!angle && self.defaultAngle) ||
           (angle && (!self.defaultAngle || ![angle isEqualToNumber:self.defaultAngle])) ||
           (!distance && self.defaultDistance) ||
           (distance && (!self.defaultDistance || ![distance isEqualToNumber:self.defaultDistance]));
}

- (BOOL) validTextField:(UITextField *)textField
{
    switch (textField.tag) {
        case 1:
            return self.angle ? YES : NO;
        case 2:
            return self.distance ? YES : NO;
        default:
            return NO;
    }
}

@end
