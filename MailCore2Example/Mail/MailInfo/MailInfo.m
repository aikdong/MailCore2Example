//
//  MailBoxInfo.m
//  CECiTurbo
//
//  Created by DongXing on 3/26/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "MailInfo.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation MailAccountInfo

-(NSArray<Ignore,MailFolderInfo> *)folders{
    if (_folders) return _folders;
    
    NSError *error;
    if (_serverType == TBMailServerTypePOP){
        _folders = (NSMutableArray<Ignore,MailFolderInfo>*)[MailFolderInfo arrayOfModelsFromJsonString:@"[{\"title\": \"Inbox\",\"path\": \"INBOX\",\"flags\": 16},{\"title\": \"Sent\",\"path\": \"Sent Messages\",\"flags\": 32},{\"title\": \"Deleted\",\"path\": \"Deleted Messages\",\"flags\": 256}]" withKeyMapper:NO error:&error];
        
        for (MailFolderInfo *folder in _folders) {
            folder.ownerAccount = self;
        }
    }else if (_serverType == TBMailServerTypeiTurbo){
        _folders = (NSMutableArray<Ignore,MailFolderInfo>*)[MailFolderInfo arrayOfModelsFromJsonString:@"[{\"title\": \"Inbox\",\"path\": \"INBOX\",\"flags\": 16},{\"title\": \"Sent\",\"path\": \"Sent Messages\",\"flags\": 32},{\"title\": \"Archive\",\"path\": \"Archive\",\"flags\": 4096}]" withKeyMapper:NO error:&error];
        
        for (MailFolderInfo *folder in _folders) {
            folder.ownerAccount = self;
        }
    }else{
        _folders = (NSMutableArray<Ignore,MailFolderInfo>*)[NSMutableArray arrayWithArray:(NSArray*)[[ApplicationDirector sharedInstance].mailCacheFolders objectForKey:self.identifier]];
        
        if (!_folders.count) {
            [_folders addObjectsFromArray:[MailFolderInfo arrayOfModelsFromJsonString:@"[{\"title\": \"Inbox\",\"path\": \"INBOX\",\"flags\": 16},{\"title\": \"Sent\",\"path\": \"Sent Messages\",\"flags\": 32}]" withKeyMapper:NO error:&error]];
        }
        
        for (MailFolderInfo *folder in _folders) {
            folder.ownerAccount = self;
        }
    }
    
    if (error) NSLog(@"%@",error);
    
    return _folders;
}

-(MailFolderInfo *)trashFolder{
    if (_trashFolder) {
        return _trashFolder;
    }
    
    for (MailFolderInfo *folder in _folders) {
        if ([folder isTrash]) {
            _trashFolder = folder;
            break;
        }
    }
    
    if (!_trashFolder) {
        for (MailFolderInfo *folder in _folders) {
            if ([folder isArchive]) {
                _trashFolder = folder;
                break;
            }
        }
    }
    return _trashFolder;
}

-(NSString<Optional> *)smtpHostname{
    if (_smtpHostname.length)
        return _smtpHostname;
    
    if ([_hostname hasPrefix:@"mail"]) {
        _smtpHostname = _hostname;
    }else if ([_hostname hasPrefix:@"imap"]){
        _smtpHostname = [_hostname stringByReplacingOccurrencesOfString:@"imap" withString:@"smtp"];
    }else if ([_hostname hasPrefix:@"pop"]){
        _smtpHostname = [_hostname stringByReplacingOccurrencesOfString:@"pop" withString:@"smtp"];
    }else
    {
        _smtpHostname = nil;
    }
    return _smtpHostname;
}

-(NSString<Index,Optional> *)identifier{
    return [NSString stringWithFormat:@"@%@@%ld@%ld",_address,_port,_serverType];
}

-(BOOL) complete{
    if (_serverType == TBMailServerTypeIMAP || _serverType == TBMailServerTypePOP) {
        if (_hostname.length==0 || _port == 0 || _address.length==0 || _password.length==0) {
            return NO;
        }
    }else{
        if (_address.length==0) {
            return NO;
        }
    }
    
    return YES;
}

