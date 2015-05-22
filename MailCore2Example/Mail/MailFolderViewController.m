//
//  MailFloderViewController.m
//  CECiTurbo
//
//  Created by DongXing on 3/26/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "MailFolderViewController.h"
#import "ComposerViewController.h"

@interface MailFolderViewController ()<ComposerSentDelegate>
{
    BOOL folderLoaded;
}
@end

@implementation MailFolderViewController
static NSString *CellReuseIdentifier = @"MailFolderCell";

- (void)viewDidLoad {
    [super viewDidLoad];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.tintColor = self.view.tintColor;
    [refresh addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;

    folderLoaded = NO;
    [self refreshView:self.refreshControl];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    if (folderLoaded) {
        [self upgradeFolders];
    }
}

- (void)refreshView:(UIRefreshControl*)refreshControl{

    if (self.account.serverType == TBMailServerTypeIMAP) {
        [[ApplicationDirector sharedInstance].mailCacheFolders objectForKey:self.account.identifier block:^(TMDiskCache *cache, NSString *key, id<NSCoding> object, NSURL *fileURL) {
            if (!object) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 沒有緩存文件夾，顯示刷新狀態
                    if (self.tableView.contentOffset.y == 0) [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^(void){self.tableView.contentOffset = CGPointMake(0, -refreshControl.frame.size.height);} completion:nil];
                });
            }
        }];
        
        [refreshControl beginRefreshing];
        MCOIMAPFetchFoldersOperation * op = [(MCOIMAPSession *)self.account.session fetchAllFoldersOperation];
        [op start:^(NSError * error, NSArray *folders) {
            folderLoaded = YES;
            if (!error && folders) {
                [self.account.folders removeAllObjects];
                
                for (MCOIMAPFolder *folder in folders) {
                    MailFolderInfo *mailfolder = [[MailFolderInfo alloc] init];
                    mailfolder.ownerAccount = self.account;
                    mailfolder.path = folder.path;
                    mailfolder.delimiter = folder.delimiter;
                    mailfolder.flags = folder.flags;
                    if (![mailfolder invalid]) {
                        [self.account.folders addObject:mailfolder];
                    }
                }
                
                // 將子文件夾縮進
                [self.account.folders enumerateObjectsUsingBlock:^(MailFolderInfo *folder, NSUInteger idx, BOOL *stop) {
                    
                    if (folder.flags == MCOIMAPFolderFlagNone || (folder.flags & MCOIMAPFolderFlagFolderTypeMask)) {
                        NSArray *paths = [folder.path componentsSeparatedByString:[NSString stringWithFormat:@"%c" , folder.delimiter]];
                        folder.indentationLevel = paths.count-1;
                        folder.title = [paths lastObject];
                    }
                    
                }];
                
                [self.account.folders sortUsingComparator:^NSComparisonResult(MailFolderInfo *folder1, MailFolderInfo *folder2) {
                    if (folder1.indentationLevel != folder2.indentationLevel)
                        return folder1.indentationLevel > folder2.indentationLevel;
                    else
                        return folder1.order > folder2.order;
                }];
                
                // Caching folders
                [[ApplicationDirector sharedInstance].mailCacheFolders setObject:self.account.folders forKey:self.account.identifier];
                [self.tableView reloadData];
                [self upgradeFolders];
            }else{
                NSString *message = NSLocalizedString(@"發生錯誤", nil);
                if (error) {
                    switch (error.code) {
                        case 1:
                            message = [NSString stringWithFormat:NSLocalizedString(@"無法連接：%@", nil),self.account.hostname];
                            break;
                        case 5:
                            message = [NSString stringWithFormat:NSLocalizedString(@"%@身份驗證失敗", nil),[self.account summaryTitle]];
                            break;
                        default:
                            break;
                    }
                    [HUD showErrorWithTitle:message text:error.localizedDescription viewController:self handler:nil];
                }else{
                    message = NSLocalizedString(@"無文件夾", nil);
                    [HUD showUIBlockingIndicatorWithText:message view:self.view];
                }
            }
            [refreshControl endRefreshing];
        }];
    }
}

- (void)upgradeFolders{

    NSLog(@"upgradeFolders");
    
    [self.account.folders enumerateObjectsUsingBlock:^(MailFolderInfo *folder, NSUInteger idx, BOOL *stop) {
        [self updateFolder:folder at:[NSIndexPath indexPathForRow:idx inSection:0]];
    }];
    
}

- (void)updateFolder:(MailFolderInfo*)folder at:(NSIndexPath*)indexPath{
    if (folder.ownerAccount.serverType == TBMailServerTypeIMAP) {
        if (!(folder.flags & MCOIMAPFolderFlagNoSelect) && (folder.flags & MCOIMAPFolderFlagFolderTypeMask)) {
            
            // try to get folder status
            MCOIMAPFolderStatusOperation * statusOp = [(MCOIMAPSession *)self.account.session folderStatusOperation:folder.path];
            [statusOp start:^(NSError *error, MCOIMAPFolderStatus *status) {
                if (!error) {
                    if (![folder.status isEqual:status]) {
                        folder.status = status;
                        
                        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                    }
                }else{
                    NSLog(@"%@ Error:%@",folder,error);
                }
            }];
        }
    }else if (self.account.serverType == TBMailServerTypePOP){
        
    }else{
        
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    return self.account.folders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellReuseIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellReuseIdentifier];
        
        cell.indentationWidth = 24;
    }
    
    MailFolderInfo *info = self.account.folders[indexPath.row];
    if (info.flags & MCOIMAPFolderFlagNoSelect) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [UIColor darkGrayColor];
    }else{
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textColor = [UIColor blackColor];
    }
    [cell setIndentationLevel:info.indentationLevel];
    
    cell.textLabel.text = [info summaryTitle];
    if([info respondsToSelector:@selector(summaryImageToCellImageView:completed:)]){
        [info summaryImageToCellImageView:cell.imageView completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            [cell layoutIfNeeded];
        }];
    }else{
        cell.imageView.image = nil;
    }
    
    [cell layoutIfNeeded];
    
    return cell;
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{

    MailFolderInfo *info = self.account.folders[indexPath.row];
    if (!(info.flags & MCOIMAPFolderFlagNoSelect)) {
        [self performSegueWithIdentifier:@"segueMailFolderToMailList" sender:[[SmartFolder alloc] initWithFolder:info]];
    }else{
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (IBAction)buttonComposerAction:(id)sender {
        [self performSegueWithIdentifier:@"segueMailFolderToComposer" sender:self.account];
}

-(void)composerSent:(MCOAbstractMessage *)msg{
    
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if([[segue destinationViewController] isMemberOfClass:[MailListViewController class]]){
        
        MailListViewController *mlVC = (MailListViewController *)[segue destinationViewController];
        mlVC.smartFolder = sender;
        //mlVC.delegate = self;
    }else if([[[segue destinationViewController] topViewController] isMemberOfClass:[ComposerViewController class]]){
        
        ComposerViewController *vc = (ComposerViewController *)[[segue destinationViewController] topViewController];
        
        [vc setSmtpSession:[(MailAccountInfo*)sender smtpSession]];
        vc.delegate = self;
    }
}
@end
