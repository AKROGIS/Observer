//
//  NSString+csvEscape.m
//  Observer
//
//  Created by Regan Sarwas on 2016-06-11.
//  Copyright © 2016 GIS Team. All rights reserved.
//

#import "NSString+csvEscape.h"

@implementation NSString (csvEscape)

- (NSString *)csvEscape
{
    NSString *results = [self stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
    results = [NSString stringWithFormat:@"\"%@\"", results];
    return results;
}

@end
