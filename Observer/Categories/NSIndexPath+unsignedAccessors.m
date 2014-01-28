//
//  NSIndexPath+unsignedAccessors.m
//  Observer
//
//  Created by Regan Sarwas on 1/28/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "NSIndexPath+unsignedAccessors.h"

@implementation NSIndexPath (unsignedAccessors)

// row/section of IndexPath will never be negative (I skip the assert to save cycles)
// see: http://stackoverflow.com/questions/13585220/why-is-the-row-property-of-nsindexpath-a-signed-integer

- (NSUInteger)urow
{
    return (NSUInteger)self.row;
}

- (NSUInteger)usection
{
    return (NSUInteger)self.section;
}

@end
