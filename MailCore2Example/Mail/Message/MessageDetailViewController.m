//
//  MessageDetailViewController.m
//  ThatInbox
//
//  Created by Liyan David Chang on 7/9/13.
//  Copyright (c) 2013 Ink. All rights reserved.
//

#import "MessageDetailViewController.h"
#import "DelayedAttachment.h"
#import "ComposerViewController.h"
#import "XJAlertManager.h"

@interface MessageDetailViewController ()<ComposerSentDelegate>

@end

@implementation MessageDetailViewController

- (IBAction)replyWindow:(id)sender{

    XJAlertManager *alert = [XJAlertManager actionSheetWithTitle:nil
                                                         message:nil
                                                  viewController:self];
    
    [alert addButtonWithTitle:NSLocalizedString(@"轉發", nil) handler:^{
        [self performSegueWithIdentifier:@"segueMailDetailToComposer" sender:@"Forward"];
    }];
    [alert addButtonWithTitle:NSLocalizedString(@"答復", nil) handler:^{
        [self performSegueWithIdentifier:@"segueMailDetailToComposer" sender:@"Reply"];
    }];
    [alert addButtonWithTitle:NSLocalizedString(@"全部答復", nil) handler:^{
        [self performSegueWithIdentifier:@"segueMailDetailToComposer" sender:@"Reply All"];
    }];
    
    [alert addCancelButtonWithTitle:@"取消" handler:nil];
    [alert show];

}

-(void)webViewDidFinishLoad:(UIWebView *)webView{
    [super webViewDidFinishLoad:webView];
    
    // set seen flag
    [self seenMessage];
}


- (void)seenMessage{
    if ([self.message updateFlags:MCOMessageFlagSeen]) {
        [self.delegate flagsMessage:self.message];
    }
}

- (IBAction)trashMessage:(id)sender {
    [self.delegate trashMessage:self.message];
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)composerMessage:(id)sender {
    [self performSegueWithIdentifier:@"segueMailDetailToComposer" sender:nil];
}

-(void)composerSent:(MCOAbstractMessage *)msg{
    [_headerView render];
    [self.delegate flagsMessage:msg];
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([[[segue destinationViewController] topViewController] isMemberOfClass:[ComposerViewController class]]){

        ComposerViewController *vc = (ComposerViewController *)[[segue destinationViewController] topViewController];
        if ([sender isKindOfClass:[NSString class]]) {
            NSString *type = (NSString*)sender;
            NSArray *attachments;
            if ([type isEqualToString:@"Forward"]) {
                attachments = [self delayedAttachments];
            }
            [vc loadWithMessage:self.message ofType:type content:[self msgContent] delayedAttachments:attachments];
        }else if ([sender isKindOfClass:[NSArray class]]) {
            vc.toField.text = [sender componentsJoinedByString:@", "];
        }
        [vc setSmtpSession:self.folder.ownerAccount.smtpSession];
        vc.delegate = self;
    }
}
@end
