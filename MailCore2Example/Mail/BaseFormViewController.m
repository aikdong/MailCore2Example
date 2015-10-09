//
//  BaseFormViewController.m
//  CECiTurbo
//
//  Created by DongXing on 1/22/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "BaseFormViewController.h"
#import "AFViewShaker.h"
#import "HUD.h"

@interface BaseFormViewController ()

@end

@implementation BaseFormViewController

- (instancetype)init
{
    return [self initWithObject:nil];
}

- (instancetype)initWithObject:(id)object
{
    return [self initWithObject:object style:UITableViewStyleGrouped];
}

- (instancetype)initWithObject:(id)object style:(UITableViewStyle)style{
    XLFormDescriptor *form = [self configureForm:object];
    
    self = [super initWithForm:form style:style];
    
    if (self) {
        [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:[self rightButtonItemTitle] style:UIBarButtonItemStylePlain target:self action:@selector(savePressed:)]];
    }
    
    return self;
}

-(BOOL)saveWithValues:(NSDictionary *)dict completion:(ProcessCompleteBlock)completion{
    return YES;
}

-(XLFormDescriptor *)configureForm:(id)object{
    return nil;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    NSString *message = [self didAppearMessage];
    if (message) {
        [HUD showUIBlockingIndicatorWithText:message withTimeout:2.3 view:self.view];
    }
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    if ([self isModal]) {
        // being presented
        [self.navigationItem setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelPressed:)]];
    } else {
        
    }
}

- (BOOL)isModal {

    if([[self presentingViewController] presentedViewController] == self)
        return YES;
    if([[[self navigationController] presentingViewController] presentedViewController] == [self navigationController])
        return YES;
    if([[[self tabBarController] presentingViewController] isKindOfClass:[UITabBarController class]])
        return YES;
    
    return NO;
}

#pragma mark Override
-(NSString*)didAppearMessage{
    // Override
    return nil;
}

-(NSString*)rightButtonItemTitle{

    return NSLocalizedString(@"完成", nil);
}

-(XLFormDescriptor *)configureForm:(id)object viewType:(NSInteger)viewType{
    // Override
    return nil;
}

-(NSError *)formLogicalError{
    // Override
    return nil;
}

#pragma mark Action
- (void)didProcessCompleteFromServer:(id)json action:(BOOL)isAction with:(NSError *)err{
    

}

- (void)didProcessCompleteFromLocal:(id)object result:(BOOL)success with:(NSError *)err{
    
    [HUD hideUIBlockingIndicator];
    
    if (self.navigationController.viewControllers.count <= 1){
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }else{
        [self.navigationController popViewControllerAnimated:YES];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(formDidProcessComplete:with:)]) {
        [self.delegate formDidProcessComplete:object with:success];
    }
}

- (void)formValidatorShowError:(NSError *)error
{
    XLFormValidationStatus *status = [error.userInfo objectForKey:XLValidationStatusErrorKey];
    XLFormRowDescriptor *row = [status rowDescriptor];
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * USEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [[[AFViewShaker alloc] initWithView:[row cellForFormController:self]] shakeWithDuration:0.6 completion:^{
            if (status.msg) {
                [HUD showUIBlockingIndicatorWithText:status.msg withTimeout:1 view:self.view];
            }
        }];
        
    });
}

-(IBAction)newPressed:(UIBarButtonItem * __unused)button{

    BaseFormViewController *newController = [(BaseFormViewController *)[[self class] alloc] init];
    newController.navigationItem.title = self.navigationItem.title;
    
    if (self.navigationController.viewControllers.count <= 1){

    }else{
        [self.navigationController popViewControllerAnimated:YES];
        [self.navigationController pushViewController:newController animated:YES];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(newSelfComplete:with:)]) {
        [self.delegate newSelfComplete:self with:newController];
    }
}

-(IBAction)cancelPressed:(UIBarButtonItem * __unused)button
{
    [self didProcessCompleteFromLocal:nil result:NO with:nil];
}
  
-(IBAction)savePressed:(UIBarButtonItem * __unused)button
{
    [self.tableView endEditing:YES];
    
    NSArray * validationErrors = [self formValidationErrors];

    if (validationErrors.count){
        NSError *error = [validationErrors firstObject];
        if (error.userInfo) {
            [self formValidatorShowError:error];
        }
        return;
    }else{
        // Validte logical error
        NSError *error = [self formLogicalError];
        if (error){
            if (error.userInfo) {
                [self formValidatorShowError:error];
                
            }
        }else{
            // Save data
            [button setEnabled:NO];
            if (![self saveWithValues:self.formValues completion:^(id object,BOOL isLocal, NSError* err) {
                
                [button setEnabled:YES];
                if (isLocal) {
                    [self didProcessCompleteFromLocal:object result:!err with:err];
                }else{
                    [self didProcessCompleteFromServer:object action:NO with:err];
                }
            }]) {
            }
        }
    }
}

- (IBAction)actionsPressed:(UIBarButtonItem * __unused)sender
{
    [self.tableView endEditing:YES];

    XJAlertManager *alert = [XJAlertManager actionSheetWithTitle:self.form.title
                                                         message:nil
                                                  viewController:self];
        
    [alert addCancelButtonWithTitle:NSLocalizedString(@"取消", nil) handler:nil];
    
    [alert show];
}

#pragma mark - XLFormDescriptorDelegate
-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

@end
