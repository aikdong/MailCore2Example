//
//  DelayedAttachment.m
//  ThatInbox
//
//  Created by Liyan David Chang on 8/1/13.
//  Copyright (c) 2013 Ink. All rights reserved.
//

#import "DelayedAttachment.h"
#import "MailInfo.h"
#import "UTIFunctions.h"
#import <MBProgressHUD.h>

@interface DelayedAttachment ()

@end


@implementation DelayedAttachment

- (id) initWithAbstractPart:(MCOAbstractPart *)part {
    
    if( (self = [super init]) ) {
        _filename = part.filename;
        _mimeType = part.mimeType;
        _uniqueID = part.uniqueID;
    }
    return self;
}

-(id)initWithFileName:(NSURL *)fileURL{
    if( (self = [super init]) ) {
        _filename = [fileURL lastPathComponent];
        _mimeType = [UTIFunctions mimetypeFromUTI:[UTIFunctions UTIFromFilename:_filename]];
        _uniqueID = [fileURL path];
        _attachmentObject = [fileURL path];
    }
    return self;
}

- (id) attachmentObject {
    if (_attachmentObject){
        return _attachmentObject;
    } else {
        _attachmentObject = self.fetchAttachment(_uniqueID,_filename,_progress,_progressCompletion);
        if (_attachmentObject) {
            [[AttachmentsFolder sharedInstance] refresh];
        }
        return _attachmentObject;
    }
}

-(void)progressShowIn:(UIView *)view{
    if (!view || _attachmentObject) {
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:NO];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.opacity = 0.4;
    
    [self setProgress:^(NSInteger percent) {
        dispatch_async(dispatch_get_main_queue(), ^{
            hud.progress = (1.0*percent)/100;
        });
    }];
    [self setProgressCompletion:^() {
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud setProgress:1.0];
            [hud hide:YES];
        });
    }];
}

@end
