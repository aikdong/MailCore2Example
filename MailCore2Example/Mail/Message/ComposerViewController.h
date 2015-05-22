//
//  ComposerViewController.h
//  ThatInbox
//
//  Created by Liyan David Chang on 7/31/13.
//  Copyright (c) 2013 Ink. All rights reserved.
//

#import "StaticDataTableViewController.h"
#import <MailCore/MailCore.h>
#import <MobileCoreServices/MobileCoreServices.h>


@protocol ComposerSentDelegate <NSObject>

@optional
-(void)composerSent:(MCOAbstractMessage*)msg;

@end

@interface ComposerViewController : StaticDataTableViewController <UITextViewDelegate, UITextFieldDelegate>

@property (nonatomic,weak) id<ComposerSentDelegate> delegate;

@property(nonatomic, weak) IBOutlet UITextField *toField;
@property(nonatomic, weak) IBOutlet UITextField *ccField;
@property(nonatomic, weak) IBOutlet UITextField *subjectField;
@property(nonatomic, weak) IBOutlet UITextView *messageBox;

@property(nonatomic, strong) NSMutableArray *delayedAttachmentsArray;
@property(nonatomic, strong) MCOSMTPSession *smtpSession;

- (void)loadWithMessage:(MCOAbstractMessage *)msg
               ofType:(NSString*)type
              content:(NSString*)content
   delayedAttachments:(NSArray *)delayedAttachments;

- (void)loadWithTo:(NSArray *)to
              CC:(NSArray *)cc
             BCC:(NSArray *)bcc
         subject:(NSString *)subject
         message:(NSString *)message
delayedAttachments:(NSArray *)delayedAttachments;


@end
