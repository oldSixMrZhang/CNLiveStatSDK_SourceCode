//
//  CNLiveStat.h
//  CNLiveStat
//
//  Created by 雷浩杰 on 2016/11/10.
//  Copyright © 2016年 雷浩杰. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CNLiveStat : NSObject

/*
 * 获取SDK版本号 2.0.0
 */
+ (NSString *)getVersion;

/*
 * 注册APP  注册成功或失败信息以log形式输出（CNLiveStatManager registerApp Success 或者 CNLiveStatManager registerApp Error :）
 
   @param appId AppId
   @param appKey AppKey
 
   此方法默认将统计数据上传到正式环境,如果需要测试SDK,强烈建议用
    + (void)registerApp:(NSString *)appId appKey:(NSString *)appKey isTestEnvironment:(BOOL)isTestEnvironment 方法初始化SDK
 */
+ (void)registerApp:(NSString *)appId appKey:(NSString *)appKey;

/**
 注册APP  注册成功或失败信息以log形式输出（CNLiveStatManager registerApp Success 或者 CNLiveStatManager registerApp Error :）

 @param appId AppId
 @param appKey AppKey
 @param isTestEnvironment 测试环境开关,YES为测试环境,NO为正式环境
 
 */
+ (void)registerApp:(NSString *)appId appKey:(NSString *)appKey isTestEnvironment:(BOOL)isTestEnvironment;

/* 数量统计
 *
 * eventID  事件ID
 *
 */
+ (void)event:(NSString *)eventID;

/* 时长统计  在调用endEvent:方法前，多次使用同一个eventID调用此方法，只会将第一次视为有效调用
 *
 * eventID  事件ID
 *
 */
+ (void)beginEvent:(NSString *)eventID;

/* 时长统计 多次使用同一个eventID调用此方法，只会将第一次视为有效调用
 *
 * eventID  事件ID
 *
 */
+ (void)endEvent:(NSString *)eventID;

/* 直播播放统计
 *
 * channelId  直播channelId
 *
 */
+ (void)statLivePlayerWithChannelId:(NSString *)channelId;

/* 点播播放统计
 *
 * vId     点播vId
 *
 */
+ (void)statVodPlayerWithVId:(NSString *)vId;


+ (void)registerApp:(NSString *)appId appKey:(NSString *)appKey isTestEnvironment:(BOOL)isTestEnvironment version:(NSString *)version eventId:(NSString *)eventId;
@end
