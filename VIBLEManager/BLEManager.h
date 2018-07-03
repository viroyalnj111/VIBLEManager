//
//  BLEManager.h
//
//  Created by 熊国锋 on 2018/2/5.
//  Copyright © 2018年 南京远御网络科技有限公司. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

typedef void (^CommonBlock)(BOOL success, NSDictionary * _Nullable info);

@class BLEManager;

@protocol BLEManagerDelegate < NSObject >

// 蓝牙硬件状态改变通知
- (void)bleManager:(BLEManager *)manager stateDidChange:(CBManagerState)state;

// 扫描状态改变通知
- (void)bleManager:(BLEManager *)manager scaningDidChange:(BOOL)scaning;

// 是否配对扫描到的这个设备
- (BOOL)bleManager:(BLEManager *)manager shouldPairDeviceWithName:(NSString *)name;

// 设备配对成功
- (void)bleManager:(BLEManager *)manager devicePaired:(NSString *)name;

// 蓝牙扫描失败
- (void)bleManagerDeviceSearchDidFailed:(BLEManager *)manager;

// 蓝牙设备断开连接
- (void)bleManager:(BLEManager *)manager deviceDidDisconnected:(NSString *)name;

@end

@interface BLEManager : NSObject

@property (nonatomic, weak) id<BLEManagerDelegate>  delegate;

@property (nonatomic, readonly) BOOL                connected;      // 连接状态
@property (nonatomic, readonly) NSString            *deviceName;    // 设备名称

+ (instancetype)manager;

/*
 * 向蓝牙设备发送指令，所有的指令会按照先后顺序，逐条发送，指令处理完成后，会调用 completion
 @param string 指令内容，非空
 @completion 完成回调
 */
- (void)sendCommand:(NSString *)string
     withCompletion:(nullable CommonBlock)completion;

/*
 * 便捷设置电台频率
 */

- (void)setRadioFrequency:(CGFloat)frequency
           withCompletion:(nullable CommonBlock)completion;

@end
