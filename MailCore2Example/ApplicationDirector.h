//
//
//  Created by DongXing on 1/4/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "JSONHTTPClient.h"
#import "NSDate+DateTools.h"
#import <TMCache.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UserSelectRowState) {
    UserSelectNoset,
    UserSelectAll,
    UserSelectReversal,
    UserSelectNone
};


@interface ApplicationDirector : NSObject

+ (ApplicationDirector*)sharedInstance;

+ (BOOL)isIOS7OrHigher;
+ (BOOL)isIOS8OrHigher;

+ (NSInteger)fromDateToAge:(NSDate*)date;

@property (nonatomic, strong) NSLocale *locale;
@property (nonatomic, strong) NSNumberFormatter *currencyFormatter;

@property (nonatomic,strong) NSString* documentDirectory;
@property (nonatomic,strong) NSString* cacheDirectory;

@property (nonatomic,strong) TMDiskCache *mailCacheDataForPart;
@property (nonatomic,strong) TMDiskCache *mailCacheFolders;
@property (nonatomic,strong) TMDiskCache *mailCacheMessages;

@property (nonatomic,strong) NSUserDefaults *userDefaults;

// 獲取一個文件夾裏面所有子文件夾裏面的文件列表
+ (NSArray*)folderFilesAtPath:(NSString*)folderPath withDir:(BOOL)incloud;

// // 完全使用unix c函数獲取文件夾大小
+ (long long)folderSizeAtPath:(NSString*) path;

#pragma mark - Utils
- (NSString *)getIPAddress:(BOOL)preferIPv4;

#pragma mark - Save Load Image
- (NSURL*)saveWithImage:(UIImage*)image;
- (UIImage*)loadImageWith:(NSURL *)imageUrl;

#pragma mark - User Setting
- (void)registerForRemoteNotification:(UIApplication *)application andRegister:(BOOL)isRegister;


#pragma mark - DeviceToken
- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken;

@end
