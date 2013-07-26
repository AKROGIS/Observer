//
//  AngleDistanceViewController.m
//  Observer
//
//  Created by Regan Sarwas on 7/25/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AngleDistanceViewController.h"
#import "AGSPoint+AKRAdditions.h"

@interface AngleDistanceViewController ()

@property (weak, nonatomic) IBOutlet UILabel *warningLabel;

@end

@implementation AngleDistanceViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self getDefaults];
}


/*
 - (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self setContentSizeForViewInPopover:CGSizeMake(320, 500)];
}
*/
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Delegate Methods: UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    switch (pickerView.tag) {
        case 1:
            switch (component) {
                case 0:
                    return row == 0 ? @"+" : @"-";
                case 4:
                    return row == 0 ? @"CW" : @"CCW";
                default:
                    return [NSString stringWithFormat:@"%u",row];
            }
            break;
        case 2:
            switch (component) {
                case 3:
                    switch (row) {
                        case 0:
                            return @"Feet";
                        case 1:
                            return @"Yards";
                        case 2:
                            return @"Meters";
                        default:
                            return nil;
                    };
                default:
                    return [NSString stringWithFormat:@"%u",row];
            }
        default:
            return nil;
    }
    
}


#pragma mark - Delegate Methods: UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    //tag 1 = angle picker, tag 2 = distance picker
    switch (pickerView.tag) {
        case 1:
            return 5;
        case 2:
            return 4;
        default:
            return 0;
    }
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    switch (pickerView.tag) {
        case 1:
            switch (component) {
                case 0:
                    return 2;
                case 1:
                    return 4;
                case 2:
                    return 10;
                case 3:
                    return 10;
                case 4:
                    return 2;
                default:
                    return 0;
            }
            break;
        case 2:
            switch (component) {
                case 0:
                    return 10;
                case 1:
                    return 10;
                case 2:
                    return 10;
                case 3:
                    return 3;
                default:
                    return 0;
            }
        default:
            return 0;
    }
}

#pragma mark - Public Properties

- (void) setCourse:(double)course
{
    if (_course == course)
        return;
    if (course < 0)
    {
        self.warningLabel.hidden = NO;
        _course = 0; //Use North as baseline
    }
    else
    {
        self.warningLabel.hidden = YES;
        _course = course;
    }
}

- (AGSPoint *)observationPoint
{
    double angle  = self.course + self.angle - self.referenceAngle;
    return [self.gpsPoint pointWithAngle:angle distance:self.distance units:self.distanceUnits];   
}


#pragma mark - Private Methods

- (void) getDefaults
{
    //FIXME
    self.angle = 225.0;
    self.referenceAngle = 180.0;
    self.distance = 20;
    self.distanceUnits = AGSSRUnitMeter;
}


@end
