//
//  CNLiveStatManager.m
//  CNLiveStat
//
//  Created by 雷浩杰 on 2016/11/10.
//  Copyright © 2016年 雷浩杰. All rights reserved.
//

#import "CNLiveStatManager.h"
#import <UIKit/UIKit.h>
#import "CommonCrypto/CommonDigest.h"

#define CNLiveFormalStatUrl @"http://do.sta.cnlive.com/do.jpg"
#define CNLiveTestStatUrl @"http://do.sta.cnlive.com/do.jpg"

#define CNLiveUserDefaults [NSUserDefaults standardUserDefaults]

//// 在初始化SDK时将 总数据拆分为 临时1块数据+临时剩余数据
//// 1块数据暂定10个event
#define CNLiveEventsKey @"CNLiveEventsKey"//总数据 10+n
#define CNLiveStatSDKTempPieceEventsKey @"CNLiveStatSDKTempPieceEventsKey"//临时1块数据 10
#define CNLiveStatSDKTempRemainEventsKey @"CNLiveStatSDKTempRemainEventsKey"//临时剩余数据 n
#define CNLiveStatEventPiece 10

#define CNLivekSVer @"1.0"
#define CNLiveSDKVersion @"2.0.0"  //SDK版本
#define CNLiveStatAppVersion  ([[[NSBundle mainBundle] infoDictionary] objectForKey: @"CFBundleShortVersionString"])

/**
 *  weakSelf
 */
#ifndef weakselfStat
#define weakselfStat __weak typeof(self)weakSelf = self;
#endif
/**
 *  strongSelf
 */
#ifndef strongselfStat
#define strongselfStat __strong typeof(weakSelf)self = weakSelf;
#endif

@interface CNLiveStatManager ()
{
    BOOL _requesting;          //是否正在检测
    BOOL _isAppResignActive;   //是否进入后台
}

@property (nonatomic, strong)NSMutableDictionary *beginEvents;
@property (nonatomic, assign)BOOL check;

@property (nonatomic, strong)NSMutableArray *totalEvents;//本地所有事件
@property (nonatomic, strong)NSMutableArray *pieceEvents;//临时一块事件
@property (nonatomic, strong)NSMutableArray *remainEvents;//临时剩余事件
@property (nonatomic, strong)NSMutableArray *tempRemainEvents;//进入后台时临时将上报的事件去掉为temp临时剩余事件,如果上报成功则替换tempRemainEvents为remainEvents,如果上报失败则清空tempRemainEvents

@property (nonatomic, assign)BOOL isUploading;   //是否正在上报,保证没有上报重复事件

@end

@implementation CNLiveStatManager

+ (CNLiveStatManager *)manager
{
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:instance selector:@selector(appResignActive) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:instance selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    });
    
    return instance;
}

- (NSString *)getVersion
{
    return CNLiveSDKVersion;
}

- (NSMutableDictionary *)beginEvents
{
    if (!_beginEvents)
    {
        _beginEvents = [[NSMutableDictionary alloc] init];
    }
    return _beginEvents;
}

- (NSMutableArray *)totalEvents
{
    if (!_totalEvents)
    {
        _totalEvents = [[NSMutableArray alloc] initWithArray:[CNLiveUserDefaults objectForKey:CNLiveEventsKey]];
    }
    return _totalEvents;
}

- (NSMutableArray *)pieceEvents
{
    if (!_pieceEvents)
    {
        _pieceEvents = [[NSMutableArray alloc] init];
    }
    return _pieceEvents;
}

- (NSMutableArray *)remainEvents
{
    if (!_remainEvents)
    {
        _remainEvents = [[NSMutableArray alloc] init];
    }
    return _remainEvents;
}

- (NSMutableArray *)tempRemainEvents
{
    if (!_tempRemainEvents)
    {
        _tempRemainEvents = [[NSMutableArray alloc] init];
    }
    return _tempRemainEvents;
}

