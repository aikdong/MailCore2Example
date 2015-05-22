//
//  ComposerViewController.m
//  ThatInbox
//
//  Created by Liyan David Chang on 7/31/13.
//  Copyright (c) 2013 Ink. All rights reserved.
//

#import "ComposerViewController.h"
#import "UTIFunctions.h"
#import "NSString+TBHelper.h"
#import "MCOMessageView.h"
#import "XJAlertManager.h"
#import "DelayedAttachment.h"
#import "FPMimetype.h"
#import "HUD.h"
#import "TTOpenInAppActivity.h"
#import "MailInfo.h"
#import "UIImage+Custom.h"
#import "UIImageView+Click.h"
#import "GKImagePicker.h"
#import "AddAddressViewController.h"
#import <AudioToolbox/AudioToolbox.h>

typedef enum
{
    ToTextFieldTag,
    CcTextFieldTag,
    SubjectTextFieldTag
}TextFildTag;

@interface ComposerViewController () <UIPopoverControllerDelegate,UINavigationControllerDelegate, GKImagePickerDelegate,AddAddressCompleteDelegate>
@end

@implementation ComposerViewController {
    NSString *_type;
    NSString *_toString;
    NSString *_ccString;
    NSString *_bccString;
    NSString *_subjectString;
    NSString *_bodyString;
    __weak IBOutlet UITableViewCell *cellAttachments;
    
    UIPopoverController *pop;
    
    BOOL keyboardState;
    
    BOOL fetching;
    
    MCOAbstractMessage *_message;
    
    NSInteger *_mailSendTypeCount;
}
static NSString *CellReuseIdentifier = @"AttachmentCell";
@synthesize toField, ccField, subjectField, messageBox;
static GKImagePicker *imagePicker;

- (void)loadWithMessage:(MCOAbstractMessage *)msg
               ofType:(NSString*)type
              content:(NSString*)content
   delayedAttachments:(NSArray *)delayedAttachments
{
    _message = msg;
    NSArray *recipients = @[];
    NSArray *cc = @[];
    NSArray *bcc = @[];
    NSString *subject = [[_message header] subject];
    _type = type;
    if ([_type isEqual: @"Forward"]){
        //TODO: Will crash if subject is null
        if (subject){
            subject = [[[_message header] forwardHeader] subject];
        }
    }
    
    if ( [@[@"Reply", @"Reply All"] containsObject:_type]){
        
        subject = [[[_message header] replyHeaderWithExcludedRecipients:@[]] subject];
        recipients = @[[[[[_message header] replyHeaderWithExcludedRecipients:@[]] to] mco_nonEncodedRFC822StringForAddresses]];
        //recipients = @[[[[msg header] from] RFC822String]];
    }
    if ( [@[@"Reply All"] containsObject:_type]){
        cc = @[[[[[_message header] replyAllHeaderWithExcludedRecipients:@[]] cc] mco_nonEncodedRFC822StringForAddresses]];
    }
    
    NSString *body = @"";
    if (content){
        NSString *date = [NSDateFormatter localizedStringFromDate:[[_message header] date]
                                                        dateStyle:NSDateFormatterMediumStyle
                                                        timeStyle:NSDateFormatterMediumStyle];
        
        NSString *replyLine = [NSString stringWithFormat:@"On %@, %@ wrote:", date, [[[_message header] from]nonEncodedRFC822String] ];
        body = [NSString stringWithFormat:@"\n\n\n%@\n> %@", replyLine, [content stringByReplacingOccurrencesOfString:@"\n" withString:@"\n> "]];
    }
    
    [self loadWithTo:recipients CC:cc BCC:bcc subject:subject message:body delayedAttachments:delayedAttachments];
}

- (void)loadWithTo:(NSArray *)to
              CC:(NSArray *)cc
             BCC:(NSArray *)bcc
         subject:(NSString *)subject
         message:(NSString *)message
