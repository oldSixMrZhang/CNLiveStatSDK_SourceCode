//
//  CNLiveStat.m
//  CNLiveStat
//
//  Created by 雷浩杰 on 2016/11/10.
//  Copyright © 2016年 雷浩杰. All rights reserved.
//

#import "CNLiveStat.h"
#import "CNLiveStatManager.h"
#import <UIKit/UIKit.h>
#import "CommonCrypto/CommonDigest.h"
#import <AdSupport/AdSupport.h>

#define kSVer @"4.0"  //探针版本

#define vodUrl @"http://api.cnlive.com/open/api2/vod_ips/vodplayByAPP"
#define liveUrl @"http://api.cnlive.com/open/api2/live_ips/liveplayByAPP"

#define testStatUrl @"http://app.sta.cnlive.com/app.jpg"
#define formalStatUrl @"http://app.sta.cnlive.com/app.jpg"

@implementation CNLiveStat

+ (NSString *)getVersion
{
    return [[CNLiveStatManager manager] getVersion];
}

+ (void)registerApp:(NSString *)appId appKey:(NSString *)appKey
{
    [CNLiveStatManager manager].appId = appId;
    [CNLiveStatManager manager].appKey = appKey;
    [CNLiveStatManager manager].isTestEnvironment = NO;
    [[CNLiveStatManager manager] registerApp:NULL];
}

+ (void)registerApp:(NSString *)appId appKey:(NSString *)appKey isTestEnvironment:(BOOL)isTestEnvironment
{
    [CNLiveStatManager manager].appId = appId;
    [CNLiveStatManager manager].appKey = appKey;
    [CNLiveStatManager manager].isTestEnvironment = isTestEnvironment;
    [[CNLiveStatManager manager] registerApp:NULL];
}

+ (void)registerApp:(NSString *)appId appKey:(NSString *)appKey isTestEnvironment:(BOOL)isTestEnvironment version:(NSString *)version eventId:(NSString *)eventId
{
    [CNLiveStatManager manager].appId = appId;
    [CNLiveStatManager manager].appKey = appKey;
    [CNLiveStatManager manager].isTestEnvironment = isTestEnvironment;
    [[CNLiveStatManager manager] registerApp:NULL];
}

+ (void)event:(NSString *)eventID
{
    [[CNLiveStatManager manager] event:eventID];
}

+ (void)event:(NSString *)eventID SDKVersion:(NSString *)SDKVersion
{
    [[CNLiveStatManager manager] event:eventID];
}

+ (void)beginEvent:(NSString *)eventID
{
    [[CNLiveStatManager manager] beginEvent:eventID];
}

+ (void)endEvent:(NSString *)eventID
{
    [[CNLiveStatManager manager] endEvent:eventID];
}

+ (void)statLivePlayerWithChannelId:(NSString *)channelId
{
    if (!channelId || ![channelId isKindOfClass:[NSString class]] || [channelId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
        channelId = @"";
    }
    [self getRealTimeString:^(NSString * _Nullable realTime, NSDate * _Nullable date) {
        NSString *timeString = realTime;
        NSDictionary *parameter = @{@"appId": [CNLiveStatManager manager].appId,
                                    @"channelId": channelId,
                                    @"timestamp": timeString,
                                    @"platform_id": [NSBundle mainBundle].bundleIdentifier,
                                    @"uid": [self uidForStat:realTime],
                                    @"onlylog": @"1"};
        NSString *string = [NSString stringWithFormat:@"%@&key=%@", [self signvalue:parameter], [CNLiveStatManager manager].appKey];
        NSString *signString = [[self sha1:string] uppercaseString];
        
        NSString *videourl = [NSString stringWithFormat:@"%@?%@&sign=%@", liveUrl, [self signvalue:parameter], signString];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:videourl]];
        [NSURLConnection connectionWithRequest:urlRequest delegate:nil];
    }];
}

+ (void)statVodPlayerWithVId:(NSString *)vId
{
    if (!vId || ![vId isKindOfClass:[NSString class]] || [vId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
        vId = @"";
    }
    
    [self getRealTimeString:^(NSString * _Nullable realTime, NSDate * _Nullable date) {
        NSString *timeString = realTime;
        NSDictionary *parameter = @{@"appId": [CNLiveStatManager manager].appId,
                                    @"vId": vId,
                                    @"timestamp": timeString,
                                    @"platform_id": [NSBundle mainBundle].bundleIdentifier,
                                    @"uid": [self uidForStat:realTime],
                                    @"onlylog": @"1"};
        NSString *string = [NSString stringWithFormat:@"%@&key=%@", [self signvalue:parameter], [CNLiveStatManager manager].appKey];
        NSString *signString = [[self sha1:string] uppercaseString];
        
        NSString *videourl = [NSString stringWithFormat:@"%@?%@&sign=%@", vodUrl, [self signvalue:parameter], signString];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:videourl]];
        [NSURLConnection connectionWithRequest:urlRequest delegate:nil];
    }];
}

#pragma mark - sign tools method
+ (nullable NSString *)uidForStat:(NSString *)dateStr {
    
    NSString *uid = @"";
    
    NSUserDefaults *defauts = [NSUserDefaults standardUserDefaults];
    NSString *keyStr = @"kCNLiveUserDefaultsUIDKey";
    if ([defauts objectForKey:keyStr]) {
        uid = [[defauts objectForKey:keyStr] copy];
        return uid;
    }
    else {
        
        NSString *stamp = dateStr;
        stamp = [stamp stringByReplacingOccurrencesOfString:@"." withString:@""];
        
        NSString *idfv = [[[[UIDevice currentDevice] identifierForVendor] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
        uid = [NSString stringWithFormat:@"%@_%@", idfv, stamp];
        
        [defauts setObject:uid forKey:keyStr];
        [defauts synchronize];
    }
    
    return uid;
}

+ (NSString*)sha1:(NSString *)string
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (int)data.length, digest);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    while ([[output substringToIndex:1] isEqualToString:@"0"]) {
        output = [[NSMutableString alloc] initWithString:[output substringFromIndex:1]];
    }
    
    return output;
}

+ (NSString *)signvalue:(NSDictionary*)parameter
{
    //对所有传入参数按照字段名的 ASCII 码从小到大排序
    NSArray *keyArr=[parameter allKeys];
    NSArray *arr = [keyArr sortedArrayUsingSelector:@selector(compare:)];
    
    NSMutableString *string1 = [[NSMutableString alloc]init];
    for (int i=0; i<arr.count; i++) {
        
        NSString *parameterString = parameter[[arr objectAtIndex:i]];
        if (parameterString.length > 0) {
            [string1 appendString:[NSString stringWithFormat:@"%@=%@&",[arr objectAtIndex:i],parameter[[arr objectAtIndex:i]]]];
        }
    }
    
    if (string1.length > 0) {
        [string1 deleteCharactersInRange:NSMakeRange(string1.length-1, 1)];
    }
    
    return string1;
}

+ (void)getRealTimeString:(void (^)(NSString * __nullable realTime,NSDate * __nullable date))realTime
{
    NSInteger time = [[NSDate date] timeIntervalSince1970];
    NSString *timeString = [NSString stringWithFormat:@"%ld", (long)time];
    dispatch_async(dispatch_get_main_queue(), ^{
        realTime(timeString,[NSDate date]);
    });
}

@end
