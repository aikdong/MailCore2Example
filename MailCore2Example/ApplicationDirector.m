//
//
//  Created by DongXing on 1/4/15.
//  Copyright (c) 2015 CEC. All rights reserved.
//

#import "ApplicationDirector.h"
#import "UIImage+Custom.h"
#import "AppDelegate.h"
#import "XJAlertManager.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AdSupport/AdSupport.h>
#import "NSDate+DateTools.h"
#import "HUD.h"
#import "NSData+CommonCrypto.h"
#import "EVURLCache.h"
#import "NSString+MD5.h"
#import <AFNetworking/AFNetworking.h>

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <sys/stat.h>
#include <dirent.h>

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

/**
 *  Extern String
 */
NSString * const NotificationModuleChanged  = @"NotificationModuleChanged";
NSString * const NotificationCategoryAction  = @"CategoryAction";
NSString * const NotificationActionActionAccept = @"ACTION_ACCEPT";
NSString * const NotificationActionActionRefuse = @"ACTION_REFUSE";
NSString * const InvalidReturnedData = @"連線逾時或資料錯誤，服務器返回異常。";
NSString * const LoadingString = @"正在獲取";
NSString * const PleaseChooseString = @"請選擇";
NSString * const NoDataString = @"無數據";


@interface ApplicationDirector(){
}
@end

@implementation ApplicationDirector

#pragma mark - Initialization and Destruction
- (void)dealloc {
    
    _currencyFormatter = nil;
    _locale = nil;
    
}

+ (ApplicationDirector *)sharedInstance
{
    static ApplicationDirector *sharedInstance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ApplicationDirector alloc] init];
        
    });
    
    return sharedInstance;
}

+ (BOOL)isIOS7OrHigher
{
    float versionNumber = floor(NSFoundationVersionNumber);
    return versionNumber >= NSFoundationVersionNumber_iOS_6_1;
}

+ (BOOL)isIOS8OrHigher
{
    float versionNumber = floor(NSFoundationVersionNumber);
    return versionNumber >= NSFoundationVersionNumber_iOS_7_1;
}


#pragma mark - @property
-(TMDiskCache *)mailCacheDataForPart{
    if (_mailCacheDataForPart)
        return _mailCacheDataForPart;
    _mailCacheDataForPart = [[TMDiskCache alloc] initWithName:@"MailCacheDataForPart"];
    return _mailCacheDataForPart;
}
-(TMDiskCache *)mailCacheFolders{
    if (_mailCacheFolders)
        return _mailCacheFolders;
    _mailCacheFolders = [[TMDiskCache alloc] initWithName:@"MailCacheFolders"];
    return _mailCacheFolders;
}
-(TMDiskCache *)mailCacheMessages{
    if (_mailCacheMessages)
        return _mailCacheMessages;
    _mailCacheMessages = [[TMDiskCache alloc] initWithName:@"MailCacheMessages"];
    return _mailCacheMessages;
}

-(NSUserDefaults *)userDefaults{
    if (_userDefaults) {
        return _userDefaults;
    }
    _userDefaults = [NSUserDefaults standardUserDefaults];
    
    return _userDefaults;
}

-(NSLocale *)locale{
    if (_locale) return _locale;
    
    _locale = [NSLocale localeWithLocaleIdentifier:@"en-US"];
    return _locale;
}

-(NSNumberFormatter *)currencyFormatter{
    if (_currencyFormatter) return _currencyFormatter;
    
    _currencyFormatter = [NSNumberFormatter new];
    _currencyFormatter.numberStyle = kCFNumberFormatterCurrencyStyle;
    _currencyFormatter.locale = self.locale;
    _currencyFormatter.maximumIntegerDigits = 14;
    
    return _currencyFormatter;
}


-(NSString *)documentDirectory{
    if (_documentDirectory) {
        return _documentDirectory;
    }
    _documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return _documentDirectory;
}

-(NSString *)cacheDirectory{
    if (_cacheDirectory) {
        return _cacheDirectory;
    }
    _cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return _cacheDirectory;
}


#pragma mark - App delegate
- (void) applicationDidReceiveMemoryWarning:(UIApplication *)application{
    //clean cached data
    
}