#pragma mark - 检测appId、appKey、BundleID是否匹配
- (void)registerApp:(void (^)(void))authSuccessBlock
{
    if (_requesting) {
        return;
    }
    
    _requesting = YES;
    
    [self getRealTimeString:^(NSString * _Nullable realTime, NSDate * _Nullable date) {
        NSString *timeString = realTime;
        
        NSDictionary *parameter = @{@"platform_id": [NSBundle mainBundle].bundleIdentifier,
                                    @"timestamp": timeString,
                                    @"appId": self.appId};
        NSString *string = [NSString stringWithFormat:@"%@&key=%@", [self signvalue:parameter], self.appKey];
        NSString *signString = [[self sha1:string] uppercaseString];
        
        NSString *urlString = [NSString stringWithFormat:@"%@?%@&sign=%@", @"http://api.cnlive.com/open/api2/platform/valid", [self signvalue:parameter], signString];
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
        request.HTTPMethod = @"GET";
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                self->_requesting = NO;
                
                if (data) {
                    
                    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                    if ([[NSString stringWithFormat:@"%@", dic[@"errorCode"]] isEqualToString:@"0"]) {
                        
                        [CNLiveStatManager manager].check = YES;
                        NSLog(@"CNLiveStatManager registerApp Success");
                        if (authSuccessBlock) {
                            authSuccessBlock();
                        }
                        
                    } else {
                        [CNLiveStatManager manager].check = NO;
                        NSLog(@"CNLiveStatManager registerApp Error : %@", dic);
                    }
                } else {
                    [CNLiveStatManager manager].check = NO;
                    NSDictionary *errorDic = @{@"errorCode": [NSString stringWithFormat:@"%ld", error.code], @"errorMessage": error.localizedDescription};
                    NSLog(@"CNLiveStatManager registerApp Error : %@", errorDic);
                    
                }
            });
            
        }];
        [task resume];
    }];
}

- (NSString*)sha1:(NSString *)string
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

- (NSString *)signvalue:(NSDictionary*)parameter
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

#pragma mark - event事件
- (void)event:(NSString *)eventID
{
    NSMutableArray *events = [[NSMutableArray alloc] initWithArray:[CNLiveUserDefaults objectForKey:CNLiveEventsKey]];
    [events addObject:@{@"eventID": eventID, @"duration": @0}];
    [self setLocalTotalEventWith:events];
    [self breakUpTempEvents];
}

- (void)beginEvent:(NSString *)eventID
{
    if (!self.beginEvents[eventID]) {
        [self getRealTimeString:^(NSString * _Nullable realTime, NSDate * _Nullable date) {
            [self.beginEvents setObject:date forKey:eventID];
        }];
    }
}

- (void)endEvent:(NSString *)eventID
{
    if ([self.beginEvents.allKeys containsObject:eventID]) {
        NSDate *beginDate = self.beginEvents[eventID];
        [self.beginEvents removeObjectForKey:eventID];
        
        NSDate *date = [NSDate date];
        NSInteger duration = [date timeIntervalSinceDate:beginDate];
        
        NSMutableArray *events = [[NSMutableArray alloc] initWithArray:[CNLiveUserDefaults objectForKey:CNLiveEventsKey]];
        [events addObject:@{@"eventID": eventID, @"duration": @(duration)}];
        [self setLocalTotalEventWith:events];
        if (!self->_isAppResignActive) {
            [self breakUpTempEvents];
        }else
        {
            [self breakUpEvents];
        }
    }
}

#pragma mark - Private Methods
#pragma mark - UIApplicationWillResignActiveNotification
- (void)appResignActive
{
    _isAppResignActive = YES;
    if (_check) {
        [self breakUpTempEvents];
    } else {
        [self registerApp:^{
            [self breakUpTempEvents];
        }];
    }
}

- (void)didBecomeActive
{
    _isAppResignActive = NO;
}

//#pragma mark - 上传统计数据
//- (void)uploadData
//{
//    NSMutableArray *events = [[NSMutableArray alloc] initWithArray:[CNLiveUserDefaults objectForKey:CNLiveEventsKey]];
//    if (events.count <= 0) {
//        return;
//    }
//    NSMutableString *eventsString = [[NSMutableString alloc] init];
//    for (NSDictionary *dic in events) {
//        [eventsString appendFormat:@"%@_%@|", dic[@"eventID"], [NSString stringWithFormat:@"%@", dic[@"duration"]]];
//    }
//    [eventsString deleteCharactersInRange:NSMakeRange(eventsString.length-1, 1)];
//
//    NSString *envirUrl = CNLiveFormalStatUrl;
//    if (self.isTestEnvironment) {
//        envirUrl = CNLiveTestStatUrl;
//    }
//
//    NSString *urlString = [NSString stringWithFormat:@"%@?sver=%@&appid=%@&version=1006_%@&eventid=%@&uri=&plat=i_%@&phone=%@&device=%@", envirUrl, CNLivekSVer, self.appId, CNLiveSDKVersion, eventsString, CNLiveStatAppVersion, [UIDevice currentDevice].model, [UIDevice currentDevice].name];
//    urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//    NSURL *url = [NSURL URLWithString:urlString];
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
//    request.HTTPMethod = @"GET";
//    NSURLSession *session = [NSURLSession sharedSession];
//    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
//            NSHTTPURLResponse *httpURLResponse = (NSHTTPURLResponse *)response;
//            if (httpURLResponse.statusCode == 200 || httpURLResponse.statusCode == 304) {
//                [CNLiveUserDefaults removeObjectForKey:CNLiveEventsKey];
//                [CNLiveUserDefaults synchronize];
//            }
//        }
//    }];
//    [task resume];
//}

