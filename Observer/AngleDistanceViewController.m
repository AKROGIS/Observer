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

@property (nonatomic, readwrite) BOOL isCanceled;

@end

@implementation AngleDistanceViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initDefaults];
    [self initRegexPredicates];
    [self hideControls];
}

- (void) viewWillAppear:(BOOL)animated
{
    [self settingsDidChange:nil];
    self.contentSizeForViewInPopover = CGSizeMake(320,250.0);
    self.navigationController.contentSizeForViewInPopover = self.contentSizeForViewInPopover;
    [super viewWillAppear:animated];
}

- (void) viewDidAppear:(BOOL)animated {
    NSLog(@"View Did Appear");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];
    [super viewDidAppear:animated];
    [self.popover setPopoverContentSize:self.contentSizeForViewInPopover animated:YES];
}

- (void) viewDidDisappear:(BOOL)animated
{
    NSLog(@"View Did Disappear");
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

- (void) textFieldDidEndEditing:(UITextField *)textField
{
    NSNumberFormatter *parser = [[NSNumberFormatter alloc] init];
    [parser setNumberStyle:NSNumberFormatterDecimalStyle];
    [parser setLocale:[NSLocale currentLocale]];
    NSNumber *number = [parser numberFromString:textField.text];
    if (textField == self.angleTextField) {
        [Settings manager].angleDistanceLastAngle = number;
        self.distanceTextField.returnKeyType = number ? UIReturnKeyDone : UIReturnKeyNext;
    }
    if (textField == self.distanceTextField) {
        [Settings manager].angleDistanceLastDistance = number;
        self.distanceTextField.returnKeyType = number ? UIReturnKeyDone : UIReturnKeyNext;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField.returnKeyType == UIReturnKeyNext) {
        if (textField == self.angleTextField) {
            [self.distanceTextField becomeFirstResponder];
        }
        if (textField == self.distanceTextField) {
            [self.angleTextField becomeFirstResponder];
        }
        return NO;
    }
    if (textField.returnKeyType == UIReturnKeyDone) {
        [textField resignFirstResponder];
        return NO;
    }
    return YES;
}


#pragma mark - Public Properties

- (void) setCourse:(double)course
{
    if (_course == course)
        return;
    _course = course;
    [self hideControls];
}

- (void) setProtocol:(SurveyProtocol *)protocol
{
    _protocol = protocol;
    [self settingsDidChange:nil];
    [self hideControls];
}

- (double) angle
{
    NSNumberFormatter *parser = [[NSNumberFormatter alloc] init];
    [parser setNumberStyle:NSNumberFormatterDecimalStyle];
    [parser setLocale:[NSLocale currentLocale]];
    NSNumber *number = [parser numberFromString:self.angleTextField.text];
    return [number doubleValue];
}

- (double) distance
{
    NSNumberFormatter *parser = [[NSNumberFormatter alloc] init];
    [parser setNumberStyle:NSNumberFormatterDecimalStyle];
    [parser setLocale:[NSLocale currentLocale]];
    NSNumber *number = [parser numberFromString:self.distanceTextField.text];
    return [number doubleValue];
}

- (AGSPoint *)observationPoint
{
    if (!self.gpsPoint || !self.distanceTextField.text.length || !self.angleTextField.text.length)
        return nil;
    if ([self.angleTextField.text isEqualToString:@"-"])
        return nil;
    
    double course = self.course < 0 ? 0 : self.course;
    double direction = self.angleDirection == AngleDirectionClockwise ? 1.0 : -1.0;
    double angle  = course + direction * (self.angle - self.referenceAngle);
    return [self.gpsPoint pointWithAngle:angle distance:self.distance units:self.distanceUnits];   
}


#pragma mark - Private Methods

- (void) initDefaults
{
    self.course = -1;
    NSNumber *angle = [Settings manager].angleDistanceLastAngle;
    self.angleTextField.text = angle ? [NSString stringWithFormat:@"%@", angle] : nil;
    NSNumber *distance = [Settings manager].angleDistanceLastDistance;
    self.distanceTextField.text = distance ? [NSString stringWithFormat:@"%@", distance] : nil;
}

- (void) initRegexPredicates
{
    self.angleRegex =[NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^-?\\d+$"];
    self.distanceRegex =[NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^\\d*$"];
}

- (void) hideControls
{
    self.basisButton.hidden = (self.protocol && self.protocol.definesAngleDistanceMeasures);
}

- (void) settingsDidChange:(NSNotification *)notification
{
    if (self.protocol && self.protocol.definesAngleDistanceMeasures)
    {
        self.distanceUnits = self.protocol.distanceUnits;
        self.referenceAngle = self.protocol.angleBaseline;
        self.angleDirection = self.protocol.angleDirection;
    }
    else
    {
        self.distanceUnits = [Settings manager].distanceUnitsForSightings;
        self.referenceAngle = [Settings manager].angleDistanceDeadAhead;
        self.angleDirection = [Settings manager].angleDistanceAngleDirection;
    }
    [self updateLabel];
}

- (void) updateLabel
{
    NSString *part1 = [NSString stringWithFormat:@"Angle increases %@ with %@ equal to %u degrees",
                       self.angleDirection == 0 ? @"clockwise" : @"counter-clockwise",
                       self.course < 0 ? @"true north" : @"dead ahead",
                       (int)self.referenceAngle
                       ];
    
    NSString *part2 = [NSString stringWithFormat:@"Distance is in %@.",
                       self.distanceUnits == AGSSRUnitMeter ? @"meters" :
                       self.distanceUnits == AGSSRUnitFoot ? @"feet" :
                       self.distanceUnits == AGSSRUnitInternationalYard ? @"yards" : @"unknown units"
                       ];
    
    if (self.course < 0) {
        NSString *text = [NSString stringWithFormat:@"%@ (heading is unavailable). %@", part1, part2];
        NSRange range = NSMakeRange(part1.length + 2, 22);
        NSDictionary *attribs = @{
                                  NSForegroundColorAttributeName: self.detailsLabel.textColor,
                                  NSFontAttributeName: self.detailsLabel.font
                                  };
        NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:text attributes:attribs];
        [attributedText setAttributes:@{NSForegroundColorAttributeName:[UIColor redColor]} range:range];
        self.detailsLabel.attributedText = attributedText;
    }
    else {
        self.detailsLabel.text = [NSString stringWithFormat:@"%@. %@", part1, part2];
    }
    [self.detailsLabel sizeToFit];
}

@end
