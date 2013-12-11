//
//  AKRDownloadView.h
//  Observer
//
//  Created by Regan Sarwas on 11/26/13.
//  Copyright (c) 2013 Regan Sarwas. All rights reserved.
//

//intended for a 30x30 view size

#import <UIKit/UIKit.h>

@interface AKRDownloadView : UIView

@property (nonatomic) float percentComplete;
@property (nonatomic) BOOL downloading;

@end