- (void)getRealTimeString:(void (^)(NSString * __nullable realTime,NSDate * __nullable date))realTime
{
    NSInteger time = [[NSDate date] timeIntervalSince1970];
    NSString *timeString = [NSString stringWithFormat:@"%ld", (long)time];
    dispatch_async(dispatch_get_main_queue(), ^{
        realTime(timeString,[NSDate date]);
    });
}

//拆分 总事件为 块events和剩余events
- (void)breakUpEvents
{
    NSMutableArray *totalEvents = self.totalEvents;
    if (totalEvents == nil || totalEvents.count == 0) {
        return;
    }
    
    NSMutableArray *tempPieceEvents = self.pieceEvents;
    
    NSInteger totalCount = totalEvents.count;
    if (totalCount < CNLiveStatEventPiece)
    {
        if (_isAppResignActive)
        {//进入后台上传
            
        }else
        {//本地没有统计event<30 不处理;
            
        }
        NSMutableArray *remainEvents = [NSMutableArray arrayWithArray:totalEvents];
        [self setTempRemainEventWith:remainEvents];
    }else
    {//本地event>=30
        if (tempPieceEvents.count <= 0)
        {//没有临时块event,拆分出一块临时
            NSMutableArray *pieceEvents = [NSMutableArray arrayWithArray:[totalEvents subarrayWithRange:NSMakeRange(0, CNLiveStatEventPiece)]];
            [self setTempPieceEventWith:pieceEvents];
            
            NSMutableArray *remainEvents = [NSMutableArray arrayWithArray:[totalEvents subarrayWithRange:NSMakeRange(CNLiveStatEventPiece, totalCount - CNLiveStatEventPiece)]];
            [self setTempRemainEventWith:remainEvents];
        }else
        {//有临时块event 不处理
            NSMutableArray *remainEvents = [NSMutableArray arrayWithArray:[totalEvents subarrayWithRange:NSMakeRange(CNLiveStatEventPiece, totalCount - CNLiveStatEventPiece)]];
            [self setTempRemainEventWith:remainEvents];
        }
    }
}

/**
 拆分events事件为对应的临时events 30+n --> 30 + n
 更新本地临时块 和 本地剩余块
 */
- (void)breakUpTempEvents
{
    [self breakUpEvents];
    [self uploadDataIfNeed];
}

#pragma mark -上传统计数据新,分成30条/次
- (void)uploadDataIfNeed
{
    NSMutableArray *tempPieceEvents = [self getTempPieceEvent];
    
    NSMutableArray *totalArray = [self getLocalTotalEvent];
    NSInteger totalEventsCount = totalArray.count;
    
    if (totalEventsCount < CNLiveStatEventPiece)
    {
        if (_isAppResignActive&& !_isUploading) {//
            //如果切换后台就直接上报所有本地数据,否则不上报
            [self uploadEventsWithArray:totalArray];
        }
    }else
    {
        NSInteger tempPieceEventsCount = tempPieceEvents.count;
        if (tempPieceEventsCount == CNLiveStatEventPiece&& !_isUploading)
        {
            [self uploadEventsWithArray:tempPieceEvents];
        }
    }
}

