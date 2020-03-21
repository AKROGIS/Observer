//
//  AttributeViewController.m
//  Observer
//
//  Created by Regan Sarwas on 12/16/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "AttributeViewController.h"
#import "QuickDialog.h"
#import "POGraphic.h"

@interface AttributeViewController ()

@end

@implementation AttributeViewController

- (void) addDeleteButtonForSurvey:(Survey *)survey
{
    NSString *buttonText = @"Delete";
    QButtonElement *deleteButton = [[QButtonElement alloc] initWithTitle:buttonText];
    deleteButton.appearance = [[QFlatAppearance alloc] init];
    deleteButton.appearance.buttonAlignment = NSTextAlignmentCenter;
    deleteButton.appearance.actionColorEnabled = [UIColor redColor];
    deleteButton.onSelected = ^(){
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Feature?"
                                                                       message:@"This cannot be undone."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            if ([self.graphic isKindOfClass:[POGraphic class]]) {
                [(POGraphic *)self.graphic remove];
            } else {
                [self.graphic.graphicsOverlay.graphics removeObject:self.graphic];
            }
            [survey deleteEntity:self.managedObject];
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
        [alert addAction:deleteAction];
        [self presentViewController:alert animated:YES completion:nil];
    };
    if (survey.protocol.cancelOnTop) {
        [self.root.sections.firstObject insertElement:deleteButton atIndex:0];
    } else {
        [self.root.sections.lastObject addElement:deleteButton];
    }
}

@end