delayedAttachments:(NSArray *)delayedAttachments
{
    _toString = [self emailStringFromArray:to];
    _ccString = [self emailStringFromArray:cc];
    _bccString = [self emailStringFromArray:bcc];
    _subjectString = subject;
    if ([message length] > 0){
        _bodyString = message;
    } else {
        _bodyString = @"";
    }
    _delayedAttachmentsArray = [NSMutableArray arrayWithArray:delayedAttachments];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)])
        self.edgesForExtendedLayout = UIRectEdgeNone;
    
    toField.text = _toString;
    ccField.text = _ccString;
    subjectField.text = _subjectString;
    messageBox.text = _bodyString;
    
    UIBarButtonItem *sendButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"發送", nil)
                                                                   style:UIBarButtonItemStyleDone target:self action:@selector(sendEmail:)];
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"取消", nil)
                                                                   style:UIBarButtonItemStyleDone target:self action:@selector(closeWindow:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    self.navigationItem.rightBarButtonItem = sendButton;
 
    // Add wiki button to UIMenuController
    UIMenuItem *addItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"添加附件", nil) action:@selector(attachButtonPressed:)];
    [[UIMenuController sharedMenuController] setMenuItems:[NSArray arrayWithObject:addItem]];
    
    if ( [@[@"Reply", @"Reply All"] containsObject:_type]){
        messageBox.selectedRange = NSMakeRange(0,0);
        [messageBox becomeFirstResponder];
    }else{
        [toField becomeFirstResponder];
    }
    
    if ([_type isEqual: @"Forward"]){
        self.navigationItem.title = NSLocalizedString(@"轉發", nil);
    }else if ([_type isEqual: @"Reply"]){
        self.navigationItem.title = NSLocalizedString(@"答復", nil);
    }else if ([_type isEqual: @"Reply All"]){
        self.navigationItem.title = NSLocalizedString(@"答復全部", nil);
    }else{
        self.navigationItem.title = NSLocalizedString(@"新郵件", nil);
    }
}

- (void)grabAttachementObjectWithBlock: (id (^)(void))objectBlock completion:(void(^)(id object))callback {
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void){
        id object = objectBlock();
        callback(object);
    });
}

- (void)updateSendButton {
    if (fetching)
    {
        self.navigationItem.rightBarButtonItem.title = NSLocalizedString(@"加載附件", nil);
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
    else
    {
        self.navigationItem.rightBarButtonItem.title = NSLocalizedString(@"發送", nil);
        self.navigationItem.rightBarButtonItem.enabled = [self isEmailTextFieldValid];
    }
    
    [self.navigationController.navigationBar layoutSubviews];
}

- (BOOL)isEmailTextFieldValid
{
    NSArray *emails = [self emailArrayFromString:toField.text];
    
    if (emails.count == 0)
    {
        return NO;
    }
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
}

- (void) closeWindow:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)sendEmail:(id)sender {

    [self.tableView endEditing:YES];
    
    NSMutableArray *attachements = [NSMutableArray arrayWithCapacity:_delayedAttachmentsArray.count];
    for (DelayedAttachment *da in _delayedAttachmentsArray) {
        if ([da.attachmentObject isKindOfClass:[NSString class]]){
            [attachements addObject:[MCOAttachment attachmentWithContentsOfFile:da.attachmentObject]];
        }else{
            [attachements addObject:[MCOAttachment attachmentWithData:da.attachmentObject filename:da.filename]];
        }
    }
    
    [self sendEmailto:[self emailArrayFromString:toField.text]
                   cc:[self emailArrayFromString:ccField.text]
                  bcc:@[]
          withSubject:subjectField.text
             withBody:[messageBox.text stringByReplacingOccurrencesOfString:@"\n" withString:@"<br />"]
      withAttachments:attachements];

}

- (IBAction)buttonAddAddressAction:(UIButton*)sender {
    
    if (sender.tag == 0) {
        [toField becomeFirstResponder];
        [self performSegueWithIdentifier:@"segueComposerToAddAddress" sender:toField];
    }else if (sender.tag == 1){
        [ccField becomeFirstResponder];
        [self performSegueWithIdentifier:@"segueComposerToAddAddress" sender:ccField];
    }
}

