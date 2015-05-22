//
//  MailBoxInfo.h
//  CECiTurbo
//
//  Created by DongXing on 3/26/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "JSONModel.h"
#import "InfoSummary.h"
#import "MCOAbstractMessage+TBMail.h"
#import "ApplicationDirector.h"

/** It's the account type.*/
typedef NS_ENUM (NSInteger, TBMailServerType) {
    TBMailServerTypeIMAP,
    TBMailServerTypePOP,
    TBMailServerTypeiTurbo
};

@protocol MailFolderInfo;
@class MailFolderInfo;

@protocol MailAccountInfo;
@interface MailAccountInfo : JSONModel <InfoSummary>
@property (nonatomic, assign) TBMailServerType serverType;
@property (nonatomic, strong, readonly) NSString<Index,Optional>* identifier;
@property (nonatomic, strong) NSString<Optional>* address;
@property (nonatomic, strong) NSString<Optional>* username;
@property (nonatomic, strong) NSString<Optional>* password;
@property (nonatomic, strong) NSString<Optional>* title;
@property (nonatomic, strong) NSString<Optional>* hostname;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, strong) NSString<Optional>* smtpHostname;
@property (nonatomic, assign) NSInteger smtpPort;
@property (nonatomic, assign) MCOConnectionType connectionType;
@property (nonatomic, strong) NSObject<Ignore>* session;
@property (nonatomic, strong) MCOSMTPSession<Ignore>* smtpSession;
@property (strong, nonatomic) NSMutableArray<Ignore,MailFolderInfo>* folders;
@property (nonatomic, strong) MailFolderInfo<Ignore>* trashFolder;

-(BOOL) complete;
@end

@interface MailFolderInfo : JSONModel <InfoSummary>
@property (nonatomic, strong, readonly) NSString<Index,Optional>* identifier;
@property (nonatomic, strong) NSString* path;
@property (nonatomic, strong) NSString<Optional>* title;
@property (nonatomic, assign) MCOIMAPFolderFlag flags;
@property (nonatomic, assign) char delimiter;
@property (nonatomic, assign) NSInteger order;
@property (nonatomic, assign) NSInteger indentationLevel;
@property (nonatomic, strong) MCOIMAPFolderInfo<Ignore>* info;
@property (nonatomic, strong) MCOIMAPFolderStatus<Ignore>* status;
@property (nonatomic, strong) NSMutableArray<Ignore>* messages;
@property (strong, nonatomic) MailAccountInfo<Ignore>*ownerAccount;

-(BOOL) invalid;
-(BOOL) isTrash;
-(BOOL) isArchive;
-(void) saveMessages;

@end

@interface SmartFolder : JSONModel <InfoSummary>
{
    NSMutableArray *messageCollection;
}
- (instancetype) initWithFolder:(MailFolderInfo*)folder;

-(NSIndexSet*)insertMessages:(NSArray *)messages inFolder:(MailFolderInfo*)folder;
-(NSIndexSet*)updateMessages:(NSArray *)messages;
-(NSIndexSet*)removeMessages:(NSArray *)messages;
- (MailFolderInfo*) ownerFolder:(MCOAbstractMessage*)message;
- (MCOAbstractMessage*) messageAtIndex:(NSUInteger)index;
- (NSUInteger) indexOfMessage:(MCOAbstractMessage*) message;
- (NSUInteger) countOfMessages;

- (void)saveMessages;

@property (nonatomic, strong) NSString<Optional>* title;
@property (nonatomic, strong) NSArray<Optional,MailFolderInfo>* folders;

@end

@interface AttachmentsFolder : NSObject <InfoSummary>

+ (AttachmentsFolder*)sharedInstance;

- (void) refresh;

-(void)removeAttachmentCollectionAtIndexes:(NSIndexSet *)indexes;

@property (nonatomic, strong) NSArray* attachmentCollection;

@end
