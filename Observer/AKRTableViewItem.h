//
//  AKRTableViewItem.h
//  Observer
//
//  Created by Regan Sarwas on 11/14/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol AKRTableViewItem <NSObject>
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *subtitle;
@property (nonatomic, readonly, strong) UIImage *thumbnail;
@optional
@property (nonatomic, readonly, copy) NSString *subtitle2;
@end
