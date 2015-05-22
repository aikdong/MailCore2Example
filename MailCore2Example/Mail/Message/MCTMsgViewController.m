//
//  MCTMsgViewController.m
//  testUI
//
//  Created by DINH Viêt Hoà on 1/20/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#import "MCTMsgViewController.h"
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import "ProgressSpeeder.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "MBProgressHUD.h"
#import "DelayedAttachment.h"

@interface MCTMsgViewController () <UIGestureRecognizerDelegate, UIPopoverControllerDelegate>
{
}
@end

@implementation MCTMsgViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (!_message){
        return;
    }

    _ops = [[NSMutableArray alloc] init];
    _pending = [[NSMutableSet alloc] init];
    _callbacks = [[NSMutableDictionary alloc] init];
    
    //Remove all the underlying subviews;
    [[self.view subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.scrollEnabled = YES;
    _scrollView.directionalLockEnabled = YES;
    
    NSMutableArray *delays = [self delayedAttachments];
    _headerView = [[HeaderView alloc] initWithFrame:self.view.bounds message:_message delayedAttachments:delays];
    _headerView.delegate = self;
    [_scrollView addSubview:_headerView];

    _messageView = [[MCOMessageView alloc] initWithFrame:CGRectMake(0, _headerView.frame.size.height, self.view.bounds.size.width, self.view.bounds.size.height-_headerView.frame.size.height)];
    [_messageView setDelegate:self];
    [_messageView setFolder:_folder.path];
    [_messageView setMessage:_message];
    [_scrollView addSubview:_messageView];
    //Dont show message view. use the messageContesntsView
    
    [self.view addSubview:_scrollView];
    
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                            action:@selector(didLongPressOnMessageContentsView:)];
    [longPress setDelegate:self];
    [longPress setMinimumPressDuration:0.8f];
    
    [_messageView addGestureRecognizer:longPress];
    
    [self showSpinner];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if ([_message isKindOfClass:[MCOPOPMessage class]]) {
        MCOPOPMessage *msg = (MCOPOPMessage*)_message;
        if (!msg.fetched && msg.index) {
            MCOPOPFetchMessageOperation *op = [(MCOPOPSession *)_session fetchMessageOperationWithIndex:msg.index];
            [op start:^(NSError *error, NSData *messageData) {
                
                if (!error) {
                    msg.fetched = YES;
                    [msg messageData:messageData];
                    [_headerView setDelayedAttachments:[self delayedAttachments]];
                    
                    _messageView.frame = CGRectMake(0, _headerView.frame.size.height, self.view.bounds.size.width, self.view.bounds.size.height-_headerView.frame.size.height);
                    [_messageView render];
                }else{
                    [HUD showErrorWithTitle:NSLocalizedString(@"發生錯誤", nil) text:error.localizedDescription viewController:self handler:nil];
                    [[(MCOPOPSession *)_session disconnectOperation] start:nil];
                }
                
            }];
        }
    }
}

- (NSMutableArray *)delayedAttachments {
    NSMutableArray *delays = [[NSMutableArray alloc] init];
    for (MCOAbstractPart *a in [self.message attachments]) {
        DelayedAttachment *da = [[DelayedAttachment alloc] initWithAbstractPart:a];
        da.fetchAttachment = ^id (NSString *uniqueID,NSString *filename,DelayedAttachmentProgressBlock progress,DelayedAttachmentProgressCompletionBlock progressCompletion){
            
            NSString *path = [NSString pathWithComponents:@[[[ApplicationDirector sharedInstance] documentDirectory],@"MailAttachments",[NSString stringWithFormat:@"%ld%@",(long)[self.message hash],uniqueID]]];
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]){
                [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
            }
            __block NSString *filepath = [path stringByAppendingPathComponent:filename];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
                if (progress) progress(100);
                if (progressCompletion) progressCompletion();
                
                return filepath;
            }else{
                if ([_pending containsObject:uniqueID]) {
                    return nil;
                }
                progress(0);
                [_pending addObject:uniqueID];
                ProgressSpeeder *speeder = [[ProgressSpeeder alloc] init];
                __block NSConditionLock* fetchLock;
                fetchLock = [[NSConditionLock alloc] initWithCondition:1];
                if ([self.message isKindOfClass:[MCOIMAPMessage class]]) {
                    MCOIMAPPart *part = (MCOIMAPPart*)a;
                    MCOIMAPFetchContentOperation *op = [(MCOIMAPSession*)_session fetchMessageAttachmentOperationWithFolder:_folder.path uid:[(MCOIMAPMessage*)_message uid] partID:part.partID encoding:part.encoding urgent:YES];
                    [_ops addObject:op];
                    [op setProgress:^(unsigned int current, unsigned int maximum) {
                        if (progress){
                            NSInteger percent = [speeder currentBytes:current maximumBytes:maximum];
                            progress(percent);
                        }
                    }];
                    

                    [op start:^(NSError * error, NSData * data) {
                        if (error || !data) {
                            filepath = nil;
                            [HUD showErrorWithTitle:NSLocalizedString(@"未能獲取數據", nil) text:NSLocalizedString(@"請稍後再試。", nil) viewController:self handler:nil];
                        }else{
                            NSError *err;
                            [data writeToFile:filepath options:NSDataWritingAtomic error:&err];
                            if (err)
                                NSLog(@"%@",err);
                        }
                        [_ops removeObject:op];
                        [_pending removeObject:uniqueID];
                        [fetchLock lock];
                        [fetchLock unlockWithCondition:0];
                    }];

                }else if ([self.message isKindOfClass:[MCOPOPMessage class]]){
                    
                    // for POPMessage
                    if ([a isKindOfClass:[MCOAttachment class]]) {
                        if ([(MCOAttachment*)a data].length) {
                            NSData *data = [(MCOAttachment*)a data];
                            [data writeToFile:filepath atomically:YES];
                            
                            if (progress) progress(100);
                            [fetchLock lock];
                            [fetchLock unlockWithCondition:0];
                        }
                    }
                    
                }
                
                [fetchLock lockWhenCondition:0];
                [fetchLock unlock];
                
                if (progressCompletion) progressCompletion();
                return filepath;
            }
        };
        [delays addObject:da];
    };
    return delays;
}

