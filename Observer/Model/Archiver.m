//
//  Archiver.m
//  Observer
//
//  Created by Regan Sarwas on 7/10/14.
//  Copyright (c) 2014 GIS Team. All rights reserved.
//

#import "Archiver.h"
#import <ZipKit/ZipKit.h>
#import "NSURL+unique.h"

@implementation Archiver

+ (BOOL)unpackSurvey:(NSURL *)outputUrl fromArchive:(NSURL *)importUrl
{
    //Create a unique extraction folder in the parent of outputURL; find *.obssurv in extraction folder; move it to outputUrl; remove extraction folder
    ZKDataArchive *archive = [ZKDataArchive archiveWithArchivePath:importUrl.path];
    NSURL *surveyFolder = [[outputUrl URLByDeletingLastPathComponent] filePathURL];
    NSURL *extractionFolder = [[[[surveyFolder URLByAppendingPathComponent:@"temp_ext_folder"] URLByUniquingPath] URLByAppendingPathComponent:@"/"] filePathURL];
    [[NSFileManager defaultManager] createDirectoryAtURL:extractionFolder withIntermediateDirectories:YES attributes:nil error:nil];
    NSUInteger errorCode = [archive inflateInFolder:[extractionFolder path] withFolderName:nil usingResourceFork:NO];
    if (errorCode == (NSUInteger)zkSucceeded) {
        NSURL *foundSurvey = [self findSurveyInFolder:extractionFolder];
        if (foundSurvey)
        {
            return [[NSFileManager defaultManager] moveItemAtURL:foundSurvey toURL:outputUrl error:nil] &&
                   [[NSFileManager defaultManager] removeItemAtURL:extractionFolder error:nil];
        } else {
            NSLog(@"No Survey found in :%@", importUrl);
            return NO;
        }
    } else {
        NSLog(@"Error inflating zip at:%@ to %@", importUrl, outputUrl);
        return NO;
    };
}

+ (NSURL *) findSurveyInFolder:(NSURL *)folder
{
    NSArray *documents = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtURL:folder
                          includingPropertiesForKeys:nil
                          options:NSDirectoryEnumerationSkipsHiddenFiles
                          error:nil];
    if (documents) {
        for (NSURL *url in documents) {
            if ([[url.lastPathComponent pathExtension] isEqualToString:INTERNAL_SURVEY_EXT]) {
                return url;
            }
        }
    }
    return nil;
}

+ (BOOL)unpackArchive:(NSURL *)importUrl to:(NSURL *)outputUrl {
    ZKDataArchive *archive = [ZKDataArchive archiveWithArchivePath:importUrl.path];
    NSString *parentFolder = [[[outputUrl URLByDeletingLastPathComponent] filePathURL] path];
    NSString *folder = outputUrl.lastPathComponent;
    //ZKDataArchive ignores the withFolderName parameter.
    //FIXME: #176 This only worked for surveys if there is a folder in the archive that matches the name of the (uniquified) archive
    NSUInteger errorCode = [archive inflateInFolder:parentFolder withFolderName:folder usingResourceFork:NO];
    if (errorCode == (NSUInteger)zkSucceeded) {
        return YES;
    } else {
        NSLog(@"Error inflating zip at:%@ to %@", importUrl, outputUrl);
        return NO;
    };
}

+ (NSData *)exportURL:(NSURL *)url toNSDataError:(NSError * __autoreleasing *)error
{
    ZKDataArchive *archive = [ZKDataArchive new];
    [self addURL:url toArchive:archive];
    return archive.data;
}

+ (NSData *)exportURL:(NSURL *)url withCSVfromSurvey:(Survey *)survey toNSDataError:(NSError * __autoreleasing *)error
{
    ZKDataArchive *archive = [ZKDataArchive new];
    [self addURL:url toArchive:archive];
    [survey addCSVtoArchive:archive since:nil];
    return archive.data;
}

+ (void)addURL:(NSURL *)url toArchive:(ZKDataArchive *)archive
{
    if ([url isFileURL]) {
        NSString *path = url.path;
        BOOL isDir = false;
        BOOL exists = (path == nil) ? NO : [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        if (exists) {
            if (isDir) {
                [archive deflateDirectory:path relativeToPath:[path stringByDeletingLastPathComponent] usingResourceFork:NO];
            } else {
                [archive deflateFile:path relativeToPath:[path stringByDeletingLastPathComponent] usingResourceFork:NO];
            }
        }
    }
}

+ (BOOL)exportURL:(NSURL *)url toDiskWithName:(NSString *)exportPath error:(NSError * __autoreleasing *)error
{
    NSData *data = [self exportURL:url toNSDataError:error];
    return [self exportData:data toDiskWithName:exportPath error:error];
}

+ (BOOL)exportURL:(NSURL *)url withCSVfromSurvey:(Survey *)survey toDiskWithName:(NSString *)exportPath error:(NSError * __autoreleasing *)error
{
    NSData *data = [self exportURL:url withCSVfromSurvey:survey toNSDataError:error];
    return [self exportData:data toDiskWithName:exportPath error:error];
}

+ (BOOL)exportData:(NSData *)data toDiskWithName:(NSString *)exportPath error:(NSError * __autoreleasing *)error
{
    if (data == nil || exportPath == nil) return NO;
    if ([data writeToFile:exportPath atomically:YES]) {
        return YES;
    } else {
        if (error != NULL) {
            //User wants error details, lets give it to them.
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"Unable to write to filesystem." forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"observer.nps.gov" code:100 userInfo:details];
        }
        return NO;
    }
}

@end
