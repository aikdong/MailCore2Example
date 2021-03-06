//
//  MCOMessageView.m
//  testUI
//
//  Created by DINH Viêt Hoà on 1/19/13.
//  Copyright (c) 2013 MailCore. All rights reserved.
//

#import "MCOMessageView.h"

@interface MCOMessageView () <MCOHTMLRendererIMAPDelegate, UIGestureRecognizerDelegate>

@end

@implementation MCOMessageView {
    UIWebView * _webView;
    NSString * _folder;
    MCOAbstractMessage * _message;
    __weak id <MCOMessageViewDelegate> _delegate;
    BOOL _prefetchIMAPImagesEnabled;
    BOOL _prefetchIMAPAttachmentsEnabled;
    BOOL _msgviewloaded;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if(self) {
        _webView = [[UIWebView alloc] initWithFrame:[self bounds]];
        [_webView setAutoresizingMask:(UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth)];
        [_webView setScalesPageToFit:YES];
        [_webView setDelegate:self];
        [self addSubview:_webView];
        _gestureRecognizerEnabled = NO;
        _msgviewloaded = NO;
    }
    
    return self;
}

- (void) dealloc
{
    _message = nil;
    _folder = nil;
    _webView = nil;
}

- (NSString*) getMessage {
    return _msgContent;
}

- (void) setMessage:(MCOAbstractMessage *)message
{
    _message = message;
    
    [_webView stopLoading];
    [self render];
}

- (MCOAbstractMessage *) message
{
    return _message;
}

- (void) render
{
    NSString * content;
    
    if (_message == nil) {
        content = nil;
    }
    else {
        if ([_message isKindOfClass:[MCOIMAPMessage class]]) {
            content = [(MCOIMAPMessage *) _message htmlRenderingWithFolder:_folder delegate:self];
        }
        else if ([_message isKindOfClass:[MCOMessageBuilder class]]) {
            content = [(MCOMessageBuilder *) _message htmlRenderingWithDelegate:self];
        }
        else if ([_message isKindOfClass:[MCOMessageParser class]]) {
            content = [(MCOMessageParser *) _message htmlRenderingWithDelegate:self];
        }
        else {
            content = nil;
            MCAssert(0);
        }
    }
	if (!content) {
		[_webView loadHTMLString:@"" baseURL:nil];
		return;
	}
	NSMutableString * html = [NSMutableString string];
	NSURL * jsURL = [[NSBundle mainBundle] URLForResource:@"MCOMessageViewScript" withExtension:@"js"];
	[html appendFormat:@"<html><head><script src=\"%@\"></script><style type='text/css'>body{ font-family: 'Helvetica Neue', Helvetica, Arial; margin:0; padding:8px;}\
        hr {border: 0; height: 1px; background-color: #bdc3c7;}\
     .show { display: none;}.hide:target + .show { display: inline;} .hide:target { display: none;} .content { display:none;} .hide:target ~ .content { display:inline;}\
        </style></head><body>%@</body><iframe src='x-mailcore-msgviewloaded:' style='width:device-width; height: 0px; border: 4px;user-scalable=yes;'></iframe></html>",
	 [jsURL absoluteString], content];
	[_webView loadHTMLString:html baseURL:nil];
    if (_msgContent == nil){
        _msgContent = [[NSString alloc] init];
    }
    _msgContent = content;
}

- (BOOL) _isCID:(NSURL *)url
{
	NSString *theScheme = [url scheme];
	if ([theScheme caseInsensitiveCompare:@"cid"] == NSOrderedSame)
        return YES;
    return NO;
}

- (BOOL) _isXMailcoreImage:(NSURL *)url
{
	NSString *theScheme = [url scheme];
	if ([theScheme caseInsensitiveCompare:@"x-mailcore-image"] == NSOrderedSame)
        return YES;
    return NO;
}