- (IBAction)attachButtonPressed:(UIMenuController*)sender
{
    NSString *title = NSLocalizedString(@"添加附件", nil);
    XJAlertManager *alert = [XJAlertManager actionSheetWithTitle:title
                                                         message:nil
                                                  viewController:self];
    
    // todo 剪貼板
//    if (剪貼板) {
//        [alert addButtonWithTitle:NSLocalizedString(@"從剪貼板", nil) handler:^{
//
//        }];
//    }
    
    [alert addButtonWithTitle:NSLocalizedString(@"從相冊中選擇", nil) handler:^{
        imagePicker = [[GKImagePicker alloc] init];
        imagePicker.imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.resizeableCropArea = YES;
        imagePicker.title = title;
        imagePicker.delegate = self;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            pop = [[UIPopoverController alloc] initWithContentViewController:imagePicker.imagePickerController];
            [pop presentPopoverFromRect:self.navigationController.toolbar.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        } else {
            [self presentViewController:imagePicker.imagePickerController animated:YES completion:nil];
        }
    }];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [alert addButtonWithTitle:NSLocalizedString(@"拍照", nil) handler:^{
            imagePicker = [[GKImagePicker alloc] init];
            imagePicker.imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
            imagePicker.resizeableCropArea = YES;
            imagePicker.title = title;
            imagePicker.delegate = self;
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                pop = [[UIPopoverController alloc] initWithContentViewController:imagePicker.imagePickerController];
                [pop presentPopoverFromRect:self.navigationController.toolbar.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            } else {
                [self presentViewController:imagePicker.imagePickerController animated:YES completion:nil];
            }
        }];
    }
    
    [alert addCancelButtonWithTitle:NSLocalizedString(@"取消", nil) handler:nil];
    [alert show];
}


#pragma mark - EMAIL HELPERS

- (NSString*) emailStringFromArray:(NSArray*) emails {
    return [emails componentsJoinedByString:@", "];
}

- (NSArray *) emailArrayFromString:(NSString*) emailstring {
    
    NSArray *emails = [MCOAddress addressesWithNonEncodedRFC822String:emailstring];
    return emails;
    //Need to remove empty emails with trailing ,
//    NSArray *emails = [emailstring componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
//    NSPredicate *notBlank = [NSPredicate predicateWithFormat:@"length > 0 AND SELF != ' '"];
    
//    return [emails filteredArrayUsingPredicate:notBlank];
}

