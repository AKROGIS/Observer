//
//  MapMonitoring.h
//  Observer
//
//  Created by Regan Sarwas on 2013-07-06.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Map;
@class Maps;

@protocol MapMonitoring <NSObject>

@optional

- (void)mapDidFinishLoad:(Map *)map;
- (void)map:(Map *)map didFailLoadWithError:(NSError *)error;

- (void)mapDidFinishDownload:(Map *)map;
- (void)map:(Map *)map didFailDownloadWithError:(NSError *)error;

- (void)mapsDidFinishServerRequest:(Maps *)maps;
- (void)mapsDidFinishAllServerRequests:(Maps *)maps;
- (void)maps:(Maps *)maps didFailServerRequestWithError:(NSError *)error;

@end
