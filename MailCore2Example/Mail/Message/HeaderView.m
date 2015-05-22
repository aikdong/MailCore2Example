//
//  HeaderView.m
//  ThatInbox
//
//  Created by Liyan David Chang on 8/4/13.
//  Copyright (c) 2013 Ink. All rights reserved.
//

#import "HeaderView.h"
#import "FPMimetype.h"
#import "DelayedAttachment.h"
#import "UTIFunctions.h"
#import "TTOpenInAppActivity.h"
#import "UIImage+Custom.h"

@interface HeaderView ()<UIActionSheetDelegate,UIPopoverPresentationControllerDelegate>{
    BOOL fetching;
}

@property MCOAbstractMessage *message;
@property NSArray* attachments;

@end

@implementation HeaderView


- (id)initWithFrame:(CGRect)frame message:(MCOAbstractMessage*)message delayedAttachments:(NSArray*)attachments{
    self = [super initWithFrame:frame];
    if (self) {
        fetching = NO;
        self.message = message;
        self.attachments = attachments;
        [self render];
    }
    return self;
}

- (UIView *)generateSpacer {
    UIView *spacer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 15)];
    spacer.backgroundColor = [UIColor clearColor];
    return spacer;
}

- (UIView *)generateHR {
    UIView *hr = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 1)];
    hr.backgroundColor = [UIColor lightGrayColor];
    return hr;
}

- (void)setDelayedAttachments:(NSArray*)attachments{
    self.attachments = attachments;
    [self render];
}

- (void)render {
    
    [[self subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    MCOMessageHeader *header = [self.message header];
    
    NSMutableArray *headerLabels = [[NSMutableArray alloc] init];
    
    NSString *fromString = [[header from] displayName] ?: [[header from] mailbox];
    if (fromString){
        fromString = [NSString stringWithFormat:@"From: %@", fromString];
        UILabel *label = [[UILabel alloc] init];
        label.text = fromString;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        [label sizeToFit];
        [headerLabels addObject:label];
    }

    if ([self displayNamesFromAddressArray:[header to]]){
        NSString *toString = [NSString stringWithFormat:@"To: %@", [self displayNamesFromAddressArray:[header to]]];
        UILabel *label = [[UILabel alloc] init];
        label.text = toString;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        label.textColor = [UIColor darkGrayColor];
        [label sizeToFit];
        [headerLabels addObject:label];
    }
    
    if ([self displayNamesFromAddressArray:[header cc]]){
        NSString *ccString = [NSString stringWithFormat:@"CC: %@", [self displayNamesFromAddressArray:[header cc]] ];
        UILabel *label = [[UILabel alloc] init];
        label.text = ccString;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
        label.textColor = [UIColor lightGrayColor];
        [label sizeToFit];
        [headerLabels addObject:label];
    }
    
    [headerLabels addObject:[self generateSpacer]];
    [headerLabels addObject:[self generateHR]];
    [headerLabels addObject:[self generateSpacer]];
    
    if ([header subject]){
        NSString *subjectString = [header subject];
        UILabel *label = [[UILabel alloc] init];
        label.text = subjectString;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        [label sizeToFit];
        [headerLabels addObject:label];
    }
    
    if ([header date]){
        NSString *dateString = [NSDateFormatter localizedStringFromDate:[header date]
                                                              dateStyle:NSDateFormatterFullStyle
                                                              timeStyle:NSDateFormatterMediumStyle];
        UILabel *label = [[UILabel alloc] init];
        label.text = dateString;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        label.textColor = [UIColor darkGrayColor];
        [label sizeToFit];
        [headerLabels addObject:label];
    }
    
    [headerLabels addObject:[self generateSpacer]];
    [headerLabels addObject:[self generateHR]];
    
    
    if ([self.attachments count] > 0){
        [headerLabels addObject:[self generateSpacer]];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 20)];
        label.text = NSLocalizedString(@"附件：", nil);
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        label.textColor = [UIColor lightGrayColor];
        [headerLabels addObject:label];
        
        int tag = 0;
        for (DelayedAttachment *da in self.attachments) {
            UIButton *attbutton = [UIButton buttonWithType:UIButtonTypeSystem];
            
            attbutton.frame = CGRectMake(0, 0, 300, 60);
            attbutton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            attbutton.contentEdgeInsets = UIEdgeInsetsMake(16, 60, 10, 0);
            [attbutton.titleLabel setLineBreakMode:NSLineBreakByTruncatingMiddle];
            [attbutton setTitle:[da filename] forState:UIControlStateNormal];
            [attbutton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
            attbutton.tag = tag;
            tag++;
            [attbutton addTarget:self action:@selector(attachmentTapped:) forControlEvents:UIControlEventTouchUpInside];

            UIImageView *progressView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 13, 44, 44)];
            NSString *pathToIcon = [FPMimetype iconPathForMimetype:[da mimeType] Filename:[da filename]];
            progressView.image = [UIImage imageNamed:pathToIcon];
            
            if ([pathToIcon isEqualToString:@"page_white_picture.png"]){
                [da progressShowIn:progressView];
                [self grabAttachementObjectWithBlock:^id{
                    return [da attachmentObject];
                } completion:^(id object) {
                    if (object) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            UIImage *thumb = [[UIImage imageWithContentsOfFile:object] resizableImageWithMaxSize:CGSizeMake(44,44)];
                            
                            progressView.layer.masksToBounds = YES;
                            progressView.layer.cornerRadius = 4.0f;
                            progressView.image = thumb;
                            [progressView setClickObject:[NSURL fileURLWithPath:object]];
                        });
                    }
                }];
            }
            
            
            [attbutton addSubview:progressView];
            
            [headerLabels addObject:attbutton];
            
            UIView *sp = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 5)];
            sp.backgroundColor = [UIColor clearColor];
            [headerLabels addObject:sp];
        }
        
        [headerLabels addObject:[self generateHR]];
        [headerLabels addObject:[self generateSpacer]];
    }

    int startingHeight = 8;
    for (UIView *l in headerLabels){
        l.frame = CGRectMake(16, startingHeight, self.frame.size.width-32, l.frame.size.height);
        [self addSubview:l];
        startingHeight += l.frame.size.height;
    }
    
    self.frame = CGRectMake(0, 0, self.frame.size.width, startingHeight);
    
    self.backgroundColor = [UIColor whiteColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (NSString *)displayNamesFromAddressArray:(NSArray*)addresses {
    if ([addresses count] == 0){
        return nil;
    }
    NSMutableArray *names = [[NSMutableArray alloc] initWithArray:@[]];
    for (MCOAddress *a in addresses){
        if ([a displayName]){
            [names addObject:[a displayName]];
        } else {
            [names addObject:[a mailbox]];
        }
    }
    return [names componentsJoinedByString:@", "];
}

- (void)grabAttachementObjectWithBlock: (id (^)(void))objectBlock completion:(void(^)(id object))callback {
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void){
        id object = objectBlock();
        callback(object);
    });
}

