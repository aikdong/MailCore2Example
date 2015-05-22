//
//  MCTMsgViewController.h
//  testUI
//
//  Created by DINH Viêt Hoà on 1/20/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#include <MailCore/MailCore.h>
#import "HeaderView.h"
#import "HUD.h"
#import "MailInfo.h"
#import "MCOMessageView.h"
#import "MCOAbstractMessage+TBMail.h"

@class MCOMessageView;
@class MCOIMAPAsyncSession;
@class MCOMAPMessage;

@interface MCTMsgViewController : UIViewController <MCOMessageViewDelegate, HeaderViewDelegate> {
    MCOMessageView * _messageView;
    HeaderView *_headerView;
    
    NSMutableSet * _pending;
    NSMutableArray * _ops;
    NSMutableDictionary * _callbacks;
    NSObject *_session;
}

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) MailFolderInfo *folder;
@property (nonatomic, strong) MCOAbstractMessage * message;

- (NSString *) msgContent;

- (NSMutableArray *)delayedAttachments;

@end