-(MCOSMTPSession<Ignore> *)smtpSession{
    if (_smtpSession)
        return _smtpSession;
    
    if (_serverType == TBMailServerTypeIMAP || _serverType == TBMailServerTypePOP) {
        MCOSMTPSession *session = [[MCOSMTPSession alloc] init];
        [session setHostname:self.smtpHostname];
        [session setUsername:_address];
        [session setPassword:_password];
        [session setConnectionType:_connectionType];
        if (_smtpPort == 0) {
            if (session.connectionType == MCOConnectionTypeStartTLS) {
                [session setPort:587];
            }else if (session.connectionType == MCOConnectionTypeTLS) {
                [session setPort:465];
            }else{
                [session setPort:25];
            }
        }else{
            [session setPort:(int)_smtpPort];
        }
        [session setAuthType:MCOAuthTypeSASLNone];
        [session setTimeout:30];
        [session setUseHeloIPEnabled:YES];
        [session setConnectionLogger:^(void * connectionID, MCOConnectionLogType type, NSData * data) {
            if (data) {
                NSLog(@"SMTP: %ld %@",type, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }
            
            if ((type == MCOConnectionLogTypeErrorParse) || (type == MCOConnectionLogTypeErrorReceived) || (type == MCOConnectionLogTypeErrorSent)) {
                NSLog(@"SMTP ERROR: %ld %@",type, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }
        }];
        _smtpSession = session;
    }else{
        _smtpSession = nil;
    }
    
    return _smtpSession;
}

-(NSObject<Ignore>*)session{
    
    if (_session)
        return _session;
    
    if (_serverType == TBMailServerTypeIMAP) {
        MCOIMAPSession *session = [[MCOIMAPSession alloc] init];
        [session setHostname:_hostname];
        [session setPort:(int)_port];
        [session setUsername:_username?:_address];
        [session setPassword:_password];
        [session setConnectionType:_connectionType];
        [session setAuthType:MCOAuthTypeSASLNone];
        [session setTimeout:30];
        [session setConnectionLogger:^(void * connectionID, MCOConnectionLogType type, NSData * data) {
//            if (data) {
//                NSLog(@"IMAP: %ld %@",type, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
//            }
            
            if ((type == MCOConnectionLogTypeErrorParse) || (type == MCOConnectionLogTypeErrorReceived) || (type == MCOConnectionLogTypeErrorSent)) {
                NSLog(@"IMAP ERROR: %ld %@",type, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }
        }];
        _session = session;
    }else if (_serverType == TBMailServerTypePOP){
        __block MCOPOPSession *session = [[MCOPOPSession alloc] init];
        [session setHostname:_hostname];
        [session setPort:(int)_port];
        [session setUsername:_username?:_address];
        [session setPassword:_password];
        [session setConnectionType:_connectionType];
        [session setAuthType:MCOAuthTypeSASLNone];
        [session setTimeout:30];
        [session setCheckCertificateEnabled:YES];
        [session setConnectionLogger:^(void * connectionID, MCOConnectionLogType type, NSData * data) {
            if (data) {
                NSLog(@"POP3: %ld %@",type, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }
            
            if ((type == MCOConnectionLogTypeErrorParse) || (type == MCOConnectionLogTypeErrorReceived) || (type == MCOConnectionLogTypeErrorSent)) {
                NSLog(@"POP3 ERROR: %ld %@",type, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }
        }];
        _session = session;
    }else{
        _session = @"iTurbo";
    }
    
    return _session;
}

-(void)setUsername:(NSString<Optional> *)username{
    _username = username;
    if (_session) {
        [(MCOPOPSession *)_session setUsername:_username];
    }
}

-(NSString *)summaryTitle{
    return _title?_title:(NSString<Optional> *)_address;
}

-(NSString *)summaryDetailTitle{
    if (_serverType == TBMailServerTypeiTurbo) {
        return nil;
    }
    return _address;
}
@end


@implementation MailFolderInfo

-(NSString<Index,Optional> *)identifier{
    return [NSString stringWithFormat:@"%@@%@",_path,_ownerAccount.identifier];
}

-(BOOL)invalid{
    if ([_path hasPrefix:@"Public"]) {
        return YES;
    }else if ([_path isEqualToString:@"Notes"]) {
        return YES;
    }
    return NO;
}

-(BOOL)isTrash{
    if (_flags&MCOIMAPFolderFlagTrash || [self.title hasPrefix:@"Deleted"]) {
        return YES;
    }
    return NO;
}

-(BOOL)isArchive{
    if (_flags&MCOIMAPFolderFlagArchive || [self.title hasPrefix:@"Archive"]) {
        return YES;
    }
    return NO;
}

-(NSMutableArray<Optional> *)messages{
    if (_messages) return _messages;
    
    NSArray *cached = (NSArray*)[[ApplicationDirector sharedInstance].mailCacheMessages objectForKey:self.identifier];
    _messages = [NSMutableArray arrayWithArray:cached];
    
    // 初始化originalFlags，該參數未序列化
    if (_ownerAccount.serverType == TBMailServerTypeIMAP) {
        for (MCOIMAPMessage *msg in _messages) {
            if (!msg.originalFlags)
                msg.originalFlags = msg.flags;
        }
    }
    
    NSLog(@"Load %ld for %@",_messages.count,self.identifier);
    return _messages;
}

-(void)saveMessages{
    if (_messages) {
        [[ApplicationDirector sharedInstance].mailCacheMessages setObject:_messages forKey:self.identifier block:^(TMDiskCache *cache, NSString *key, id<NSCoding> object, NSURL *fileURL) {
            NSLog(@"%ld messages cached to %@",[(NSArray*)object count],fileURL);
        }];
    }
}

-(void)setPath:(NSString<Index> *)path{
    _path = path;
    [self setTitle:(NSString<Optional> *)_path];
}

-(void)setTitle:(NSString<Optional> *)title{
    // UTF7_IMAP decode
    unsigned long encode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF7_IMAP);
    NSData *responseData =[title dataUsingEncoding:NSUTF8StringEncoding];
    _title = [[NSString alloc] initWithData:responseData encoding:encode];
}


-(NSInteger)order{
    if (_order > 0) return _order;
    
    if (_flags & MCOIMAPFolderFlagInbox || [self.title isEqualToString:@"INBOX"]) {
        _order = 1;
    }else if (_flags & MCOIMAPFolderFlagSentMail || [self.title isEqualToString:@"Sent Messages"]) {
        _order = 5;
    }else if (_flags & MCOIMAPFolderFlagStarred) {
        _order = 15;
    }else if (_flags & MCOIMAPFolderFlagTrash || [self.title isEqualToString:@"Deleted Messages"]) {
        _order = 20;
    }else if (_flags & MCOIMAPFolderFlagDrafts || [self.title isEqualToString:@"Drafts"]) {
        _order = 10;
    }else if (_flags & MCOIMAPFolderFlagSpam || [self.title isEqualToString:@"Junk"]) {
        _order = 30;
    }else if (_flags & MCOIMAPFolderFlagImportant) {
        _order = 3;
    }else if (_flags & MCOIMAPFolderFlagArchive || [self.title isEqualToString:@"Archive"]) {
        _order = 35;
    }else if ([self.title isEqualToString:@"Deleted Items"]) {
        _order = 21;
    }else if ([self.title isEqualToString:@"Sent Items"]) {
        _order = 6;
    }else{
        _order = 100;
    }
    
    return _order;
}

-(void)setFlags:(MCOIMAPFolderFlag)flags{
    if ([_title isEqualToString:@"INBOX"]) {
        _flags = flags|MCOIMAPFolderFlagInbox;
    }else if ([_title isEqualToString:@"Sent Messages"]) {
        _flags = flags|MCOIMAPFolderFlagSentMail;
    }else if ([_title isEqualToString:@"Deleted Messages"]) {
        _flags = flags|MCOIMAPFolderFlagTrash;
    }else if ([_title isEqualToString:@"Drafts"]) {
        _flags = flags|MCOIMAPFolderFlagDrafts;
    }else if ([_title isEqualToString:@"Junk"]) {
        _flags = flags|MCOIMAPFolderFlagSpam;
    }else if ([_title isEqualToString:@"Archive"]) {
        _flags = flags|MCOIMAPFolderFlagArchive;
    }else if ([_title isEqualToString:@"Deleted Items"]) {
        _flags = flags|MCOIMAPFolderFlagTrash;
    }else if ([_title isEqualToString:@"Sent Items"]) {
        _flags = flags|MCOIMAPFolderFlagSentMail;
    }else{
        _flags = flags;
    }
}


-(NSString *)summaryTitle{
    if (_flags & MCOIMAPFolderFlagInbox || [_title isEqualToString:@"INBOX"]) {
        return NSLocalizedString(@"收件箱", nil);
    }else if (_flags & MCOIMAPFolderFlagSentMail || [_title isEqualToString:@"Sent Messages"]) {
        return NSLocalizedString(@"已發郵件", nil);
    }else if (_flags & MCOIMAPFolderFlagStarred) {
        return NSLocalizedString(@"已加星标", nil);
    }else if (_flags & MCOIMAPFolderFlagTrash || [_title isEqualToString:@"Deleted Messages"]) {
        return NSLocalizedString(@"已刪除郵件", nil);
    }else if (_flags & MCOIMAPFolderFlagDrafts || [_title isEqualToString:@"Drafts"]) {
        return NSLocalizedString(@"草稿", nil);
    }else if (_flags & MCOIMAPFolderFlagSpam || [_title isEqualToString:@"Junk"]) {
        return NSLocalizedString(@"垃圾郵件", nil);
    }else if (_flags & MCOIMAPFolderFlagImportant) {
        return NSLocalizedString(@"重要郵件", nil);
    }else if (_flags & MCOIMAPFolderFlagArchive || [_title isEqualToString:@"Archive"]) {
        return NSLocalizedString(@"存檔", nil);
    }else if ([_title isEqualToString:@"Notes"]) {
        return NSLocalizedString(@"便簽夾", nil);
    }else if ([_title isEqualToString:@"Deleted Items"]) {
        return NSLocalizedString(@"已刪除項", nil);
    }else if ([_title isEqualToString:@"Sent Items"]) {
        return NSLocalizedString(@"已發送項", nil);
    }
    
    return _title;
}

-(NSString *)summaryDetailTitle{
    if (_status) {
        return _status.messageCount?[NSString stringWithFormat:@"%d/%d",_status.unseenCount,_status.messageCount]:@"0";
    }else if (_info){
        return [NSString stringWithFormat:@"%d",_info.messageCount];
    }else{
        return nil;
    }
}

-(NSInteger)summaryBadage{
    return _status.unseenCount;
}

-(void)summaryImageToCellImageView:(UIImageView *)imageView completed:(SDWebImageCompletionBlock)completed{
    
    if (_flags & MCOIMAPFolderFlagInbox){
        imageView.image = [UIImage imageNamed:@"Folder"];
    }else if (_flags & MCOIMAPFolderFlagNoSelect){
        imageView.image = [UIImage imageNamed:@"Folders"];
    }else if (_flags & MCOIMAPFolderFlagSentMail){
        imageView.image = [UIImage imageNamed:@"Folder"];
    }else if (_flags & MCOIMAPFolderFlagStarred){
        imageView.image = [UIImage imageNamed:@"Folder"];
    }else if (_flags & MCOIMAPFolderFlagAllMail){
        imageView.image = [UIImage imageNamed:@"Folder"];
    }else if (_flags & MCOIMAPFolderFlagTrash){
        imageView.image = [UIImage imageNamed:@"Folder"];
    }else if (_flags & MCOIMAPFolderFlagDrafts){
        imageView.image = [UIImage imageNamed:@"Folder"];
    }else if (_flags & MCOIMAPFolderFlagSpam){
        imageView.image = [UIImage imageNamed:@"Folder"];
    }else if (_flags & MCOIMAPFolderFlagImportant){
        imageView.image = [UIImage imageNamed:@"Folder"];
    }else if (_flags & MCOIMAPFolderFlagArchive){
        imageView.image = [UIImage imageNamed:@"Folder"];
    }else{
        imageView.image = [UIImage imageNamed:@"Folder"];
    }
}
@end

@implementation SmartFolder
-(instancetype)init{
    self = [super init];
    if (self) {
        messageCollection = [NSMutableArray array];
    }
    return self;
}

- (instancetype) initWithFolder:(MailFolderInfo*)folder{
    self = [self init];
    if (self) {
        self.title = folder.title;
        self.folders = (NSArray<Optional,MailFolderInfo>*)[NSArray arrayWithObject:folder];
    }
    
    return self;
}

- (void)didReceiveMemoryWarning {
    // Dispose of any resources that can be recreated.
}

- (void)saveMessages{
    for (MailFolderInfo *folder in _folders) {
        [folder saveMessages];
    }
}

-(void)setFolders:(NSArray<Optional,MailFolderInfo> *)folders{
    _folders = folders;
    for (MailFolderInfo *folder in _folders) {
        // Insert cached messages
        for (MCOAbstractMessage *msg in folder.messages) {
            [self insertMessage:msg inArray:messageCollection];
        }
    }
}

-(NSIndexSet*)insertMessages:(NSArray *)messages inFolder:(MailFolderInfo*)folder{
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    NSArray *sorted = [messages sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"header.date" ascending:NO]]];
    
    for (MCOAbstractMessage *insertMsg in sorted) {
        NSUInteger atIndex = [self insertMessage:insertMsg inFolder:folder];
        if (atIndex != NSNotFound) {
            [indexes addIndex:atIndex];
        }
    }

    if (indexes.count) {
        
        if (![folder isTrash]) {
            AudioServicesPlaySystemSound(1000);
        }
        
        return [indexes copy];
    }
    return nil;
}

-(NSUInteger)insertMessage:(MCOAbstractMessage *)message inFolder:(MailFolderInfo*)folder{
    // 先插入 Folder
    NSUInteger index = [self insertMessage:message inArray:folder.messages];
    
    if (index == NSNotFound) {
        return index;
    }
    
    // 再插入集合，並且返回集合的index
    return [self insertMessage:message inArray:messageCollection];
}

-(NSUInteger)insertMessage:(MCOAbstractMessage *)message inArray:(NSMutableArray*)array{

    // 不重複插入Message
    if ([array containsObject:message]) {
        return NSNotFound;
    }
    
    __block NSUInteger index = array.count;
    [array enumerateObjectsUsingBlock:^(MCOAbstractMessage *cmsg, NSUInteger idx, BOOL *stop) {
        if ([message.header.date compare:cmsg.header.date] == NSOrderedDescending){
            index = idx;
            *stop = YES;
        }
    }];
    [array insertObject:message atIndex:index];
    
    return index;
}

-(NSIndexSet*)updateMessages:(NSArray *)messages{
    return [self updateMessages:messages isDelete:NO];
}

-(NSIndexSet*)updateMessages:(NSArray *)messages isDelete:(BOOL)deleted{
    for (MailFolderInfo *folder in _folders) {
        
        NSMutableArray *processMessages = [NSMutableArray array];
        for (MCOAbstractMessage *message in messages) {
            
            NSUInteger idx = [folder.messages indexOfObject:message];
            if (idx != NSNotFound) {
                if (deleted && [folder isTrash]) {
                    [folder.messages[idx] updateFlags:MCOMessageFlagDeleted];
                    if (folder.ownerAccount.serverType == TBMailServerTypeIMAP)
                        [processMessages addObject:folder.messages[idx]];
                    [folder.messages removeObjectAtIndex:idx];
                    if (folder.status) folder.status.messageCount --;
                }else if (deleted) {
                    // move to trash
                    [folder.messages[idx] updateFlags:MCOMessageFlagDeleted];
                    
                    MailFolderInfo *trashFolder = folder.ownerAccount.trashFolder;
                    [trashFolder.messages addObject:folder.messages[idx]];
                    if (trashFolder.status) trashFolder.status.messageCount ++;
                    
                    [processMessages addObject:folder.messages[idx]];
                    [folder.messages removeObjectAtIndex:idx];
                    if (folder.status) folder.status.messageCount --;
                }else{
                    [folder.messages[idx] updateFlags:[message TBFlags]];
                    if (folder.status) folder.status.unseenCount --;
                    
                    if (folder.ownerAccount.serverType!=TBMailServerTypePOP){
                        // POP不需要更新服務器處理
                        [processMessages addObject:folder.messages[idx]];
                    }
                }
            }
        }
        
        if (processMessages.count) {
            // change flags to server
            if (folder.ownerAccount.serverType == TBMailServerTypeIMAP){
                __block BOOL containsDelete = NO;
                [processMessages enumerateObjectsUsingBlock:^(MCOIMAPMessage *msg, NSUInteger pidx, BOOL *stop) {
                    if (msg.originalFlags != msg.flags) {
                        if (deleted && ![folder isTrash]){
                            // move to trash
                            MailFolderInfo *trashFolder = folder.ownerAccount.trashFolder;
                            MCOIMAPCopyMessagesOperation *cop = [(MCOIMAPSession *)folder.ownerAccount.session copyMessagesOperationWithFolder:folder.path uids:[MCOIndexSet indexSetWithIndex:msg.uid] destFolder:trashFolder.path];
                            [cop start:^(NSError *error, NSDictionary *uidMapping) {
                                if(!error) {
                                    [uidMapping enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSNumber *obj, BOOL *stop) {
                                        for (MCOIMAPMessage *trashmsg in trashFolder.messages) {
                                            if (trashmsg.uid == [key unsignedIntValue]) {
                                                trashmsg.uid = [obj unsignedIntValue];
                                                break;
                                            }
                                        }
                                    }];
                                    NSLog(@"Copy message:%@", uidMapping);
                                }else{
                                    NSLog(@"Error copy message:%@", error);
                                }
                            }];
                        }
                        
                        NSLog(@"storeFlags %d:%ld,%ld",msg.uid,msg.originalFlags,msg.flags);
                        
                        MCOIMAPOperation *op = [(MCOIMAPSession *)folder.ownerAccount.session storeFlagsOperationWithFolder:folder.path uids:[MCOIndexSet indexSetWithIndex:msg.uid] kind:MCOIMAPStoreFlagsRequestKindSet flags:msg.flags];
                        
                        containsDelete = msg.flags&MCOMessageFlagDeleted;
                        
                        [op start:^(NSError * error) {
                            if(error) {
                                NSLog(@"Error updating flags:%@", error);
                            }else{
                                msg.originalFlags = msg.flags;
                            }
                            if (pidx == processMessages.count - 1) {
                                if(containsDelete)
                                {
                                    //Must also expunge for the archive to happen
                                    MCOIMAPOperation *exOp = [(MCOIMAPSession *)folder.ownerAccount.session expungeOperation:folder.path];
                                    [exOp start:^(NSError *error) {
                                        if(error) {
                                            //TODO: should undo if it fails.
                                            NSLog(@"Error expungeOperation:%@", error);
                                        }
                                        [folder saveMessages];
                                    }];
                                }else{
                                    [folder saveMessages];
                                }
                            }
                        }];
                    }
                }];
                
            }else if (folder.ownerAccount.serverType == TBMailServerTypePOP){
                MCOPOPMessage *msg = [messages firstObject];
                if (msg.flags&MCOMessageFlagDeleted){
                    MCOIndexSet *messageIds = [MCOIndexSet indexSet];
                    for (MCOPOPMessage *message in processMessages) {
                        [messageIds addIndex:message.index];
                    }
                    
                    MCOPOPOperation *op = [(MCOPOPSession *)folder.ownerAccount.session deleteMessagesOperationWithIndexes:messageIds];
                    [op start:^(NSError *error) {
                        if(error)
                            NSLog(@"%@", error);
                        else
                            [folder saveMessages];
                    }];
                }
            }
        }
        
    }
    
    // 處理messageCollection
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    for (MCOAbstractMessage *message in messages) {
        NSUInteger idx = [messageCollection indexOfObject:message];
        if (idx != NSNotFound) {
            [indexes addIndex:idx];
        }
    }
    
    if (deleted){
        [messageCollection removeObjectsAtIndexes:indexes];
    }
    return [indexes copy];
}

-(NSIndexSet*)removeMessages:(NSArray *)messages{
    return [self updateMessages:messages isDelete:YES];
}

- (MailFolderInfo*)ownerFolder:(MCOAbstractMessage*)message{
    
    for (MailFolderInfo *folder in self.folders) {
        for (MCOAbstractMessage *msg in folder.messages) {
            if ([message isEqual:msg]) {
                return folder;
            }
        }
    }
    return nil;
}
- (NSUInteger)indexOfMessage:(MCOAbstractMessage*) message{
    return [messageCollection indexOfObject:message];
}

- (MCOAbstractMessage*) messageAtIndex:(NSUInteger)index{
    return messageCollection[index];
}
- (NSUInteger) countOfMessages{
    return messageCollection.count;
}

-(NSString *)summaryTitle{
    return _title;
}

-(NSString *)summaryDetailTitle{
    if (_folders.count <= 1) {
        return nil;
    }else{
        MailFolderInfo *info = [_folders firstObject];
        if (info.ownerAccount.serverType == TBMailServerTypeiTurbo) {
            return [NSString stringWithFormat:NSLocalizedString(@"%@及%ld帳戶", nil),[info.ownerAccount summaryTitle],_folders.count-1];
        }else{
            return [NSString stringWithFormat:NSLocalizedString(@"%ld帳戶", nil),_folders.count];
        }
    }
}

-(NSInteger)summaryBadage{
    NSUInteger count = 0;
    for (MailFolderInfo *folder in _folders) {
        count += folder.messages.count;
    }
    return count;
}
@end


@implementation AttachmentsFolder
+ (AttachmentsFolder*)sharedInstance{
    static AttachmentsFolder *sharedInstance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AttachmentsFolder alloc] init];
    });
    
    return sharedInstance;
}

