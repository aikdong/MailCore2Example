//
//  MessageCell.m
//  ThatInbox
//
//  Created by Andrey Yastrebov on 20.09.13.
//  Copyright (c) 2013 com.inkmobility. All rights reserved.
//

#import "MessageCell.h"
#import "NSDate+DateTools.h"
#import "UIImage+Custom.h"
#import "MCOPOPMessage.h"
#import <MailCore/MailCore.h>


@implementation MessageCell
static NSString *plainTextBodyRendering = @"plainTextBodyRendering";


- (void)setMessage:(MCOAbstractMessage *)message
{
    MCOMessageHeader *header = message.header;
    
//    NSLog(@"%@ ,%@, %@",header.messageID,header.date,[header extraHeaderValueForName:KeyCachedPreview]);
    
    if (self.folder.flags&MCOIMAPFolderFlagSentMail){
        NSMutableString * result = [[NSMutableString alloc] init];
        [header.to enumerateObjectsUsingBlock:^(MCOAddress * to, NSUInteger idx, BOOL *stop) {
            if (idx > 0)
                [result appendString:@";"];
            
            if (to.displayName)
                [result appendString:[to displayName]];
            else
                [result appendString:[to mailbox]];
        }];
        self.addressTextField.text = result;
    }else{
        self.addressTextField.text = header.from.displayName?:header.from.mailbox;
    }
    
    self.subjectTextField.text = header.subject ? header.subject : @"No Subject";
    self.dateTimeField.text = [header.date showsTimeSinceNowWithDateStyle:NSDateFormatterShortStyle andTimeStyle:NSDateFormatterShortStyle];

    if ([ApplicationDirector isIOS8OrHigher]) {
        self.detailTextField.numberOfLines = 2;
    }
    
    //attachments
    NSArray *attachments = [message attachments];
    if ([attachments count] > 0)
    {
        [self.attachementIcon setHidden:NO];
        MCOAttachment *firstAttachment = [message.attachments firstObject];
        
        if (attachments.count == 1)
        {
            self.detailTextField.text = firstAttachment.filename;
        }
        else
        {
            self.detailTextField.text = [NSString stringWithFormat:@"%@ + %d more", firstAttachment.filename, (int)attachments.count - 1];
        }
    }
    else
    {
        [self.attachementIcon setHidden:YES];
        self.detailTextField.text = @" ";
    }
    
    // Preview
    if ([message isMemberOfClass:[MCOIMAPMessage class]]) {
//        MCOIMAPMessage *msg = (MCOIMAPMessage*)message;
        
        NSString *cachedPreview = [header extraHeaderValueForName:plainTextBodyRendering];
        if (cachedPreview){
            self.detailTextField.text = cachedPreview;
        }else{
            self.messageRenderingOperation = [(MCOIMAPSession *)self.folder.ownerAccount.session plainTextBodyRenderingOperationWithMessage:(MCOIMAPMessage*)message folder:self.folder.path stripWhitespace:YES];
            [self.messageRenderingOperation start:^(NSString * plainTextBodyString, NSError * error) {
                if (!error) {
                    [header setExtraHeaderValue:plainTextBodyString forName:plainTextBodyRendering];
                    if (self) {
                        self.messageRenderingOperation = nil;
                        self.detailTextField.text = plainTextBodyString;
                    }
                }else if (error){
                    NSLog(@"%@",error);
                }
            }];
        }
    }else if([message isMemberOfClass:[MCOPOPMessage class]]){
        MCOPOPMessage *msg = (MCOPOPMessage*)message;
        if (msg.fetched) {
            self.detailTextField.text = [msg plainTextBodyRendering];
        }else if (msg.index){
            MCOPOPFetchMessageOperation *op = [(MCOPOPSession *)self.folder.ownerAccount.session fetchMessageOperationWithIndex:msg.index];
            [op start:^(NSError *error, NSData *messageData) {
                if (!error) {
                    msg.fetched = YES;
                    [msg messageData:messageData];
                    self.detailTextField.text = [msg plainTextBodyRendering];
                }else{
                    [[(MCOPOPSession *)self.folder.ownerAccount.session disconnectOperation] start:nil];
                }
            }];
        }
        
    }
    
    // Flags
    [self renderFlags:[message TBFlags]];
}

-(void)renderFlags:(MCOMessageFlag)flag{
    
    
    [self.flagIcon setHidden:YES];
    [self.unseenIcon setHidden:YES];
    [self.forwardAnswered setHidden:YES];
    
    if (flag&MCOMessageFlagAnswered||flag&MCOMessageFlagForwarded) {
        [self.forwardAnswered setHidden:NO];
    }
    if (flag&MCOMessageFlagSeen) {
        if (flag&MCOMessageFlagFlagged) {
            [self.flagIcon setHidden:NO];
        }
    }else{
        static UIImage *unseenImage;
        if (!unseenImage) {
            unseenImage = [UIImage imageWithColor:self.tintColor withSize:CGSizeMake(8, 8)];
        }
        self.unseenIcon.layer.masksToBounds = YES;
        self.unseenIcon.layer.cornerRadius = 4;
        self.unseenIcon.image = unseenImage;
        [self.unseenIcon setHidden:NO];
    }
}

- (void)prepareForReuse
{
    [self.messageRenderingOperation cancel];
}

-(void)dealloc{
    self.messageRenderingOperation = nil;
}
@end