- (void)uploadEventsWithArray:(NSMutableArray *)array
{
    //上传一块数据
    //成功: 将本地剩余块->本地 ,本地临时块->nil,本地剩余块->nil ,重新拆分3个块
    //失败: 不处理
    //更新本地临时块 和 本地剩余块
    if (array == nil || array.count == 0) {
        return;
    }
    
    _isUploading = YES;
    NSMutableString *eventsString = [[NSMutableString alloc] init];
    for (NSDictionary *dic in array) {
        [eventsString appendFormat:@"%@_%@|", dic[@"eventID"], [NSString stringWithFormat:@"%@", dic[@"duration"]]];
    }
    [eventsString deleteCharactersInRange:NSMakeRange(eventsString.length-1, 1)];
    
    NSString *envirUrl = CNLiveFormalStatUrl;
    
    NSString *urlString = [NSString stringWithFormat:@"%@?sver=%@&appid=%@&version=1006_%@&eventid=%@&uri=&plat=i_%@&from=apple&phone=%@&device=%@", envirUrl, CNLivekSVer, self.appId, CNLiveSDKVersion, eventsString, CNLiveStatAppVersion, [UIDevice currentDevice].model, [UIDevice currentDevice].name];
    urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30];
    request.HTTPMethod = @"GET";
    NSURLSession *session = [NSURLSession sharedSession];
    self.tempRemainEvents = [self getTempRemainEvent];
    weakselfStat
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        weakSelf.isUploading = NO;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpURLResponse = (NSHTTPURLResponse *)response;
            if (httpURLResponse.statusCode == 414) {
                //414时,清空本地所有事件,在听云上查看
                [self setLocalTotalEventWith:nil];
                [self setTempPieceEventWith:nil];
                [self setTempRemainEventWith:nil];
            }
            if (httpURLResponse.statusCode == 200 || httpURLResponse.statusCode == 304) {
                //成功: 将本地剩余块->本地 ,本地临时块->nil,本地剩余块->nil ,重新拆分3个块
                //失败: 不处理
                NSMutableArray *tempTotalArr;
                if (self.totalEvents.count < CNLiveStatEventPiece)
                {
                    tempTotalArr = self.totalEvents.mutableCopy;
                    if (tempTotalArr.count >= self.tempRemainEvents.count) {
                        [tempTotalArr removeObjectsInRange:NSMakeRange(0, self.tempRemainEvents.count)];
                    }
                }else
                {
                    tempTotalArr = [self getTempRemainEvent];
                }
                
                [self setLocalTotalEventWith:tempTotalArr];
                [self setTempPieceEventWith:nil];
                [self setTempRemainEventWith:nil];
                //更新本地临时块 和 本地剩余块
                [self breakUpEvents];
            }
        }
        self.tempRemainEvents = [NSMutableArray array];
    }];
    [task resume];
}

//获取本地临时块数组
- (NSMutableArray *)getTempPieceEvent
{
    NSMutableArray *tempPieceEvents = self.pieceEvents;
    if (tempPieceEvents.count <= 0 || tempPieceEvents == nil) {
        return [NSMutableArray array];
    }else
    {
        return tempPieceEvents;
    }
}

//获取本地剩余块数组
- (NSMutableArray *)getTempRemainEvent
{
    NSMutableArray *tempRemainEvents = self.remainEvents;
    if (tempRemainEvents.count <= 0 || tempRemainEvents == nil) {
        return [NSMutableArray array];
    }else
    {
        return tempRemainEvents;
    }
}

//获取本地所有数组
- (NSMutableArray *)getLocalTotalEvent
{
    NSMutableArray *totalEvents = self.totalEvents;
    if (totalEvents.count <= 0 || totalEvents == nil) {
        return [NSMutableArray array];
    }else
    {
        return totalEvents;
    }
}

//设置本地临时块为新array
- (void)setTempPieceEventWith:(NSMutableArray *)array
{
    if (array == nil || array.count == 0) {
        self.pieceEvents = [NSMutableArray array];
    }else
    {
        self.pieceEvents = array.mutableCopy;
    }
    [CNLiveUserDefaults setObject:self.pieceEvents forKey:CNLiveStatSDKTempPieceEventsKey];
    [CNLiveUserDefaults synchronize];
}

//设置本地剩余块为新array
- (void)setTempRemainEventWith:(NSMutableArray *)array
{
    if (array == nil || array.count == 0) {
        self.remainEvents = [NSMutableArray array];
    }else
    {
        self.remainEvents = array.mutableCopy;
    }
    [CNLiveUserDefaults setObject:self.remainEvents forKey:CNLiveStatSDKTempRemainEventsKey];
    [CNLiveUserDefaults synchronize];
}

//设置本地所有块为新array
- (void)setLocalTotalEventWith:(NSMutableArray *)array
{
    if (array == nil || array.count == 0) {
        self.totalEvents = [NSMutableArray array];
    }else
    {
        self.totalEvents = array.mutableCopy;
    }
    [CNLiveUserDefaults setObject:self.totalEvents forKey:CNLiveEventsKey];
    [CNLiveUserDefaults synchronize];
}
@end