- (void)sendEmailto:(NSArray*)to
                 cc:(NSArray*)cc
                bcc:(NSArray*)bcc
        withSubject:(NSString*)subject
           withBody:(NSString*)body
    withAttachments:(NSArray*)attachments
{
    
    NSMutableArray *toma = [NSMutableArray array];
    NSMutableArray *toin = [NSMutableArray array];
    for(MCOAddress *address in to) {
        if ([address.mailbox isEmailValid])
            [toma addObject:address];
        else if([address.mailbox isInternalAddressValid])
            [toin addObject:address];
    }
    NSMutableArray *ccma = [NSMutableArray array];
    NSMutableArray *ccin = [NSMutableArray array];
    for(MCOAddress *address in cc) {
        if ([address.mailbox isEmailValid])
            [ccma addObject:address];
        else if([address.mailbox isInternalAddressValid])
            [ccin addObject:address];
    }
    NSMutableArray *bccma = [NSMutableArray array];
    NSMutableArray *bccin = [NSMutableArray array];
    for(MCOAddress *address in bcc) {
        if ([address.mailbox isEmailValid])
            [bccma addObject:address];
        else if([address.mailbox isInternalAddressValid])
            [bccin addObject:address];
    }
    
    _mailSendTypeCount = 0;
    
    [HUD showUIBlockingIndicatorWithText:NSLocalizedString(@"正在發送", nil) view:self.view];
    if (toma.count || ccma.count || bccma.count) {
        // Internet message
        _mailSendTypeCount ++;
        void (^smtpSendBlock)(MCOSMTPSession*) = ^(MCOSMTPSession* session){
            self.smtpSession = session;
            
            MCOMessageBuilder * builder = [[MCOMessageBuilder alloc] init];
            [[builder header] setTo:toma];
            [[builder header] setCc:ccma];
            [[builder header] setBcc:bccma];
            [[builder header] setFrom:[MCOAddress addressWithMailbox:session.username]];
            [[builder header] setSubject:subject];
            [builder setHTMLBody:body];
            
            /* Sending attachments */
            if ([attachments count] > 0){
                [builder setAttachments:attachments];
            }
            NSData * rfc822Data = [builder data];
            MCOSMTPSendOperation *sendOperation = [session sendOperationWithData:rfc822Data];
            [sendOperation start:^(NSError *error) {
                
                [HUD hideUIBlockingIndicator];
                if(error) {
                    self.smtpSession = nil;
                    NSString *message;
                    switch (error.code) {
                        case 1:
                            message = [NSString stringWithFormat:NSLocalizedString(@"無法連接發件服務器：%@", nil),session.hostname];
                            break;
                        case 5:
                            message = [NSString stringWithFormat:NSLocalizedString(@"%@身份驗證失敗", nil),session.username];
                            break;
                        default:
                            break;
                    }
                    [HUD showErrorWithTitle:message?:NSLocalizedString(@"外部郵件發送錯誤", nil) text:error.localizedDescription viewController:self handler:nil];
                } else {
                    [self mailSent];
                }
            }];
        };
        
        if (!self.smtpSession) {
            XJAlertManager *alert = [XJAlertManager actionSheetWithTitle:NSLocalizedString(@"外部郵件", nil)
                                                                 message:NSLocalizedString(@"選擇一個發送地址", nil)
                                                          viewController:self];
            
            NSError *error;
            NSArray *mailAccounts = [MailAccountInfo arrayOfModelsFromDictionaries:[[ApplicationDirector sharedInstance].userDefaults valueForKey:@"UserMailAccountsKey"] withKeyMapper:YES error:&error];
            
            if (error)
                NSLog(@"%@",error);
            
            for (MailAccountInfo *info in mailAccounts) {
                [alert addButtonWithTitle:info.smtpSession.username handler:^{
                    if (smtpSendBlock) {
                        smtpSendBlock(info.smtpSession);
                    }
                }];
            }
            
            [alert addCancelButtonWithTitle:NSLocalizedString(@"取消", nil) handler:nil];
            [alert show];
        }else{
            smtpSendBlock(self.smtpSession);
        }
    }

}

-(void)mailSent{
    _mailSendTypeCount --;
    
    if (_mailSendTypeCount == 0) {

        AudioServicesPlaySystemSound(1001);
        
        if (_message) {
            if ([_type isEqual: @"Forward"]){
                [_message updateFlags:MCOMessageFlagForwarded];
            }else if ([_type isEqual: @"Reply"]){
                [_message updateFlags:MCOMessageFlagAnswered];
            }else if ([_type isEqual: @"Reply All"]){
                [_message updateFlags:MCOMessageFlagAnswered];
            }
        }
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(composerSent:)]) {
            [self.delegate composerSent:_message];
        }
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    if (section != 1)
        return [super tableView:tableView numberOfRowsInSection:section];
    else
    {
        NSInteger count = _delayedAttachmentsArray.count;
        return count;
    }

}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if (indexPath.section != 1)
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    else
        return 44;
}

-(NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section != 1)
        return [super tableView:tableView indentationLevelForRowAtIndexPath:indexPath];
    else
        return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section != 1)
        return [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellReuseIdentifier];
    
    DelayedAttachment *da = _delayedAttachmentsArray[indexPath.row];
    cell.textLabel.text = [da filename];
    NSString *pathToIcon = [FPMimetype iconPathForMimetype:[da mimeType] Filename:[da filename]];
    cell.imageView.image = [UIImage imageNamed:pathToIcon];
    fetching = YES;
    [da progressShowIn:cell.imageView];
    [self grabAttachementObjectWithBlock:^id{
        return [da attachmentObject];
    } completion:^(id object) {
        fetching = NO;
        if (!object) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ([pathToIcon isEqualToString:@"page_white_picture.png"]){
                UIImage *image;
                if ([object isKindOfClass:[NSData class]]){
                    image = [UIImage imageWithData:object];
                    [cell.imageView setClickObject:image];
                }else if ([object isKindOfClass:[NSString class]]){
                    image = [UIImage imageWithContentsOfFile:object];
                    [cell.imageView setClickObject:[NSURL fileURLWithPath:object]];
                }
                UIImage *thumb = [image resizableImageWithMaxSize:CGSizeMake(44,44)];
                cell.imageView.layer.masksToBounds = YES;
                cell.imageView.layer.cornerRadius = 4.0f;
                cell.imageView.image = thumb;
                [cell layoutSubviews];
            }
            [self updateSendButton];
        });
    }];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        if (fetching)
            return;
        
        XJAlertManager *alert = [XJAlertManager actionSheetWithTitle:NSLocalizedString(@"操作附件", nil)
                                                             message:nil
                                                      viewController:self];

        
        [alert addButtonWithTitle:NSLocalizedString(@"刪除", nil) handler:^{
            [_delayedAttachmentsArray removeObjectAtIndex:indexPath.row];
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
        
        [alert addCancelButtonWithTitle:NSLocalizedString(@"取消", nil) handler:nil];
        [alert show];
    }
}

