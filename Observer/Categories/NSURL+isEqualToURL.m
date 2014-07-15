//
//  NSURL+isEqualToURL.m
//  Observer
//
//  Created by Regan Sarwas on 7/11/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "NSURL+isEqualToURL.h"

@implementation NSURL (isEqualToURL)

- (BOOL)isEqualToURL:(NSURL *)other {
    //Comparing URLs is tricky, I am trying to be efficient, and permissive
    if (other == nil) {
        return NO;
    }
    return [self isEqual:other] ||  //reference equality
    [self.absoluteURL isEqual:other.absoluteURL] ||
    [self.fileReferenceURL isEqual:other.fileReferenceURL];
}

@end