- (void) _loadImages
{
	NSString * result = [_webView stringByEvaluatingJavaScriptFromString:@"findCIDImageURL()"];
	NSData * data = [result dataUsingEncoding:NSUTF8StringEncoding];
	NSError *error = nil;
	NSArray * imagesURLStrings = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    NSString* messageID = [[self.message header] messageID];
    
    if (imagesURLStrings.count > 0)
    {
        _gestureRecognizerEnabled = YES;
        
        // Load the JavaScript code from the Resources and inject it into the web page
        NSString *path = [[NSBundle mainBundle] pathForResource:@"WebViewActions" ofType:@"js"];
        NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        [_webView stringByEvaluatingJavaScriptFromString:jsCode];
    }
    
	for(NSString * urlString in imagesURLStrings) {
		MCOAbstractPart * part = nil;
		NSURL * url;
		
		url = [NSURL URLWithString:urlString];
		if ([self _isCID:url] && [_message isKindOfClass:[MCOIMAPMessage class]]) {
            NSLog(@"url is cidurl:%@", url);
			part = [self _partForCIDURL:url];
		}
		else if ([self _isXMailcoreImage:url]) {
            NSLog(@"url is x-mailcore-img:%@", url);
			NSString * specifier = [url resourceSpecifier];
			NSString * partUniqueID = specifier;
			part = [self _partForUniqueID:partUniqueID];
		}
		
		if (part == nil)
			continue;
		
		NSString * partUniqueID = [part uniqueID];
		NSData * data = [self.delegate MCOMessageView:self dataForPartWithUniqueID:partUniqueID];
		
		void (^replaceImages)(NSError *error) = ^(NSError *error) {
			NSData * downloadedData = [self.delegate MCOMessageView:self dataForPartWithUniqueID:partUniqueID];
            NSLog(@"LDC Replace Images: %lu", (unsigned long)[downloadedData length]);

            NSData * previewData = [self.delegate MCOMessageView:self previewForData:downloadedData isHTMLInlineImage:[self _isCID:url]];
			NSString * filename = [NSString stringWithFormat:@"%lu%@", (unsigned long)urlString.hash, messageID];
			NSURL * cacheURL = [self _cacheJPEGImageData:previewData withFilename:filename];
			
			NSDictionary * args = @{ @"URLKey": urlString, @"LocalPathKey": cacheURL.absoluteString };
			NSString * jsonString = [self _jsonEscapedStringFromDictionary:args];
			
			NSString * replaceScript = [NSString stringWithFormat:@"replaceImageSrc(%@)", jsonString];
			[_webView stringByEvaluatingJavaScriptFromString:replaceScript];
		};
		
		if (data == nil) {
			[self.delegate MCOMessageView:self fetchDataForPartWithUniqueID:partUniqueID downloadedFinished:^(NSError * error) {
				replaceImages(error);
			}];
		} else {
			replaceImages(nil);
		}
	}
}

- (NSString *) _jsonEscapedStringFromDictionary:(NSDictionary *)dictionary
{
	NSData * json = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
	NSString * jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
	return jsonString;
}

- (NSURL *) _cacheJPEGImageData:(NSData *)imageData withFilename:(NSString *)filename
{
	NSString * path = [[NSTemporaryDirectory() stringByAppendingPathComponent:filename] stringByAppendingPathExtension:@"jpg"];
	[imageData writeToFile:path atomically:YES];
	return [NSURL fileURLWithPath:path];
}

- (MCOAbstractPart *) _partForCIDURL:(NSURL *)url
{
    return [_message partForContentID:[url resourceSpecifier]];
}

- (MCOAbstractPart *) _partForUniqueID:(NSString *)partUniqueID
{
    return [_message partForUniqueID:partUniqueID];
}

- (NSData *) _dataForIMAPPart:(MCOIMAPPart *)part folder:(NSString *)folder
{
    NSData * data;
    NSString * partUniqueID = [part uniqueID];
    data = [self.delegate MCOMessageView:self dataForPartWithUniqueID:partUniqueID];
    if (data == NULL) {
        [self.delegate MCOMessageView:self fetchDataForPartWithUniqueID:partUniqueID downloadedFinished:^(NSError * error) {
            [self render];
        }];
    }
    return data;
}

- (void)handleTapAtpoint:(CGPoint)pt
{
    if (_gestureRecognizerEnabled)
    {
        // Load the JavaScript code from the Resources and inject it into the web page
        NSString *path = [[NSBundle mainBundle] pathForResource:@"JSTools" ofType:@"js"];
        NSString *jsCode = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        [_webView stringByEvaluatingJavaScriptFromString:jsCode];
        
        // get the Tags at the touch location
        NSString *tags = [_webView stringByEvaluatingJavaScriptFromString:
                          [NSString stringWithFormat:@"getHTMLElementsAtPoint(%li,%li);",(long)pt.x,(long)pt.y]];
                
        NSString *tagsSRC = [_webView stringByEvaluatingJavaScriptFromString:
                             [NSString stringWithFormat:@"getLinkSRCAtPoint(%li,%li);",(long)pt.x,(long)pt.y]];
        
        NSString *tagsID = [_webView stringByEvaluatingJavaScriptFromString:
                             [NSString stringWithFormat:@"getObjectIdAtPoint(%li,%li);",(long)pt.x,(long)pt.y]];

        // If an image was touched, add image-related buttons.
        if ([tags rangeOfString:@",IMG,"].location != NSNotFound)
        {
            NSString * path = [NSTemporaryDirectory() stringByAppendingPathComponent:[[tagsSRC pathComponents] lastObject]];
            UIImage *inlineImage = [UIImage imageWithContentsOfFile:path];
            
            CGRect imageRect = [self positionOfElementWithId:tagsID];
            
            CFStringRef pathExtension = (__bridge_retained CFStringRef)[path pathExtension];
            CFStringRef type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, NULL);
            CFRelease(pathExtension);
            
            // The UTI can be converted to a mime type:
            
            NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType);
            
            if (self.delegate && [self.delegate respondsToSelector:@selector(MCOMessageView:didTappedInlineImage:atPoint:imageRect:imagePath:imageName:imageMimeType:)])
            {
                [self.delegate MCOMessageView:self
                         didTappedInlineImage:inlineImage
                                      atPoint:pt
                                    imageRect:imageRect
                                    imagePath:path
                                    imageName:[[path pathComponents] lastObject]
                                imageMimeType:mimeType];
            }
        }
    }
}

