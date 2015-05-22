//
//  AttachmentListViewController.m
//  CECiTurbo
//
//  Created by DongXing on 4/28/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "AttachmentListViewController.h"
#import "DelayedAttachment.h"
#import "FPMimetype.h"
#import "TTOpenInAppActivity.h"
#import "UIImage+Custom.h"
#import "ComposerViewController.h"

@interface AttachmentListViewController ()<ComposerSentDelegate>
{
    NSArray *selectedRows;
    UserSelectRowState userSelectRowState;
    
    __weak IBOutlet UIBarButtonItem *buttonCompose;
    __weak IBOutlet UIBarButtonItem *buttonTrash;
    UIBarButtonItem *navigationItemRightBarButtonItem;
}
@end

@implementation AttachmentListViewController
static NSString *CellReuseIdentifier = @"AttachmentCell";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([ApplicationDirector isIOS8OrHigher]){
        self.tableView.estimatedRowHeight = 68.0;
        self.tableView.rowHeight = UITableViewAutomaticDimension;
    }
    
    navigationItemRightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(buttonActionEdit:)];
    self.navigationItem.rightBarButtonItem = navigationItemRightBarButtonItem;
    [self.navigationController setToolbarHidden:YES animated:NO];
    
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    refresh.tintColor = self.view.tintColor;
    [refresh addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;
    
    [self refreshView:self.refreshControl];

}

