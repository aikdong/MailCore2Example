//
//  MailViewController.m
//  CECiTurbo
//
//  Created by DongXing on 3/26/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "MailMainViewController.h"
#import "ComposerViewController.h"
@protocol FormDidProcessCompleteDelegate <NSObject>

@optional
-(void)formDidProcessComplete:(id)object with:(BOOL)success;

-(void)newSelfComplete:(UIViewController*)oldController with:(UIViewController*)newController;

@end

@interface MailMainViewController () <FormDidProcessCompleteDelegate>

@end

@implementation MailMainViewController
static NSString *SmartFolderReuseIdentifier = @"SmartFolderCell";
static NSString *InternalAccountReuseIdentifier = @"InternalAccountCell";
static NSString *MailAccountReuseIdentifier = @"MailAccountCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = NSLocalizedString(@"郵件", nil);
    
    [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(composerMailAction:)]];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:YES];
    
    // reload AttachmentsFolder
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.smartFolders.count inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    _smartFolders = nil;
    _internalAccounts = nil;
    _mailAccounts = nil;
}

-(NSArray *)smartFolders{
    if (!_smartFolders) {
        
        NSMutableArray *iturboFolders = [NSMutableArray array];
        for (MailAccountInfo *account in self.internalAccounts) {
            if ([account complete]) {
                for (MailFolderInfo *folder in account.folders) {
                    if (folder.flags & MCOIMAPFolderFlagInbox) {
                        [iturboFolders addObject:folder];
                    }
                }
            }
        }
        NSMutableArray *internetFolders = [NSMutableArray array];
        for (MailAccountInfo *account in self.mailAccounts) {
            if ([account complete]) {
                for (MailFolderInfo *folder in account.folders) {
                    if (folder.flags & MCOIMAPFolderFlagInbox) {
                        [internetFolders addObject:folder];
                    }
                }
            }
        }
        
        SmartFolder *iturboInboxFolders;
        if (iturboFolders.count) {
            iturboInboxFolders = [[SmartFolder alloc] initWithString:@"{\"title\": \"iTurbo收件箱\"}" error:nil];
            iturboInboxFolders.folders = [iturboFolders copy];
        }
        SmartFolder *internetInboxFolders;
        if (internetFolders.count) {
            internetInboxFolders = [[SmartFolder alloc] initWithString:@"{\"title\": \"Internet收件箱\"}" error:nil];
            internetInboxFolders.folders = [internetFolders copy];
        }
        
        SmartFolder *inboxFolders = [[SmartFolder alloc] initWithString:@"{\"title\": \"所有收件箱\"}" error:nil];
        if (iturboInboxFolders) {
            inboxFolders.folders = (NSArray<Optional,MailFolderInfo>*)[iturboInboxFolders.folders arrayByAddingObjectsFromArray:internetInboxFolders.folders];
        }else{
            inboxFolders.folders = internetInboxFolders.folders;
        }
        
        NSMutableArray *smartFolders = [NSMutableArray array];
        [smartFolders addObject:inboxFolders];
        if (iturboInboxFolders && internetInboxFolders){
            [smartFolders addObject:iturboInboxFolders];
            [smartFolders addObject:internetInboxFolders];
        }
        _smartFolders = [smartFolders copy];
    }
    return _smartFolders;
}

-(NSMutableArray *)mailAccounts{
    
    if (!_mailAccounts) {
        
        NSError *error;
        _mailAccounts = [NSMutableArray arrayWithArray:[MailAccountInfo arrayOfModelsFromDictionaries:[[ApplicationDirector sharedInstance].userDefaults valueForKey:@"UserMailAccountsKey"] withKeyMapper:YES error:&error]];
        if (error) NSLog(@"%@",error);
    }
    
    return _mailAccounts;
}

- (IBAction)buttonAddAccountAction:(UIBarButtonItem *)sender {
    EmailAccountViewController *aVC = [[EmailAccountViewController alloc] init];
    aVC.navigationItem.title = NSLocalizedString(@"新郵箱帳號", nil);
    UINavigationController * nav = [[UINavigationController alloc] initWithRootViewController:aVC];
    
    [self.navigationController presentViewController:nav animated:YES completion:nil];
}

- (IBAction)composerMailAction:(UIBarButtonItem *)sender {
    
    [self performSegueWithIdentifier:@"segueMailMainToComposer" sender:sender];
    
}