- (CGRect)positionOfElementWithId:(NSString *)elementID {
    NSString *js = @"function f(){ var r = document.getElementById('%@').getBoundingClientRect(); return '{{'+r.left+','+r.top+'},{'+r.width+','+r.height+'}}'; } f();";
    NSString *result = [_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:js, elementID]];
    CGRect rect = CGRectFromString(result);
    return rect;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    NSURLRequest *responseRequest = [self webView:webView
                                         resource:nil
                                  willSendRequest:request
                                 redirectResponse:nil
                                   fromDataSource:nil];
    
    if(responseRequest == request) {

        if ( navigationType == UIWebViewNavigationTypeLinkClicked )
        {
            if ([[[request URL] scheme] isEqual:@"mailto"])
            {
                if (self.delegate && [self.delegate respondsToSelector:@selector(MCOMessageView:handleMailtoUrlString:)])
                {
                    [self.delegate MCOMessageView:self handleMailtoUrlString:[[request URL] resourceSpecifier]];
                }
                
            }
            else if ([[UIApplication sharedApplication] canOpenURL:[request URL]])
            {
                [[UIApplication sharedApplication] openURL:[request URL]];
            }
            
            return NO;
        }
        else
        {
            return YES;
        }
    }
    else
    {
        [webView loadRequest:responseRequest];
        return NO;
    }
}

- (NSURLRequest *)webView:(UIWebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(id)dataSource
{
    if ([[[request URL] scheme] isEqualToString:@"x-mailcore-msgviewloaded"]) {
        _msgviewloaded = YES;
        [self _loadImages];
    }
    
    return request;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (_msgviewloaded) {
        [self.delegate webViewDidFinishLoad:webView];
        
        [webView stringByEvaluatingJavaScriptFromString:@"var element = document.createElement('meta');  element.name = \"viewport\";  element.content = \"width=device-width,user-scalable=yes\"; var head = document.getElementsByTagName('head')[0]; head.appendChild(element);"];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    if ([self.delegate respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [self.delegate webView:webView didFailLoadWithError:error];
    }
}

#pragma mark - MCOHTMLRendererDelegate

- (BOOL) MCOAbstractMessage:(MCOAbstractMessage *)msg canPreviewPart:(MCOAbstractPart *)part
{
    static NSMutableSet * supportedImageMimeTypes = NULL;
    if (supportedImageMimeTypes == NULL) {
        supportedImageMimeTypes = [[NSMutableSet alloc] init];
        [supportedImageMimeTypes addObject:@"image/png"];
        [supportedImageMimeTypes addObject:@"image/gif"];
        [supportedImageMimeTypes addObject:@"image/jpg"];
        [supportedImageMimeTypes addObject:@"image/jpeg"];
    }
    static NSMutableSet * supportedImageExtension = NULL;
    if (supportedImageExtension == NULL) {
        supportedImageExtension = [[NSMutableSet alloc] init];
        [supportedImageExtension addObject:@"png"];
        [supportedImageExtension addObject:@"gif"];
        [supportedImageExtension addObject:@"jpg"];
        [supportedImageExtension addObject:@"jpeg"];
    }
    
    if ([supportedImageMimeTypes containsObject:[[part mimeType] lowercaseString]]) {
        return YES;
    }
    
    NSString * ext = nil;
    if ([part filename] != nil) {
        if ([[part filename] pathExtension] != nil) {
            ext = [[[part filename] pathExtension] lowercaseString];
        }
    }
    if (ext != nil) {
        if ([supportedImageExtension containsObject:ext])
            return YES;
    }
    
    if (![self.delegate respondsToSelector:@selector(MCOMessageView:canPreviewPart:)]) {
        return false;
    }
    return [self.delegate MCOMessageView:self canPreviewPart:part];
}

- (NSDictionary *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateValuesForHeader:(MCOMessageHeader *)header
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView:templateValuesForHeader:)]) {
        return nil;
    }
    return [self.delegate MCOMessageView:self templateValuesForHeader:header];
}

