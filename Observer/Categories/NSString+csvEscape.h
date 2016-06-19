//
//  NSString+csvEscape.h
//  Observer
//
//  Created by Regan Sarwas on 2016-06-11.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (csvEscape)

// returns a new string based on self that is escaped for export in a CSV file
// 1) converts quotes (") to ("")
// 2) surrounds string with quotes (")
- (NSString *)csvEscape;

@end
