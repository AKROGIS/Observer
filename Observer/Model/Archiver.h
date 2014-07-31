//
//  Archiver.h
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Archiver : NSObject

+ (BOOL)unpackArchive:(NSURL *)importUrl to:(NSURL *)outputUrl;

// returns a zip data stream of the survey document at URL; used by the email client for the attachment
+ (NSData *)exportURL:(NSURL *)url toNSDataError:(NSError **)error;

+ (BOOL)exportURL:(NSURL *)url toDiskWithName:(NSString *)exportPath error:(NSError * __autoreleasing *)error;

@end