-(void)fileURLFor:(NSString*)uniqueID withFilename:(NSString*)filename finished:(void (^)(id responseObject))success{
    [filename pathExtension];
}

-(void)didLongPressOnMessageContentsView:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer && recognizer.state == UIGestureRecognizerStateRecognized)
    {
        CGPoint point = [recognizer locationInView:_messageView];
        [_messageView handleTapAtpoint:point];
    }
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    //Update the underlying webview with the new bounds
    //We don't know it yet for sure, but we can predict it
    if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)){
        _messageView.frame = CGRectMake(0, 0, 703, 724);
    } else {
        //You don't want to do this as it will flash the underlying content. Just wait it out.
        //_messageView.frame = CGRectMake(0, 0, 447, 980);
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    //Update the underlying webview with the new bounds;
    _messageView.frame = self.view.bounds;
    [_headerView render];
}


- (void) showSpinner {
    [MBProgressHUD showHUDAddedTo:[self view] animated:YES];
}

- (void) hideSpinner {
    [MBProgressHUD hideAllHUDsForView:[self view] animated:NO];
}

-(void)setFolder:(MailFolderInfo *)folder{
    _folder = folder;
    _session = folder.ownerAccount.session;
}

- (void) setMessage:(MCOAbstractMessage *)message
{
    for(MCOOperation * op in _ops) {
        [op cancel];
    }
    [_ops removeAllObjects];
    
    [_callbacks removeAllObjects];
    [_pending removeAllObjects];
    _message = message;
}

