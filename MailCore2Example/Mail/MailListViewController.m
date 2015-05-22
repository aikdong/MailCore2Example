//
//  MailViewController.m
//  CECiTurbo
//
//  Created by DongXing on 3/26/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "MailListViewController.h"
#import "MessageCell.h"
#import <NSSet+BlocksKit.h>
#import <CCBottomRefreshControl/UIScrollView+BottomRefreshControl.h>
#import "UIImage+Custom.h"
#import "ComposerViewController.h"

@interface MailListViewController () <MessageActionDelegate,ComposerSentDelegate>
{
    NSMutableArray * _ops;
    UIActivityIndicatorView *activity;
}
@property (nonatomic) BOOL isLoading;
@end

@implementation MailListViewController
static NSString *CellReuseIdentifier = @"MailMessageCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _ops = [NSMutableArray array];
    
    if ([ApplicationDirector isIOS8OrHigher]){
        self.tableView.estimatedRowHeight = 98.0;
        self.tableView.rowHeight = UITableViewAutomaticDimension;
    }
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.refreshControl = [UIRefreshControl new];
    self.refreshControl.tintColor = self.view.tintColor;
    [self.refreshControl addTarget:self action:@selector(topRefresh) forControlEvents:UIControlEventValueChanged];
    [self topRefresh];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if (!self.tableView.bottomRefreshControl) {
        UIRefreshControl *bottomRefresh = [UIRefreshControl new];
        bottomRefresh.tintColor = self.view.tintColor;
        bottomRefresh.triggerVerticalOffset = 98.0;
        [bottomRefresh addTarget:self action:@selector(bottomRefresh) forControlEvents:UIControlEventValueChanged];
        self.tableView.bottomRefreshControl = bottomRefresh;
    }
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    self.tableView.bottomRefreshControl = nil;
    
}

