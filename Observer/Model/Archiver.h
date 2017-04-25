//
//  Archiver.h
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Survey.h"

@interface Archiver : NSObject

+ (BOOL)unpackSurvey:(NSURL *)outputUrl fromArchive:(NSURL *)importUrl;

// returns a zip data stream of the survey document at URL; used by the email client for the attachment
+ (NSData *)exportURL:(NSURL *)url toNSDataError:(NSError **)error;

+ (BOOL)exportURL:(NSURL *)url toDiskWithName:(NSString *)exportPath error:(NSError * __autoreleasing *)error;

+ (NSData *)exportURL:(NSURL *)url withCSVfromSurvey:(Survey *)survey toNSDataError:(NSError **)error;

+ (BOOL)exportURL:(NSURL *)url withCSVfromSurvey:(Survey *)survey toDiskWithName:(NSString *)exportPath error:(NSError * __autoreleasing *)error;

@end