- (void)refreshView:(UIRefreshControl*)refreshControl{
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^(void){self.tableView.contentOffset = CGPointMake(0, -refreshControl.frame.size.height);} completion:nil];
    
    [refreshControl beginRefreshing];
    
    [self.attachmentsFolder refresh];
    [self.tableView reloadData];
    
    [refreshControl endRefreshing];
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
    
    return self.attachmentsFolder.attachmentCollection.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellReuseIdentifier forIndexPath:indexPath];
    cell.textLabel.numberOfLines = 2;
    
    NSURL *info = self.attachmentsFolder.attachmentCollection[indexPath.row];

    cell.textLabel.text = [info lastPathComponent];
    
    long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[info path] error:nil] fileSize];
    cell.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:fileSize countStyle:NSByteCountFormatterCountStyleFile];;
    
    NSString *iconName = [FPMimetype iconPathForFilename:[info path]];
    if ([iconName isEqualToString:@"page_white_picture.png"]){
        UIImage *thumb = [[UIImage imageWithContentsOfFile:[info path]] resizableImageWithMaxSize:CGSizeMake(44,44)];
        cell.imageView.layer.masksToBounds = YES;
        cell.imageView.layer.cornerRadius = 4.0f;
        cell.imageView.image = thumb;
        [cell.imageView setClickObject:info];
    }else{
        cell.imageView.image = [UIImage imageNamed:iconName];
    }

    // reload selected rows
    if ([self.tableView isEditing]) {
        if (userSelectRowState == UserSelectAll) {
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }else if (userSelectRowState == UserSelectReversal){
            if ([selectedRows containsObject:indexPath]) {
                [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            }else{
                [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            }
        }else if ([selectedRows containsObject:indexPath]){
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (self.tableView.isEditing) {
        
        selectedRows = nil;
        userSelectRowState = UserSelectNoset;
        [self buttonActionStateChanged];
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (self.tableView.isEditing) {
        selectedRows = nil;
        userSelectRowState = UserSelectNoset;
        [self buttonActionStateChanged];
        
    }else{
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        NSURL *info = self.attachmentsFolder.attachmentCollection[indexPath.row];
        
        NSArray *activityItems = @[info];

        TTOpenInAppActivity *openInAppActivity = [[TTOpenInAppActivity alloc] initWithView:self.view andRect:cell.frame];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:@[openInAppActivity]];
        activityViewController.excludedActivityTypes = @[UIActivityTypeMail];
        
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
            // Store reference to superview (UIActionSheet) to allow dismissal
            openInAppActivity.superViewController = activityViewController;
            // Show UIActivityViewController
            [self presentViewController:activityViewController animated:YES completion:NULL];
        } else {
            // Create pop up
            UIPopoverController *activityPopoverController = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
            // Store reference to superview (UIPopoverController) to allow dismissal
            openInAppActivity.superViewController = activityPopoverController;
            // Show UIActivityViewController in popup
            [activityPopoverController presentPopoverFromRect:cell.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete | UITableViewCellEditingStyleInsert;
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
        [self.attachmentsFolder removeAttachmentCollectionAtIndexes:[NSIndexSet indexSetWithIndex:indexPath.row]];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)buttonActionStateChanged {
    BOOL actionEnabled = NO;
    
    if (userSelectRowState != UserSelectNoset){
        if (userSelectRowState == UserSelectAll) {
            actionEnabled = YES;
        }else if (userSelectRowState == UserSelectReversal){
            actionEnabled = YES;
        }
    }else if (userSelectRowState == UserSelectNoset){
        if (selectedRows.count || self.tableView.indexPathsForSelectedRows.count)
            actionEnabled = YES;
    }
    [buttonCompose setEnabled:actionEnabled];
    [buttonTrash setEnabled:actionEnabled];
}

- (IBAction)buttonActionSelectAll:(id)sender {
    userSelectRowState = UserSelectAll;
    [self buttonActionStateChanged];
    
    [self.tableView reloadData];
}

- (IBAction)buttonActionReversal:(id)sender {
    userSelectRowState = UserSelectReversal;
    selectedRows = [self.tableView.indexPathsForSelectedRows copy];
    [self buttonActionStateChanged];
    
    [self.tableView reloadData];
}

- (IBAction)buttonActionDone:(id)sender{
    self.navigationItem.rightBarButtonItem = navigationItemRightBarButtonItem;
    
    [self.navigationController setToolbarHidden:YES animated:YES];
    
    //記錄當前選擇
    selectedRows = [self.tableView.indexPathsForSelectedRows copy];
    userSelectRowState = UserSelectNoset;
    [self.tableView setEditing:NO animated:YES];
}

- (IBAction)buttonActionEdit:(id)sender {
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(buttonActionDone:)];
    
    [self.navigationController setToolbarHidden:NO animated:YES];
    [self.tableView setEditing:YES animated:YES];
    
    [self buttonActionStateChanged];
    
    // 加載之前的選擇
    if (selectedRows.count) {
        [self.tableView reloadData];
    }
}

- (IBAction)buttonComposeAction:(UIBarButtonItem *)sender {
    [self.tableView endEditing:YES];
    
    if (self.tableView.indexPathsForSelectedRows.count) {
        NSMutableArray *files = [NSMutableArray array];
        for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
            NSURL *fileURL = [[self.attachmentsFolder attachmentCollection] objectAtIndex:indexPath.row];
            DelayedAttachment *da = [[DelayedAttachment alloc] initWithFileName:fileURL];
            [files addObject:da];
        }
        
        [self performSegueWithIdentifier:@"segueAttachmentToComposer" sender:[files copy]];
    }
}

- (IBAction)buttonTrashAction:(UIBarButtonItem *)sender {
    [self.tableView endEditing:YES];
    
    if (self.tableView.indexPathsForSelectedRows.count) {
        NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
        for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
            [indexes addIndex:indexPath.row];
        }
        [self.attachmentsFolder removeAttachmentCollectionAtIndexes:indexes];
        [self.tableView deleteRowsAtIndexPaths:self.tableView.indexPathsForSelectedRows withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    
}

-(void)composerSent:(MCOAbstractMessage *)msg{
    [self buttonActionDone:msg];
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
        if (sender) {
            vc.delayedAttachmentsArray = sender;
        }
        vc.delegate = self;
    }
}

@end