- (void) registerForRemoteNotification:(UIApplication *)application andRegister:(BOOL)isRegister{
#if !TARGET_IPHONE_SIMULATOR
    if (isRegister) {
        //调用push，请求获取动态令牌
        if ([ApplicationDirector isIOS8OrHigher])
        {
#ifdef __IPHONE_8_0
            // Pair Request Action
            UIMutableUserNotificationAction *actionAccept = [[UIMutableUserNotificationAction alloc] init];
            [actionAccept setAuthenticationRequired:YES];
            [actionAccept setActivationMode:UIUserNotificationActivationModeBackground];
            [actionAccept setTitle:NSLocalizedString(@"Accept", @"Accept")];
            [actionAccept setIdentifier:NotificationActionActionAccept];
            [actionAccept setDestructive:NO];
            
            UIMutableUserNotificationAction *actionRefuse = [[UIMutableUserNotificationAction alloc] init];
            [actionRefuse setAuthenticationRequired:YES];
            [actionRefuse setActivationMode:UIUserNotificationActivationModeBackground];
            [actionRefuse setTitle:NSLocalizedString(@"Refuse", @"Refuse")];
            [actionRefuse setIdentifier:NotificationActionActionRefuse];
            [actionRefuse setDestructive:YES];
            
            UIMutableUserNotificationCategory *actionCategory = [[UIMutableUserNotificationCategory alloc] init];
            [actionCategory setIdentifier:NotificationCategoryAction];
            [actionCategory setActions:@[actionAccept, actionRefuse] forContext:UIUserNotificationActionContextDefault];
            
            NSSet *categories = [NSSet setWithObjects:actionCategory, nil];
            
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:categories];
            [application registerUserNotificationSettings:settings];
            
#endif
        }
        else
        {
            UIRemoteNotificationType myTypes = UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound;
            [application registerForRemoteNotificationTypes:myTypes];
        }
    }else{
        [application unregisterForRemoteNotifications];
    }
#endif
}


- (void)application:(UIApplication *)application receiveRemoteNotification:(NSDictionary *)userInfo{

    NSString *category = userInfo[@"aps"][@"category"];
    
    if ([category isEqualToString:NotificationCategoryAction]) {
        // 收到消息
        if (application.applicationState == UIApplicationStateActive)
        {
            // 活动状态，正在运行，用户没有看到PUSH消息内容
            // 如果当前不是 DatingNavigationViewController
            AudioServicesPlaySystemSound(1003);
        }
        else
        {
            //[[NSNotificationCenter defaultCenter] postNotificationName:RemoteNotificationMessage object:nil userInfo:userInfo];
        }
        
    }else{
        //收到其他通知
        
        if (application.applicationState == UIApplicationStateActive) {
            // 活动状态，正在运行，用户没有看到PUSH消息内容
        }
    }
}

#pragma mark - DeviceToken
//得到令牌
- (void) didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    // Prepare the Device Token for Registration (remove spaces and < >)
    NSString *newToken = [[[[deviceToken description]
                            stringByReplacingOccurrencesOfString:@"<"withString:@""]
                           stringByReplacingOccurrencesOfString:@">" withString:@""]
                          stringByReplacingOccurrencesOfString: @" " withString:@""];
    
    // Save
    NSLog(@"%@",newToken);
    // 更新服务器

}

#pragma mark - Save Load Image
- (NSString*)createTempFileNameWithFormat:(NSString*)format inDirectory:(NSString*)dir
{
    NSString* templateStr = [NSString stringWithFormat:@"%@/%@",dir, format];
    char template[templateStr.length + 1];
    strcpy(template, [templateStr cStringUsingEncoding:NSASCIIStringEncoding]);
    char* filename = mktemp(template);
    
    if (filename == NULL) {
        return nil;
    }
    return [NSString stringWithCString:filename encoding:NSASCIIStringEncoding];
}

- (NSURL*) saveWithImage:(UIImage*)image{
    
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *savedImagePath = [self createTempFileNameWithFormat:@"Image-XXXXX" inDirectory:documentsDirectory];
    
    NSData* imageData = UIImageJPEGRepresentation(image, 0.9);
    [imageData writeToFile:savedImagePath atomically:YES];
    
    return [NSURL fileURLWithPath:savedImagePath isDirectory:NO];
}

- (UIImage*) loadImageWith:(NSURL *)imageUrl{
    if (![imageUrl isFileURL]) return nil;
    
    NSData *myData = [NSData dataWithContentsOfFile:[imageUrl path]];
    
    return [UIImage imageWithData:myData];
}

#pragma mark - Send Request
- (void)uploadFileDataWithPost:(NSData*)data fileName:(NSString*)filename mimeType:(NSString*)mimetype success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success progress:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))progress failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure{
    
    // 1. Create `AFHTTPRequestSerializer` which will create your request.
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    
    NSString *url = @"URL";
    
    NSError *error;
    // 2. Create an `NSMutableURLRequest`.
    NSMutableURLRequest *request = [serializer multipartFormRequestWithMethod:kHTTPMethodPOST
                                                                    URLString:url
                                                                   parameters:nil
                                                    constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
                                                        [formData appendPartWithFileData:data
                                                                                    name:@"attachment"
                                                                                fileName:filename
                                                                                mimeType:mimetype];
                                                    } error:&error];
    
    if (!error) {
        // 3. Create and use `AFHTTPRequestOperationManager` to create an `AFHTTPRequestOperation` from the `NSMutableURLRequest` that we just created.
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        [manager.requestSerializer setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        AFHTTPRequestOperation *operation = [manager HTTPRequestOperationWithRequest:request success:success failure:failure];
        operation.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
        // 4. Set the progress block of the operation.
        [operation setUploadProgressBlock:progress];
        
        // 5. Begin!
        [operation start];
    }else{
        NSLog(@"Error:%@",error);
    }
}

