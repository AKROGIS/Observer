//
//  Map.m
//  Observer
//
//  Created by Regan Sarwas on 7/5/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "Map.h"

@implementation Map

#pragma mark - initializer

- (id) initWithLocalURL:(NSURL *)localURL andServerURL:(NSURL *)serverUrl
{
    self = [super init];
    if (self) {
        if (!localURL && !serverUrl)
            return nil;
        self.localURL = localURL;
        self.serverURL = serverUrl;
    }
    return self;
}

- (id) initWithLocalURL:(NSURL *)localURL
{
    return [self initWithLocalURL:localURL andServerURL:nil];
}

- (id) initWithServerURL:(NSURL *)serverUrl
{
    return [self initWithLocalURL:nil andServerURL:serverUrl];
}

- (id) init
{
    return [self initWithLocalURL:nil andServerURL:nil];
}


#pragma mark public properties


#pragma mark public instance methods

- (void) download {
#warning incomplete implementation
}

- (void) unload {
#warning incomplete implementation
}


#pragma mark public class methods

+ (Map *) randomMap {
    int i = 1 + rand() % 999;
    NSURL *serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://myserver/mymaps/map%u.tpk", i]];
    Map *map = [[Map alloc] initWithServerURL:serverURL];
    if (map) {
        map.name = [NSString stringWithFormat:@"Map # %u", i];
        map.summary = [serverURL description];
    }
    return map;
}

#pragma mark private methods



@end
