//
//  DelayedAttachment.h
//  ThatInbox
//
//  Created by Liyan David Chang on 8/1/13.
//  Copyright (c) 2013 Ink. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MailCore/MailCore.h>

typedef void (^DelayedAttachmentProgressBlock)(NSInteger percent);
typedef void (^DelayedAttachmentProgressCompletionBlock)();

@interface DelayedAttachment : NSObject


- (id) initWithAbstractPart:(MCOAbstractPart *)part;
- (id) initWithFileName:(NSURL *)fileURL;

@property (nonatomic, copy) NSString * filename;
@property (nonatomic, copy) NSString * mimeType;
@property (nonatomic, copy) NSString * uniqueID;
@property (nonatomic, strong) id (^fetchAttachment)(NSString *uniqueID,NSString *filename,DelayedAttachmentProgressBlock progress,DelayedAttachmentProgressCompletionBlock progressCompletion);

@property (nonatomic, strong) DelayedAttachmentProgressBlock progress;
@property (nonatomic, strong) DelayedAttachmentProgressCompletionBlock progressCompletion;

@property (nonatomic, strong) id attachmentObject;

-(void) progressShowIn:(UIView*)view;

@end