-(void)formDidProcessComplete:(MailAccountInfo *)mailAccount with:(BOOL)success{
    
    if (success) {
        NSUInteger idx = [self.mailAccounts indexOfObject:mailAccount];
        if (idx != NSNotFound) {
            if (mailAccount.complete) {
                [self performSegueWithIdentifier:@"segueMailMainToMailFolder" sender:mailAccount];
            }
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.internalAccounts.count+idx inSection:2]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }else{
            [self.mailAccounts addObject:mailAccount];
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:self.internalAccounts.count+self.mailAccounts.count-1 inSection:2]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        
        [[ApplicationDirector sharedInstance].userDefaults setObject:[JSONModel arrayOfDictionariesFromModels:self.mailAccounts] forKey:@"UserMailAccountsKey"];
        [[ApplicationDirector sharedInstance].userDefaults synchronize];
    }
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (section == 0) {
        return self.smartFolders.count+1;// +1 AttachmentFolder
    }else{
        return self.internalAccounts.count + self.mailAccounts.count;
    }
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if (section == 0) {
        return nil;
    }else if (section == 1){
        return NSLocalizedString(@"帳戶", nil);
    }else{
        return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell;
    
    NSObject<InfoSummary> *info;
    if (indexPath.section == 0) {
        if (indexPath.row < self.smartFolders.count){
            info = self.smartFolders[indexPath.row];
            cell = [tableView dequeueReusableCellWithIdentifier:SmartFolderReuseIdentifier forIndexPath:indexPath];
        }else{
            info = [AttachmentsFolder sharedInstance];
            cell = [tableView dequeueReusableCellWithIdentifier:SmartFolderReuseIdentifier forIndexPath:indexPath];
        }
    }else{
        if (indexPath.row < self.internalAccounts.count){
            info = self.internalAccounts[indexPath.row];
            cell = [tableView dequeueReusableCellWithIdentifier:InternalAccountReuseIdentifier forIndexPath:indexPath];
        }else{
            info = self.mailAccounts[indexPath.row - self.internalAccounts.count];
            cell = [tableView dequeueReusableCellWithIdentifier:MailAccountReuseIdentifier forIndexPath:indexPath];
            cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        }
    }
    
    cell.textLabel.text = [info summaryTitle];
    if([info respondsToSelector:@selector(summaryDetailTitle)]){
        cell.detailTextLabel.text = [info summaryDetailTitle];
    }
    if([info respondsToSelector:@selector(summaryImageToCellImageView:completed:)]){
        [info summaryImageToCellImageView:cell.imageView completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            [cell layoutIfNeeded];
        }];
    }else{
        cell.imageView.image = nil;
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if (indexPath.section == 0) {
        if (indexPath.row < self.smartFolders.count){
            SmartFolder *info = self.smartFolders[indexPath.row];
            [self performSegueWithIdentifier:@"segueMailMainToMailList" sender:info];
        }else{
            AttachmentsFolder *info = [AttachmentsFolder sharedInstance];
            [self performSegueWithIdentifier:@"segueMailMainToAttachmentList" sender:info];
        }
    }else{
        MailAccountInfo *info;
        if (indexPath.row < self.internalAccounts.count) {
            info = self.internalAccounts[indexPath.row];
        }else{
            info = self.mailAccounts[indexPath.row-self.internalAccounts.count];
        }
        if (!info.complete) {
            EmailAccountViewController *aVC = [[EmailAccountViewController alloc] init];
            UINavigationController * nav = [[UINavigationController alloc] initWithRootViewController:aVC];
            [self.navigationController presentViewController:nav animated:YES completion:nil];
            
        }else{
            [self performSegueWithIdentifier:@"segueMailMainToMailFolder" sender:info];
        }
    }
}

-(void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section == 1) {
        MailAccountInfo *info;
        if (indexPath.row < self.internalAccounts.count) {
            info = self.internalAccounts[indexPath.row];
        }else{
            info = self.mailAccounts[indexPath.row-self.internalAccounts.count];
        }
        EmailAccountViewController *aVC = [[EmailAccountViewController alloc] init];
        aVC.navigationItem.title = NSLocalizedString(@"郵箱帳號", nil);
        UINavigationController * nav = [[UINavigationController alloc] initWithRootViewController:aVC];
        
        [self.navigationController presentViewController:nav animated:YES completion:nil];
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    if (indexPath.section == 0){
        return NO;
    }else{
        if (indexPath.row < self.internalAccounts.count) {
            return NO;
        }
    }
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        if (indexPath.section == 1){
            if (indexPath.row >= self.internalAccounts.count) {
                [self.mailAccounts removeObjectAtIndex:indexPath.row-self.internalAccounts.count];
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                
                [[ApplicationDirector sharedInstance].userDefaults setObject:[JSONModel arrayOfDictionariesFromModels:self.mailAccounts] forKey:@"UserMailAccountsKey"];
                [[ApplicationDirector sharedInstance].userDefaults synchronize];
                
                _smartFolders = nil;
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    }
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([[segue destinationViewController] isMemberOfClass:[MailListViewController class]]){
        
        MailListViewController *mlVC = (MailListViewController *)[segue destinationViewController];
        mlVC.smartFolder = sender;
    }else if ([[segue destinationViewController] isMemberOfClass:[AttachmentListViewController class]]){
        AttachmentListViewController *alVC = (AttachmentListViewController *)[segue destinationViewController];
        AttachmentsFolder *attfolder = (AttachmentsFolder*)sender;
        alVC.attachmentsFolder = attfolder;
    }else if ([[segue destinationViewController] isMemberOfClass:[MailFolderViewController class]]){
        MailFolderViewController *mfVC = (MailFolderViewController *)[segue destinationViewController];
        MailAccountInfo *account = (MailAccountInfo*)sender;
        mfVC.account = account;
    }
}
@end