- (void) attachmentTapped:(UIButton *)sender {
    if (fetching) {
        return;
    }
    
    fetching = YES;
    
    DelayedAttachment *da = [self.attachments objectAtIndex:[sender tag]];
    [da progressShowIn:[sender.subviews lastObject]];
    [self grabAttachementObjectWithBlock:^id {
        return [da attachmentObject];
    } completion:^(id object) {
        fetching = NO;
        if (!object)
            return;
        
        NSArray *activityItems;
        if ([object isKindOfClass:[NSString class]]){
            activityItems = @[[NSURL fileURLWithPath:object]];
        }else{
            activityItems = @[da.filename,object];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            TTOpenInAppActivity *openInAppActivity = [[TTOpenInAppActivity alloc] initWithView:self.superview andRect:sender.frame];
            UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:@[openInAppActivity]];
            activityViewController.excludedActivityTypes = @[UIActivityTypeMail];
            
            if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
                // Store reference to superview (UIActionSheet) to allow dismissal
                openInAppActivity.superViewController = activityViewController;
                // Show UIActivityViewController
                [self.delegate presentViewController:activityViewController animated:YES completion:NULL];
            } else {
                // Create pop up
                UIPopoverController *activityPopoverController = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
                // Store reference to superview (UIPopoverController) to allow dismissal
                openInAppActivity.superViewController = activityPopoverController;
                // Show UIActivityViewController in popup
                [activityPopoverController presentPopoverFromRect:sender.frame inView:self.superview permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            }
        });
    }];
    
}
@end