- (NSString *) msgContent {
    return [[[_messageView getMessage] mco_flattenHTML] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


- (MCOIMAPFetchContentOperation *) _fetchIMAPPartWithUniqueID:(NSString *)partUniqueID folder:(NSString *)folder
{
    MCLog("%s is missing, fetching", partUniqueID.description.UTF8String);
    
    if ([_pending containsObject:partUniqueID]) {
        return nil;
    }
    
    MCOIMAPPart * part = (MCOIMAPPart *) [_message partForUniqueID:partUniqueID];
    //NSAssert(part != nil, @"part != nil");
    
    [_pending addObject:partUniqueID];
    
    MCOIMAPFetchContentOperation * op = [(MCOIMAPSession*)_session fetchMessageAttachmentOperationWithFolder:folder uid:[(MCOIMAPMessage*)_message uid] partID:[part partID] encoding:[part encoding] urgent:YES];
    [_ops addObject:op];
    [op start:^(NSError * error, NSData * data) {
        if ([error code] != MCOErrorNone) {
            [self _callbackForPartUniqueID:partUniqueID error:error];
            return;
        }
        
        if (!data) {
            NSLog(@"No IMAP part data");
        }else{
            NSString *cachekey = [NSString stringWithFormat:@"%@@%ld",partUniqueID,(unsigned long)[_message hash]];
            [[ApplicationDirector sharedInstance].mailCacheDataForPart setObject:data forKey:cachekey];
        }
        [_ops removeObject:op];
        [_pending removeObject:partUniqueID];
        [self _callbackForPartUniqueID:partUniqueID error:nil];
    }];
    
    return op;
}

typedef void (^DownloadCallback)(NSError * error);

- (void) _callbackForPartUniqueID:(NSString *)partUniqueID error:(NSError *)error
{
    NSArray * blocks;
    blocks = [_callbacks objectForKey:partUniqueID];
    for(DownloadCallback block in blocks) {
        block(error);
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return _messageView.gestureRecognizerEnabled;
}

#pragma mark - ActionPickerDelegate
//
//- (void)actionPicker:(ActionPickerViewController *)picker didSelectedAction:(Action)action
//{
//    switch (action)
//    {
//        case ActionOpenWithInk:
//        {
//            NSString *uti = [UTIFunctions UTIFromMimetype:picker.imageMimeType Filename:picker.imageName];
//            
//            [Ink showWorkspaceWithUTI:uti dynamicBlob:^INKBlob *
//            {
//                NSData *data = UIImagePNGRepresentation(picker.image);
//                INKBlob *blob = [[INKBlob alloc] init];
//                blob.data = data;
//                blob.filename = picker.imageName;
//                blob.uti = uti;
//                return blob;
//            }
//                              onReturn:^(INKBlob *result, INKAction *action, NSError *error)
//            {
//                if ([action.type isEqualToString:INKActionType_ReturnCancel])
//                {
//                    NSLog(@"Return Cancel");
//                    return;
//                }
//
//            }];
//        }
//            break;
//            
//        case ActionSaveImage:
//        {
//            UIImageWriteToSavedPhotosAlbum(picker.image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
//        }
//            break;
//            
//        case ActionCopy:
//        {
//            [[UIPasteboard generalPasteboard] setImage:picker.image];
//        }
//            break;
//            
//        case ActionPreview:
//        {
//            // TODO: make preview
//        }
//            break;
//    }
//    
//    //Dismiss the popover if it's showing.
//    if (_actionPicker)
//    {
//        [_actionPickerPopover dismissPopoverAnimated:YES];
//        _actionPickerPopover = nil;
//    }
//}

- (void)image:(UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo
{
    NSLog(@"SAVE IMAGE COMPLETE");
    if(error)
    {
        NSLog(@"ERROR SAVING:%@",[error localizedDescription]);
    }
}

#pragma mark - MCOMessageViewDelegate

- (NSString *) MCOMessageView_templateForAttachmentSeparator:(MCOMessageView *)view {
    return @"";
}

- (NSString *) MCOMessageView_templateForAttachment:(MCOMessageView *)view
{
    // No need for attachments to be displayed. Using Native HeaderView instead.
    return @"";
}

- (NSString *) MCOMessageView_templateForMainHeader:(MCOMessageView *)view {
    // No need for main header. Using Native HeaderView instead.
    return @"";
}

- (NSString *) MCOMessageView_templateForImage:(MCOMessageView *)view {
    // Disable inline image attachments. Using Native HeaderView instead.
    return @"";
}

- (NSString *) MCOMessageView_templateForMessage:(MCOMessageView *)view
{
    return @"{{BODY}}";
}

- (BOOL) MCOMessageView:(MCOMessageView *)view canPreviewPart:(MCOAbstractPart *)part
{
    // tiff, tif, pdf
    NSString * mimeType = [[part mimeType] lowercaseString];
    if ([mimeType isEqualToString:@"image/tiff"]) {
        return YES;
    }
    else if ([mimeType isEqualToString:@"image/tif"]) {
        return YES;
    }
    else if ([mimeType isEqualToString:@"application/pdf"]) {
        return YES;
    }
    
    NSString * ext = nil;
    if ([part filename] != nil) {
        if ([[part filename] pathExtension] != nil) {
            ext = [[[part filename] pathExtension] lowercaseString];
        }
    }
    if (ext != nil) {
        if ([ext isEqualToString:@"tiff"]) {
            return YES;
        }
        else if ([ext isEqualToString:@"tif"]) {
            return YES;
        }
        else if ([ext isEqualToString:@"pdf"]) {
            return YES;
        }
    }
    
    return NO;
}

- (NSData *) MCOMessageView:(MCOMessageView *)view dataForPartWithUniqueID:(NSString *)partUniqueID
{
    NSString *cachekey = [NSString stringWithFormat:@"%@@%ld",partUniqueID,(unsigned long)[_message hash]];
    NSData * data = (NSData*)[[ApplicationDirector sharedInstance].mailCacheDataForPart objectForKey:cachekey];
    return data;
}

- (void) MCOMessageView:(MCOMessageView *)view fetchDataForPartWithUniqueID:(NSString *)partUniqueID
     downloadedFinished:(void (^)(NSError * error))downloadFinished
{
    
    MCOIMAPFetchContentOperation * op = [self _fetchIMAPPartWithUniqueID:partUniqueID folder:_folder.path];
    if (op != nil) {
        [_ops addObject:op];
    }
    if (downloadFinished != NULL) {
        NSMutableArray * blocks;
        blocks = [_callbacks objectForKey:partUniqueID];
        if (blocks == nil) {
            blocks = [NSMutableArray array];
            [_callbacks setObject:blocks forKey:partUniqueID];
        }
        [blocks addObject:[downloadFinished copy]];
    }
}

- (void) MCOMessageView:(MCOMessageView *)view handleMailtoUrlString:(NSString *)mailtoAddress
{
    [self performSegueWithIdentifier:@"segueMailDetailToComposer" sender:@[mailtoAddress]];
}

- (void) MCOMessageView:(MCOMessageView *)view
   didTappedInlineImage:(UIImage *)inlineImage
                atPoint:(CGPoint)point
              imageRect:(CGRect)rect
              imagePath:(NSString *)path
              imageName:(NSString *)imgName
          imageMimeType:(NSString *)mimeType
{    
//    if (!_actionPicker)
//    {
//        _actionPicker = [[ActionPickerViewController alloc] initWithStyle:UITableViewStylePlain];
//        _actionPicker.delegate = self;
//    }
//    
//    _actionPicker.image = inlineImage;
//    _actionPicker.imagePath = path;
//    _actionPicker.imageName = imgName;
//    _actionPicker.imageMimeType = mimeType;
//    
//    if (!_actionPickerPopover)
//    {
//        _actionPickerPopover = [[UIPopoverController alloc] initWithContentViewController:_actionPicker];
//        [_actionPickerPopover setDelegate:self];
//        
//        [_actionPickerPopover configureFlatPopoverWithBackgroundColor:[UIColor iOS7lightGreyColor]
//                                                         cornerRadius:5.f];
//    }
//
//    [_actionPickerPopover presentPopoverFromRect:rect
//                                          inView:_messageView
//                        permittedArrowDirections:UIPopoverArrowDirectionAny
//                                        animated:YES];
}

- (NSData *) MCOMessageView:(MCOMessageView *)view previewForData:(NSData *)data isHTMLInlineImage:(BOOL)isHTMLInlineImage
{
    if (isHTMLInlineImage) {
        return data;
    }
    else {
        return [self _convertToJPEGData:data];
    }
}

#define IMAGE_PREVIEW_HEIGHT 300
#define IMAGE_PREVIEW_WIDTH 500

- (NSData *) _convertToJPEGData:(NSData *)data {
    CGImageSourceRef imageSource;
    CGImageRef thumbnail;
    NSMutableDictionary * info;

    imageSource = CGImageSourceCreateWithData((__bridge CFDataRef) data, NULL);
    if (imageSource == NULL)
        return nil;

    info = [[NSMutableDictionary alloc] init];
    [info setObject:(id) kCFBooleanTrue forKey:(id) kCGImageSourceCreateThumbnailWithTransform];
    [info setObject:(id) kCFBooleanTrue forKey:(id) kCGImageSourceCreateThumbnailFromImageAlways];
    [info setObject:(id) [NSNumber numberWithFloat:(float) IMAGE_PREVIEW_WIDTH] forKey:(id) kCGImageSourceThumbnailMaxPixelSize];
    thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, (__bridge CFDictionaryRef) info);

    CGImageDestinationRef destination;
    NSMutableData * destData = [NSMutableData data];

    destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef) destData,
                                                   (CFStringRef) @"public.jpeg",
                                                   1, NULL);
    
    CGImageDestinationAddImage(destination, thumbnail, NULL);
    CGImageDestinationFinalize(destination);

    CFRelease(destination);

    CFRelease(thumbnail);
    CFRelease(imageSource);

    return destData;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {

    [self hideSpinner];
    
    CGFloat contentHeight = webView.scrollView.contentSize.height;
    CGFloat contentWidth = webView.scrollView.contentSize.width;
    contentHeight = contentHeight > (self.view.bounds.size.height - _headerView.bounds.size.height) ? contentHeight : (self.view.bounds.size.height - _headerView.bounds.size.height);
    _messageView.frame = CGRectMake(_messageView.frame.origin.x, _messageView.frame.origin.y, contentWidth, contentHeight);
    _scrollView.contentSize = CGSizeMake(_messageView.bounds.size.width, _headerView.bounds.size.height + _messageView.bounds.size.height);
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    
    if (error.code != 101) {
        [HUD showTextWithTitle:NSLocalizedString(@"加載中有錯誤", nil) text:error.localizedDescription withTimeout:2 view:self.view];
    }
}
@end