- (void)refresh{
    _attachmentCollection = nil;
}

-(NSString *)summaryTitle{
    return NSLocalizedString(@"已下載附件", nil);
}

-(NSString *)summaryDetailTitle{
    return [NSString stringWithFormat:@"%ld",(long)self.attachmentCollection.count];
}

-(void)summaryImageToCellImageView:(UIImageView *)imageView completed:(SDWebImageCompletionBlock)completed{
    [imageView setImage:[UIImage imageNamed:@"Attachment"]];
    
    if (completed) {
        completed(imageView.image,nil,SDImageCacheTypeDisk,nil);
    }
}

-(void)removeAttachmentCollectionAtIndexes:(NSIndexSet *)indexes{
    
    NSArray *removed = [_attachmentCollection objectsAtIndexes:indexes];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSURL *url in removed) {
        [fileManager removeItemAtURL:url error:nil];
    }
    _attachmentCollection = nil;
}

-(NSArray<Optional> *)attachmentCollection{
    if (_attachmentCollection) {
        return _attachmentCollection;
    }
    
    NSString *attachmentDir = [[[ApplicationDirector sharedInstance] documentDirectory] stringByAppendingPathComponent:@"MailAttachments"];
    _attachmentCollection = [ApplicationDirector folderFilesAtPath:attachmentDir withDir:NO];
    return _attachmentCollection;
}
@end
