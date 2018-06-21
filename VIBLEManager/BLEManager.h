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

@optional

- (void)bleManager:(BLEManager *)manager stateDidChange:(CBManagerState)state;

- (void)bleManager:(BLEManager *)manager scaningDidChange:(BOOL)scaning;

- (void)bleManager:(BLEManager *)manager devicePaired:(NSString *)name;

- (void)bleManagerDeviceSearchDidFailed:(BLEManager *)manager;

- (void)bleManager:(BLEManager *)manager deviceDidDisconnected:(NSString *)name;

- (void)bleManager:(BLEManager *)manager dataReceived:(NSData *)data;

@end

@interface BLEManager : NSObject

@property (nonatomic, weak) id<BLEManagerDelegate>   delegate;
@property (nonatomic, readonly, getter=isPairing) BOOL                pairing;
@property (nonatomic, readonly) NSString            *deviceName;

+ (instancetype)manager;

- (void)sendCommand:(NSString *)string
     withCompletion:(nullable CommonBlock)completion;

@end
