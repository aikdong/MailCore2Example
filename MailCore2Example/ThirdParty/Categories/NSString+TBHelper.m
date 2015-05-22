//
//  NSString+Email.m
//  AFMailClient
//
//  Created by Andrey Yastrebov on 22.08.13.
//  Copyright (c) 2013 AgileFusion. All rights reserved.
//

#import "NSString+TBHelper.h"

@implementation NSString (TBHelper)

-(BOOL)isInternalAddressValid{
    // The NSRegularExpression class is currently only available in the Foundation framework of iOS 4
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines error:&error];
    NSUInteger numberOfMatches = [regex numberOfMatchesInString:self options:0 range:NSMakeRange(0, [self length])];
    
    if (!error && numberOfMatches > 0)
    {
        return YES;
    }
    
    return NO;
    
}

-(BOOL)isEmailValid{
    // The NSRegularExpression class is currently only available in the Foundation framework of iOS 4
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines error:&error];
    NSUInteger numberOfMatches = [regex numberOfMatchesInString:self options:0 range:NSMakeRange(0, [self length])];
    
    if (!error && numberOfMatches > 0)
    {
        return YES;
    }
    
    return NO;
    
}

- (BOOL)isEmailsValid
{
    // The NSRegularExpression class is currently only available in the Foundation framework of iOS 4
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,4}\\b" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines error:&error];
    NSUInteger numberOfMatches = [regex numberOfMatchesInString:self options:0 range:NSMakeRange(0, [self length])];
    
    if (!error && numberOfMatches > 0)
    {
        return YES;
    }
    
    return NO;
}

- (NSString *)emailDomain
{
    if ([self isEmailValid])
    {
        NSString *fullDomain = [[self componentsSeparatedByString:@"@"] lastObject];
        return [[fullDomain componentsSeparatedByString:@"."] objectAtIndex:0];
    }
    else
    {
        return nil;
    }
}

- (NSString *)emailDomainUpperCase
{
    NSString *domain = [self emailDomain];
    if (domain)
    {
        domain = [domain capitalizedString];
    }
    return domain;
}

-(BOOL) isHTML{
    // The NSRegularExpression class is currently only available in the Foundation framework of iOS 4
    NSError *error = NULL;
    // @"<([A-Za-z][A-Za-z0-9]*)\b[^>]*>(.*?)</\1>"
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"</?[A-Za-z][A-Za-z0-9]*[^<>]*>" options:NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines error:&error];
    NSTextCheckingResult *match = [regex firstMatchInString:self options:NSMatchingReportCompletion range:NSMakeRange(0, [self length])];
    if (!error && !match)
    {
        return NO;
    }
    
    return YES;
}

@end
