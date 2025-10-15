//
//  CNLiveStatManager.h
//  CNLiveStat
//
//  Created by 雷浩杰 on 2016/11/10.
//  Copyright © 2016年 雷浩杰. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CNLiveStatManager : NSObject

@property (nonatomic, copy)NSString *appId;
@property (nonatomic, copy)NSString *appKey;
@property (nonatomic, assign)BOOL isTestEnvironment;

//其他SDK内部用
//@property (nonatomic, copy)NSString *sdkVersion;

+ (CNLiveStatManager *)manager;

- (NSString *)getVersion;

- (void)registerApp:(void(^)(void))authSuccessBlock;

- (void)event:(NSString *)eventID;

- (void)beginEvent:(NSString *)eventID;

- (void)endEvent:(NSString *)eventID;

@end
