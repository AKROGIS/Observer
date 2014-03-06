//
//  ProtocolTableViewCell.m
//  Observer
//
//  Created by Regan Sarwas on 11/21/13.
//  Copyright (c) 2013 GIS Team. All rights reserved.
//

#import "ProtocolTableViewCell.h"
#import "AKRDownloadView.h"

@interface ProtocolTableViewCell ()
@property (weak, nonatomic) IBOutlet AKRDownloadView *downloadProgressView;
@property (weak, nonatomic) IBOutlet UIImageView *startDownloadImageView;
@end

@implementation ProtocolTableViewCell

- (void)setPercentComplete:(float)percentComplete
{
    self.downloadProgressView.percentComplete = percentComplete;
}

- (void)setDownloading:(BOOL)downloading
{
    if (downloading != _downloading) {
        _downloading = downloading;
        self.downloadProgressView.hidden = !downloading;
        self.startDownloadImageView.hidden = downloading;
        self.downloadProgressView.downloading = downloading;
    }
}

@end