- (void)refreshView:(UIRefreshControl*)refreshControl{
    if (!self.smartFolder.folders.count)
        return;
    
    self.isLoading = YES;
    [refreshControl beginRefreshing];
    
    BOOL top = NO;
    if ([refreshControl isEqual:self.refreshControl]) {
        top = YES;
    }
    [self.smartFolder.folders enumerateObjectsUsingBlock:^(MailFolderInfo *folder, NSUInteger idx, BOOL *stop) {
        
        void (^loaded)(NSIndexSet*);
        loaded = ^(NSIndexSet *indexes){
            if (idx == self.smartFolder.folders.count - 1) {
                self.isLoading = NO;
                [refreshControl endRefreshing];
                
                if (indexes.count) {
                    [self.smartFolder saveMessages];
                }
            }
        };
        
        if (folder.ownerAccount.serverType == TBMailServerTypeIMAP) {
            
            void (^fetchMessagesByNumber)(NSUInteger);
            fetchMessagesByNumber = ^(NSUInteger messageCount) {
                
                //
                // Top refresh fetch: 0 - folder.messages.count
                // Bottom refresh fetch: folder.messages.count - add 10
                //
                
                NSUInteger numberOfMessagesToLoad = MIN(messageCount - (top?0:folder.messages.count), 10);
                
                if (numberOfMessagesToLoad > 0)
                {
                    MCORange fetchRange = MCORangeMake(messageCount - (top?0:folder.messages.count) - (numberOfMessagesToLoad - 1),(numberOfMessagesToLoad - 1));
                    MCOIndexSet *numbers = [MCOIndexSet indexSetWithRange:fetchRange];
                    if (numbers.count > 0) {
                        
                        //Get inbox information. Then grab the 50 most recent mails.
                        MCOIMAPMessagesRequestKind requestKind = MCOIMAPMessagesRequestKindHeaders|MCOIMAPMessagesRequestKindStructure|MCOIMAPMessagesRequestKindInternalDate|MCOIMAPMessagesRequestKindFlags;
                        
                        MCOIMAPFetchMessagesOperation *op = [(MCOIMAPSession *)folder.ownerAccount.session
                                                                              fetchMessagesByNumberOperationWithFolder:folder.path
                                                                              requestKind:requestKind
                                                                              numbers:numbers];
                        
                        [_ops addObject:op];
                        [op setProgress:^(unsigned int progress) {
                                //NSLog(@"Progress: %u", progress);
                        }];
                        [op start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
                            
                            //Let's check if there was an error:
                            if(error)
                                NSLog(@"Error downloading message headers:%@", error);
                            
                            NSMutableArray *newMessages = [NSMutableArray arrayWithArray:messages];
                            if (vanishedMessages) {
                                [newMessages removeObjectsAtIndexes:vanishedMessages.nsIndexSet];
                            }
                            
                            NSIndexSet *insertIndexes = [self.smartFolder insertMessages:newMessages inFolder:folder];
                            if (insertIndexes) {
                                NSMutableArray *paths = [NSMutableArray array];
                                [insertIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {[paths addObject:[NSIndexPath indexPathForRow:index inSection:0]];}];
                                [self.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationAutomatic];
                            }
                            
                            // and update flags of messages
                            if (top) {
                                NSIndexSet *updateIndexes = [self updateMessages:newMessages andDelete:NO];
                                loaded(updateIndexes);
                            }else{
                                loaded(insertIndexes);
                            }
                            
                            [_ops removeObject:op];
                        }];
                    }else{
                        loaded(nil);
                    }
                }else{
                    loaded(nil);
                }
            };
            
            if (folder.status) {
                fetchMessagesByNumber(folder.status.messageCount);
            }else{
                MCOIMAPFolderInfoOperation *op = [(MCOIMAPSession *)folder.ownerAccount.session folderInfoOperation:folder.path];
                [_ops addObject:op];
                [op start:^(NSError *error, MCOIMAPFolderInfo *info) {
                    
                    if (!error) {
                        fetchMessagesByNumber(info.messageCount);
                    }else{
                        NSString *message;
                        switch (error.code) {
                            case 1:
                                message = [NSString stringWithFormat:NSLocalizedString(@"無法連接：%@", nil),folder.ownerAccount.hostname];
                                break;
                            case 5:
                                message = [NSString stringWithFormat:NSLocalizedString(@"%@身份驗證失敗", nil),[folder.ownerAccount summaryTitle]];
                                break;
                            default:
                                break;
                        }
                        [HUD showErrorWithTitle:message?:NSLocalizedString(@"發生錯誤", nil) text:error.localizedDescription viewController:self handler:nil];
                    }
                    [_ops removeObject:op];
                }];
            }
            
        }else if (folder.ownerAccount.serverType == TBMailServerTypePOP){
            
            if (folder.flags & MCOIMAPFolderFlagInbox) {
                MCOPOPSession *session = (MCOPOPSession *)folder.ownerAccount.session;
                MCOPOPFetchMessagesOperation *op = [session fetchMessagesOperation];
                [_ops addObject:op];
                [op start:^(NSError *error, NSArray *messageInfos) {
                    
                    if (!error && messageInfos) {
                        NSMutableIndexSet *insertIndexes = [NSMutableIndexSet indexSet];
                        [messageInfos enumerateObjectsUsingBlock:^(MCOPOPMessageInfo *info, NSUInteger midx, BOOL *stop) {
                            // 根據MCOPOPMessageInfo 獲取MailData 初始化為 MCOPOPMessage
                            MCOPOPMessage *message = [[MCOPOPMessage alloc] init];
                            message.index = info.index;
                            message.uid = info.uid;
                            
                            // 已有Message，不重新獲取，只更新Index值
                            NSUInteger msgIdxOfFolder = [folder.messages indexOfObject:message];
                            if (msgIdxOfFolder == NSNotFound) {
                                MCOPOPFetchHeaderOperation *hOp = [session fetchHeaderOperationWithIndex:message.index];
                                [_ops addObject:hOp];
                                [hOp start:^(NSError *error, MCOMessageHeader *header) {
                                    if (!error && header) {
                                        message.header = header;
                                        
                                        NSLog(@"%@",header.allExtraHeadersNames);
                                        
                                        NSIndexSet *indexes = [self.smartFolder insertMessages:@[message] inFolder:folder];
                                        if (indexes) {
                                            [insertIndexes addIndexes:indexes];
                                            NSMutableArray *paths = [NSMutableArray array];
                                            [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {[paths addObject:[NSIndexPath indexPathForRow:index inSection:0]];}];
                                            [self.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationAutomatic];
                                        }
                                    }else if (error){
                                        NSLog(@"%@",error);
                                    }
                                    
                                    if (midx == messageInfos.count - 1) {
                                        MCOPOPOperation *noop = [session noopOperation];
                                        [_ops addObject:noop];
                                        [noop start:^(NSError *error) {
                                            if (error) NSLog(@"%@",error);
                                        }];
                                        loaded(insertIndexes);
                                    }
                                    [_ops removeObject:hOp];
                                }];
                            }else{
                                
                                [[session disconnectOperation] start:nil];
                                
                                MCOPOPMessage *msg = folder.messages[msgIdxOfFolder];
                                [msg setIndex:message.index];
                                if (midx == messageInfos.count - 1){
                                    loaded(insertIndexes);
                                }
                            }
                        }];
                    }else{
                        if (error) {
                            NSString *message;
                            switch (error.code) {
                                case 1:
                                    message = [NSString stringWithFormat:NSLocalizedString(@"無法連接：%@", nil),folder.ownerAccount.hostname];
                                    break;
                                case 5:
                                    message = [NSString stringWithFormat:NSLocalizedString(@"%@身份驗證失敗", nil),[folder.ownerAccount summaryTitle]];
                                    break;
                                default:
                                    break;
                            }
                            [HUD showErrorWithTitle:message?:NSLocalizedString(@"發生錯誤", nil) text:error.localizedDescription viewController:self handler:nil];
                        }
                        
                        [[session disconnectOperation] start:nil];
                        
                        loaded(nil);
                    }
                    [_ops removeObject:op];
                }];
            }else{
                loaded(nil);
            }
        }
    }];
}

