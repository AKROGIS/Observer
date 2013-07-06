//
//  Map.h
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Map : NSObject

//designated initializer
- (id) initWithLocalURL:(NSURL *)localURL andServerURL:(NSURL *)serverUrl;

- (id) initWithLocalURL:(NSURL *)localURL;
- (id) initWithServerURL:(NSURL *)serverUrl;
- (id) init; // don't call this - it overrides super init to prevent malformed objects

@property (strong, nonatomic) NSURL *localURL;
@property (strong, nonatomic) NSURL *serverURL;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *summary;

- (void) download;
- (void) unload;

+ (Map *) randomMap; //for testing purposes

@end