- (void)downloadFile:(NSURL*)url saveTo:(NSString*)fullPath success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success progress:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))progress failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure{
    
    [self downloadFile:url withUserName:nil andPassword:nil saveTo:fullPath success:success progress:progress failure:failure];
}

- (void)downloadFile:(NSURL*)url withUserName:(NSString*)userName andPassword:(NSString*)password saveTo:(NSString*)fullPath success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success progress:(void (^)(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite))progress failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure{
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[url query] forHTTPHeaderField:URLCACHE_CACHE_KEY];
    [request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    AFHTTPRequestOperation *operation = [manager HTTPRequestOperationWithRequest:request success:success failure:failure];

    // HTTP Basic Authentication
    if (userName && password) {
        [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:@"userName" password:@"password"];
    }
    [operation setRedirectResponseBlock:^NSURLRequest *(NSURLConnection *connection, NSURLRequest *request, NSURLResponse *redirectResponse) {
        if(redirectResponse == nil)
            return request;
        NSURLRequest *urlRequest = [NSURLRequest requestWithURL:request.URL];
        return  urlRequest;
    }];
    [operation setOutputStream:[NSOutputStream outputStreamToFileAtPath:fullPath append:NO]];
    [operation setDownloadProgressBlock:progress];
    
    [operation start];
}


#pragma mark - Utils

+ (NSArray*)folderFilesAtPath:(NSString*)folderPath withDir:(BOOL)incloud{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSURL * folderURL = [NSURL fileURLWithPath:folderPath];
    NSArray *fileList = [fileManager contentsOfDirectoryAtURL:folderURL
               includingPropertiesForKeys:[NSArray arrayWithObject:NSURLNameKey]
                                  options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsPackageDescendants
                                    error:&error];
    
    NSMutableArray *folderFiles = [NSMutableArray array];
    BOOL isDir;
    for (NSURL *file in fileList) {
        [fileManager fileExistsAtPath:[file path] isDirectory:(&isDir)];
        if (isDir) {
            if (incloud) {
                [folderFiles addObject:file];
            }
            [folderFiles addObjectsFromArray:[self folderFilesAtPath:[file path] withDir:incloud]];
        }else{
            [folderFiles addObject:file];
        }
    }
    return [folderFiles copy];
}

+ (long long) folderSizeAtPath:(NSString*) folderPath{
    return [self _folderSizeAtPath:[folderPath cStringUsingEncoding:NSUTF8StringEncoding]];
}

+ (long long) _folderSizeAtPath: (const char*)folderPath{
    long long folderSize = 0;
    DIR* dir = opendir(folderPath);
    if (dir == NULL) return 0;
    struct dirent* child;
    while ((child = readdir(dir))!=NULL) {
        if (child->d_type == DT_DIR && (
                                        (child->d_name[0] == '.' && child->d_name[1] == 0) || // 忽略目录 .
                                        (child->d_name[0] == '.' && child->d_name[1] == '.' && child->d_name[2] == 0) // 忽略目录 ..
                                        )) continue;
        
        unsigned long folderPathLength = strlen(folderPath);
        char childPath[1024]; // 子文件的路径地址
        stpcpy(childPath, folderPath);
        if (folderPath[folderPathLength-1] != '/'){
            childPath[folderPathLength] = '/';
            folderPathLength++;
        }
        stpcpy(childPath+folderPathLength, child->d_name);
        childPath[folderPathLength + child->d_namlen] = 0;
        if (child->d_type == DT_DIR){ // directory
            folderSize += [self _folderSizeAtPath:childPath]; // 递归调用子目录
            // 把目录本身所占的空间也加上
            struct stat st;
            if(lstat(childPath, &st) == 0) folderSize += st.st_size;
        }else if (child->d_type == DT_REG || child->d_type == DT_LNK){ // file or link
            struct stat st;
            if(lstat(childPath, &st) == 0) folderSize += st.st_size;
        }
    }
    closedir(dir);
    return folderSize;
}

- (NSString *)getIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
    @[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
}

- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

+ (NSInteger)fromDateToAge:(NSDate*)date{
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *comps = [calendar components:NSCalendarUnitYear fromDate:date toDate:[NSDate date] options:0];
    
    return [comps year];
}

@end
