//
//  RingTool.h
//  HandheldBloodDoctor
//
//  Created by fangfei on 2017/3/9.
//  Copyright © 2017年 team. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger , ReadType){

    ReadTypeBattery,  // 电量
    ReadTypeBuffer,   // 缓存
    ReadTypePreference, // 偏好
  
};

@protocol RingToolDelegate <NSObject>

@optional
// 扫面的结果
- (void)searchRingResult:(BOOL)isSearchRing;
// 得到的手环id
- (void)getRingID:(NSString *)ringID;
// 得到的手环的数据
- (void)getRingData:(NSData *)data WithType:(NSString *)type;
// 此时蓝牙的状态
- (void)getBluetoothState:(BOOL)state;
@end


@interface RingTool : NSObject

/**代理*/
@property (nonatomic , strong)id<RingToolDelegate>delegate;

+ (instancetype)shareBluetooth;

// 扫描手环
- (void)scanRing;
// 停止搜索手环
- (void)stopScanRing;
// 发送命令
- (void)sendOrderWithData:(NSData *)data;
// 主动读取值
- (void)readRingValue:(ResType)type;
// 断开连接
- (void)disconnectRing;
@end