- (NSDictionary *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateValuesForPart:(MCOAbstractPart *)part
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView:templateValuesForPartWithUniqueID:)]) {
        return nil;
    }
    return [self.delegate MCOMessageView:self templateValuesForPartWithUniqueID:[part uniqueID]];
}

- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForMainHeader:(MCOMessageHeader *)header
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView_templateForMainHeader:)]) {
        return nil;
    }
    return [self.delegate MCOMessageView_templateForMainHeader:self];
}

- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForImage:(MCOAbstractPart *)header
{
    NSString * templateString;
    if ([self.delegate respondsToSelector:@selector(MCOMessageView_templateForImage:)]) {
        templateString = [self.delegate MCOMessageView_templateForImage:self];
    }
    else {
        templateString = @"<img src=\"{{URL}}\"/>";
    }
    templateString = [NSString stringWithFormat:@"<div id=\"{{CONTENTID}}\">%@</div>", templateString];
    return templateString;
}

- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForAttachment:(MCOAbstractPart *)part
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView_templateForAttachment:)]) {
        return NULL;
    }
    NSString * templateString = [self.delegate MCOMessageView_templateForAttachment:self];
    templateString = [NSString stringWithFormat:@"<div id=\"{{CONTENTID}}\">%@</div>", templateString];
    return templateString;
}

- (NSString *) MCOAbstractMessage_templateForMessage:(MCOAbstractMessage *)msg
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView_templateForMessage:)]) {
        return NULL;
    }
    return [self.delegate MCOMessageView_templateForMessage:self];
}

- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForEmbeddedMessage:(MCOAbstractMessagePart *)part
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView_templateForEmbeddedMessage:)]) {
        return NULL;
    }
    return [self.delegate MCOMessageView_templateForEmbeddedMessage:self];
}

- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg templateForEmbeddedMessageHeader:(MCOMessageHeader *)header
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView_templateForEmbeddedMessageHeader:)]) {
        return NULL;
    }
    return [self.delegate MCOMessageView_templateForEmbeddedMessageHeader:self];
}

- (NSString *) MCOAbstractMessage_templateForAttachmentSeparator:(MCOAbstractMessage *)msg
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView_templateForAttachmentSeparator:)]) {
        return NULL;
    }
    return [self.delegate MCOMessageView_templateForAttachmentSeparator:self];
}

- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg filterHTMLForPart:(NSString *)html
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView:filteredHTMLForPart:)]) {
        return html;
    }
    return [self.delegate MCOMessageView:self filteredHTMLForPart:html];
}

- (NSString *) MCOAbstractMessage:(MCOAbstractMessage *)msg filterHTMLForMessage:(NSString *)html
{
    if (![self.delegate respondsToSelector:@selector(MCOMessageView:filteredHTMLForMessage:)]) {
        return html;
    }
    return [self.delegate MCOMessageView:self filteredHTMLForMessage:html];
}

- (NSData *) MCOAbstractMessage:(MCOAbstractMessage *)msg dataForIMAPPart:(MCOIMAPPart *)part folder:(NSString *)folder
{
    return [self _dataForIMAPPart:part folder:folder];
}

- (void) MCOAbstractMessage:(MCOAbstractMessage *)msg prefetchAttachmentIMAPPart:(MCOIMAPPart *)part folder:(NSString *)folder
{
    if (!_prefetchIMAPAttachmentsEnabled)
        return;
    
    NSString * partUniqueID = [part uniqueID];
    [self.delegate MCOMessageView:self fetchDataForPartWithUniqueID:partUniqueID downloadedFinished:^(NSError * error) {
        // do nothing
    }];
}

- (void) MCOAbstractMessage:(MCOAbstractMessage *)msg prefetchImageIMAPPart:(MCOIMAPPart *)part folder:(NSString *)folder
{
    if (!_prefetchIMAPImagesEnabled)
        return;
    
    NSString * partUniqueID = [part uniqueID];
    [self.delegate MCOMessageView:self fetchDataForPartWithUniqueID:partUniqueID downloadedFinished:^(NSError * error) {
        // do nothing
    }];
}

@end
