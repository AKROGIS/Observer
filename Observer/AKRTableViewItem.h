//
//  AKRTableViewItem.h
//  Observer
//
//  Created by Regan Sarwas on 11/14/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AKRTableViewItem <NSObject>
- (NSString *) title;
- (NSString *) subtitle;
- (UIImage *) thumbnail;
@optional
- (void) setTitle:(NSString *)title;
- (NSString *) subtitle2;
@end