- (void)topRefresh{
    if (self.isLoading) return;
    
    if (self.tableView.contentOffset.y == 0) [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^(void){self.tableView.contentOffset = CGPointMake(0, -self.refreshControl.frame.size.height);} completion:nil];
    [self refreshView:self.refreshControl];
}
- (void)bottomRefresh{
    if (self.isLoading) return;
    
    [self refreshView:self.tableView.bottomRefreshControl];
}

-(void)dealloc{
    
    for(MCOOperation * op in _ops) {
        [op cancel];
    }
    [_ops removeAllObjects];
    
    if (self.smartFolder) {
        [self.smartFolder saveMessages];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.smartFolder countOfMessages];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MessageCell *cell = [tableView dequeueReusableCellWithIdentifier:CellReuseIdentifier forIndexPath:indexPath];

    MCOAbstractMessage *message = [self.smartFolder messageAtIndex:indexPath.row];
    MailFolderInfo *folder = [self.smartFolder ownerFolder:message];

    [cell setFolder:folder];
    [cell setMessage:message];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    MCOAbstractMessage *message = [self.smartFolder messageAtIndex:indexPath.row];

    [self performSegueWithIdentifier:@"segueMailListToMessageDetail" sender:message];
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        MCOAbstractMessage *message = [self.smartFolder messageAtIndex:indexPath.row];
        [self trashMessage:message];
    }
}

-(void)flagsMessage:(MCOAbstractMessage*)message{
    [self flagsMessages:@[message]];
}

-(void)organizeMessage:(MCOAbstractMessage*)message{
    [self organizeMessages:@[message]];
}
-(void)trashMessage:(MCOAbstractMessage*)message {
    
    [self trashMessages:@[message]];
    
}

-(void)flagsMessages:(NSArray*)messages{
    // Should remove from ui to be more responsive.
    [self updateMessages:messages andDelete:NO];
}

-(void)trashMessages:(NSArray*)messages{
    // Should remove from ui to be more responsive.
    
    [self updateMessages:messages andDelete:YES];
}

-(void)organizeMessages:(NSArray*)messages{
//    [self organizeMessages:messages andDelete:NO];
}

- (IBAction)buttonComposerAction:(id)sender {
    
    NSInteger smtpsessioncount = 0;
    MCOSMTPSession *smtpsession;
    for (MailFolderInfo *folder in self.smartFolder.folders) {
        if (folder.ownerAccount.serverType != TBMailServerTypeiTurbo) {
            smtpsession = folder.ownerAccount.smtpSession;
            smtpsessioncount++;
        }
    }
    
    // 如果有多個smtpSession就一個都不設置，在发邮件的时候会弹出选择
    [self performSegueWithIdentifier:@"segueMailListToComposer" sender:(smtpsessioncount>0)?nil:smtpsession];
}

-(NSIndexSet*)updateMessages:(NSArray*)messages andDelete:(BOOL)delete{
    // Should remove from ui to be more responsive.
    NSIndexSet *indexes;
    if (delete) {
        indexes = [self.smartFolder removeMessages:messages];
    }else{
        indexes = [self.smartFolder updateMessages:messages];
    }
    
    if (indexes) {
        NSMutableArray *paths = [NSMutableArray array];
        [indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {[paths addObject:[NSIndexPath indexPathForRow:index inSection:0]];}];
        if (delete) {
            [self.tableView deleteRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationAutomatic];
        }else{
            [self.tableView reloadRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationFade];
        }
    }
    
    return indexes;
}

-(void)composerSent:(MCOAbstractMessage *)msg{
    
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([[segue destinationViewController] isMemberOfClass:[MessageDetailViewController class]]){
        
        MCOAbstractMessage *message = (MCOAbstractMessage*)sender;
        MailFolderInfo *folder = [self.smartFolder ownerFolder:message];
        
        MessageDetailViewController *mdVC = (MessageDetailViewController *)[segue destinationViewController];
        mdVC.folder = folder;
        mdVC.message = message;
        mdVC.delegate = self;
    }else if([[[segue destinationViewController] topViewController] isMemberOfClass:[ComposerViewController class]]){
        
        ComposerViewController *vc = (ComposerViewController *)[[segue destinationViewController] topViewController];
        [vc setSmtpSession:(MCOSMTPSession*)sender];
        vc.delegate = self;
        
    }
}
@end
