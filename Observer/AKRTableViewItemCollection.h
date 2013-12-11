//
//  AKRTableViewObjectCollection.h
//  Observer
//
//  Created by Regan Sarwas on 11/14/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FSTableViewItem <NSObject>
- (NSString *) title;
- (NSString *) subtitle;
- (UIImage *) thumbnail;
@optional
- (void) setTitle:(NSString *)title;
- (NSString *) subtitle2;
@end

//@protocol FSTableViewItemCollection <NSObject>
//@property (nonatomic, strong) NSIndexPath * selectedIndex;
//- (id<FSTableViewItem>) itemAtIndexPath:(NSIndexPath *)indexPath;
//- (id<FSTableViewItem>) selectedItem;
//- (int) itemCount;
//- (NSIndexPath *) addNewItem;
//- (void) moveItemAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath;
//- (void) removeItemAtIndexPath:(NSIndexPath *)indexPath;
//- (void) refreshWithCompletionHandler:(void (^)(BOOL success))completionHandler;
//@end