#pragma mark - UITextFieldDelegate

-(BOOL)textViewShouldBeginEditing:(UITextView *)textView{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger section = self.tableView.numberOfSections - 2;
        if ([self.tableView numberOfRowsInSection:section] == 0) {
            section --;
        }
        NSIndexPath *textViewTopIndexPath = [NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:section]-1 inSection:section];
        [self.tableView scrollToRowAtIndexPath:textViewTopIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    });
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField.tag < 2 && textField.text.length > 0 && ![textField.text hasSuffix:@", "])
    {
        textField.text = [textField.text stringByAppendingString:@", "];
    }
    
    if (textField.tag == ToTextFieldTag)
    {
        [self updateSendButton];
    }

}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField.tag == ToTextFieldTag)
    {
        [self updateSendButton];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSUInteger nextTextFieldTag = textField.tag + 1;
    [textField resignFirstResponder];
    if (nextTextFieldTag < 3)
    {
        UITextField *newTextField = (UITextField *)[self.view viewWithTag:nextTextFieldTag];
        [newTextField becomeFirstResponder];
    }
    else if (nextTextFieldTag == 3)
    {
        [messageBox becomeFirstResponder];
        return NO;
    }
    
    return YES;
}


# pragma mark GKImagePicker Delegate Methods
- (void)imagePicker:(GKImagePicker *)imagePicker pickedImage:(UIImage *)image{
    
    [self hideImagePicker];
    
    DelayedAttachment *da = [[DelayedAttachment alloc] init];
    da.attachmentObject = UIImageJPEGRepresentation(image, 1);
    da.filename = @"Image.jpg";
    
    CFStringRef pathExtension = (__bridge_retained CFStringRef)@"jpg";
    CFStringRef type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, NULL);
    CFRelease(pathExtension);
    NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType);
    
    da.mimeType = mimeType;

    if (!_delayedAttachmentsArray)
        _delayedAttachmentsArray = [NSMutableArray arrayWithCapacity:1];
    
    [_delayedAttachmentsArray addObject:da];
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)hideImagePicker{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [pop dismissPopoverAnimated:YES];
    } else {
        [imagePicker.imagePickerController dismissViewControllerAnimated:YES completion:nil];
    }
    
    imagePicker = nil;
}

-(void)addAddressComplete:(UITextField *)bindTextField with:(MCOAddress *)info{
    NSArray *components = [bindTextField.text componentsSeparatedByString:@","];
    NSMutableArray *outComponents = [[NSMutableArray alloc] init];
    for (NSString *c in components) {
        [outComponents addObject:[c stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    }
    [outComponents removeLastObject];
    [outComponents addObject:[NSString stringWithFormat:@"%@<%@>", info.displayName, info.mailbox]];
    bindTextField.text = [outComponents componentsJoinedByString:@", "];
    
    [self updateSendButton];
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[[segue destinationViewController] topViewController] isMemberOfClass:[AddAddressViewController class]]){
        AddAddressViewController *vc = (AddAddressViewController *)[[segue destinationViewController] topViewController];
        vc.bindTextField = sender;
        vc.delegate = self;
    }
}
@end
