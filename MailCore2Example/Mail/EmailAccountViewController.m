//
//  EmailAccountViewController.m
//  CECiTurbo
//
//  Created by DongXing on 4/2/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "EmailAccountViewController.h"

@interface EmailAccountViewController (){
    BOOL isNew;
    MailAccountInfo *mailAccount;
}

@end

@implementation EmailAccountViewController

#pragma mark -
#pragma mark Override
- (XLFormDescriptor *)configureForm:(id)object{
    
    if (object){
        isNew = NO;
        mailAccount = object;
    }else{
        isNew = YES;
        mailAccount = [[MailAccountInfo alloc]init];
    }
    
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    XLFormOptionsObject *defaultvalue;
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"serverType" rowType:XLFormRowDescriptorTypeSelectorSegmentedControl title:@"伺服器类型"];
    defaultvalue = [XLFormOptionsObject formOptionsObjectWithValue:@0 displayText:NSLocalizedString(@"IMAP", nil)];
    row.selectorOptions = @[defaultvalue,
                            [XLFormOptionsObject formOptionsObjectWithValue:@1 displayText:NSLocalizedString(@"POP", nil)]
                            ];
    row.required = YES;
    row.value = [NSNumber numberWithInteger:mailAccount.serverType?:0];
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"伺服器信息", nil)];
    [form addFormSection:section];
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"title" rowType:XLFormRowDescriptorTypeName title:@"名稱"];
    row.required = YES;
    row.value = mailAccount.title;
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"address" rowType:XLFormRowDescriptorTypeEmail title:@"電郵"];
    // validate the email
    [row addValidator:[XLFormValidator emailValidator]];
    row.required = YES;
    row.value = mailAccount.address;
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"password" rowType:XLFormRowDescriptorTypePassword title:@"密碼"];
    row.required = YES;
    row.value = mailAccount.password;
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"hostname" rowType:XLFormRowDescriptorTypeURL title:@"主機名稱"];
    row.required = YES;
    row.value = mailAccount.hostname;
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"connectionType" rowType:XLFormRowDescriptorTypeSelectorSegmentedControl title:NSLocalizedString(@"加密",nil)];
    row.required = YES;
    defaultvalue = [XLFormOptionsObject formOptionsObjectWithValue:@1 displayText:NSLocalizedString(@"不加密", nil)];
    row.selectorOptions = @[defaultvalue,
                            [XLFormOptionsObject formOptionsObjectWithValue:@2 displayText:NSLocalizedString(@"自動", nil)],
                            [XLFormOptionsObject formOptionsObjectWithValue:@4 displayText:NSLocalizedString(@"始終", nil)]
                            ];
    row.value = [NSNumber numberWithInteger:mailAccount.connectionType?:1];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"port" rowType:XLFormRowDescriptorTypeNumber title:@"端口"];
    row.required = YES;
    row.value = [NSNumber numberWithInteger:mailAccount.port>0?mailAccount.port:143];
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"發件服務器SMTP", nil)];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"smtpHostname" rowType:XLFormRowDescriptorTypeURL title:@"主機名稱"];
    row.required = YES;
    row.value = mailAccount.smtpHostname;
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"smtpPort" rowType:XLFormRowDescriptorTypeNumber title:@"端口"];
    row.required = YES;
    row.value = [NSNumber numberWithInteger:mailAccount.smtpPort>0?mailAccount.smtpPort:25];
    [section addFormRow:row];
    return form;
}

#pragma mark - BaseFormViewController Override
-(NSString*)rightButtonItemTitle{
    NSString *title = NSLocalizedString(@"完成", nil);
    return title;
}

-(BOOL)saveWithValues:(NSDictionary *)dict completion:(ProcessCompleteBlock)completion{
    [super saveWithValues:dict completion:completion];
    
    JSONModelError* err;
    BOOL updated = [mailAccount updateWithDictionary:dict withKeyMaper:NO error:&err];
    [mailAccount setSession:nil];
    [mailAccount setSmtpSession:nil];
    
    NSLog(@"Updated JSONModel:%@",[mailAccount toJSONString]);
    
    if (!updated || err){
        if (completion) completion(nil,YES,err);
        return NO;
    }
    else
    {
        if ([mailAccount complete] && mailAccount.serverType == TBMailServerTypePOP){
            MCOPOPSession *session = (MCOPOPSession*)mailAccount.session;
            MCOPOPOperation *op = [session checkAccountOperation];

            [op start:^(NSError *error) {
                
                if (error) {
                    NSLog(@"%@",error);
                    if (error.code == 5) {
                        // 去掉@後面的域作為用戶名
                        mailAccount.username = [[mailAccount.address componentsSeparatedByString:@"@"] firstObject];
                    }
                }
                
                [[session disconnectOperation] start:^(NSError *error) {
                    // 再次更新
                    if (completion)
                        completion(mailAccount,YES,err);
                }];
            }];
        }else{
            if (completion)
                completion(mailAccount,YES,err);
        }
        
        return YES;
    }
}

#pragma mark - XLFormDescriptorDelegate
-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"connectionType"] || [rowDescriptor.tag isEqualToString:@"serverType"]){
        TBMailServerType serverType = [[[self.form formRowWithTag:@"serverType"].value valueData] integerValue];
        MCOConnectionType connectType = [[[self.form formRowWithTag:@"connectionType"].value valueData] integerValue];
        XLFormRowDescriptor *portRow = [self.form formRowWithTag:@"port"];
        XLFormRowDescriptor *smtpPortRow = [self.form formRowWithTag:@"smtpPort"];
        switch (connectType) {
            case MCOConnectionTypeClear:
                portRow.value = serverType==TBMailServerTypeIMAP?@"143":@"110";
                smtpPortRow.value = @"25";
                break;
            case MCOConnectionTypeStartTLS:
                portRow.value = serverType==TBMailServerTypeIMAP?@"143":@"110";
                smtpPortRow.value = @"587";
                break;
            case MCOConnectionTypeTLS:
                portRow.value = serverType==TBMailServerTypeIMAP?@"993":@"995";
                smtpPortRow.value = @"465";
                break;
            default:
                break;
        }
    }else if ([rowDescriptor.tag isEqualToString:@"hostname"]){
        mailAccount.hostname = [[self.form formRowWithTag:@"hostname"].value valueData];
        XLFormRowDescriptor *smtpHostnameRow = [self.form formRowWithTag:@"smtpHostname"];
        smtpHostnameRow.value = mailAccount.smtpHostname;
    }
}
@end
