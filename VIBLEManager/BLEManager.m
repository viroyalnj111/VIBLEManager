//
//  BLEManager.m
//
//  Created by 熊国锋 on 2018/2/5.
//  Copyright © 2018年 南京远御网络科技有限公司. All rights reserved.
//

#import "BLEManager.h"

typedef enum : NSUInteger {
    BtCmdStateInit,
    BtCmdStateSent,
    BtCmdStateFinished,
    BtCmdStateFailed
} BtCmdState;

@interface BTCommand : NSObject

@property (nonatomic, copy) NSString        *cmdString;
@property (nonatomic, assign) BtCmdState    state;
@property (nonatomic, copy) CommonBlock     completion;

@end

@implementation BTCommand

+ (instancetype)commandWithString:(NSString *)string completion:(CommonBlock)completion {
    return [[self alloc] initWithString:string completion:completion];
}

- (instancetype)initWithString:(NSString *)string completion:(CommonBlock)completion {
    if (self = [super init]) {
        self.cmdString = string;
        self.state = BtCmdStateInit;
        self.completion = completion;
    }
    
    return self;
}

@end

@interface BLEManager () < CBCentralManagerDelegate, CBPeripheralDelegate >

@property (nonatomic, strong) CBCentralManager  *centralManager;
@property (nonatomic, strong) NSMutableArray    *peripherals;
@property (nonatomic, assign) BOOL              connected;
@property (nonatomic, copy)   NSString          *deviceName;

@property (nonatomic, strong) CBCharacteristic  *characteristic;
@property (nonatomic, copy)   CommonBlock       sendCompletion;
@property (nonatomic, strong) NSMutableArray    *arrCommand;

@end

@implementation BLEManager

+ (instancetype)manager {
    static dispatch_once_t onceToken;
    static BLEManager *client = nil;
    dispatch_once(&onceToken, ^{
        client = [BLEManager new];
    });
    
    return client;
}

- (instancetype)init {
    if (self = [super init]) {
        self.peripherals = [NSMutableArray new];
        
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                   queue:nil
                                                                 options:nil];
        
        [self.centralManager addObserver:self
                              forKeyPath:@"isScanning"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
    }
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"isScanning"]) {
        self.connected = NO;
        self.deviceName = nil;
        
        [self.delegate bleManager:self scaningDidChange:self.centralManager.isScanning];
    }
}

- (void)sendCommand:(NSString *)string withCompletion:(CommonBlock)completion {
    if (!self.connected) {
        if (completion) {
            completion(NO, nil);
        }
        
        return;
    }
    
    BTCommand *cmd = [BTCommand commandWithString:string completion:completion];
    [self.arrCommand addObject:cmd];
    
}

- (void)nextCommand {
    BTCommand *cmd = self.arrCommand.firstObject;
    if (cmd.state == BtCmdStateInit) {
        [self sendString:cmd.cmdString
          withCompletion:^(BOOL success, NSDictionary * _Nullable info) {
              if (success) {
                  // 发送成功
                  cmd.state = BtCmdStateSent;
              }
              else {
                  // 发送失败
                  cmd.state = BtCmdStateFailed;
                  if (cmd.completion) {
                      cmd.completion(NO, nil);
                  }
              }
          }];
    }
    else if (cmd.state == BtCmdStateSent) {
        
    }
    else if (cmd.state == BtCmdStateFinished) {
        [self.arrCommand removeObjectAtIndex:0];
    }
    else {
        NSAssert(NO, @"unhandled case");
    }
}

- (void)sendString:(NSString *)string withCompletion:(nullable CommonBlock)completion {
    if (!self.connected) {
        // 设备没有配对好，报错
        if (completion) {
            completion(NO, nil);
        }
    }
    
    [self writeString:string peripheral:self.peripherals characteristic:self.characteristic];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStatePoweredOn:
            [central scanForPeripheralsWithServices:nil options:nil];
            break;
            
        default:
            [central stopScan];
            break;
    }
    
    [self.delegate bleManager:self stateDidChange:central.state];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSString *name = peripheral.name;
    
    if ([name containsString:@"Q11"]) {
        NSLog(@"name: %@ advertisementData: %@", peripheral.name, advertisementData);
        [self.peripherals addObject:peripheral];
        
        // 连接之前，先终止扫描
        [central stopScan];
        
        [central connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self.delegate bleManagerDeviceSearchDidFailed:self];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"didConnectPeripheral: %@", peripheral.name);
    
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"didDisconnectPeripheral: %@", peripheral.name);
    
    self.connected = NO;
    self.deviceName = nil;
    self.peripherals = nil;
    
    [self.delegate bleManager:self deviceDidDisconnected:peripheral.name];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *item in peripheral.services) {
        NSLog(@"didDiscoverServices: %@", item.UUID);
        [peripheral discoverCharacteristics:nil forService:item];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *item in service.characteristics) {
        NSLog(@"characteristic: %@", item.UUID);
        if (item.properties & CBCharacteristicPropertyWrite || item.properties & CBCharacteristicPropertyWriteWithoutResponse) {
            [self writeString:@"ATQ+FMFREQ=964"
                   peripheral:peripheral
               characteristic:item];
            
            // 这时候就认为是连接上了，不做其它判断
            self.connected = YES;
            self.deviceName = peripheral.name;
            self.peripherals = peripheral;
            self.characteristic = item;
            
            [self.delegate bleManager:self devicePaired:peripheral.name];
            
            // 此时，才能接受指令
            self.arrCommand = [NSMutableArray new];
            
            break;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSString *value = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSLog(@"BLE >> %@", value);
    BTCommand *cmd = self.arrCommand.firstObject;
    if (cmd && cmd.state == BtCmdStateSent) {
        // 目前有正在处理中的命令
        cmd.state = BtCmdStateFinished;
        if (cmd.completion) {
            cmd.completion(YES, @{@"response" : value});
        }
        
        [self nextCommand];
        return;
    }
    
    if ([self.delegate respondsToSelector:@selector(bleManager:dataReceived:)]) {
        [self.delegate bleManager:self dataReceived:characteristic.value];
    }
}

- (void)writeString:(NSString *)string
         peripheral:(CBPeripheral *)peripheral
     characteristic:(CBCharacteristic *)characteristic {
    
    NSLog(@"BLE << %@", string);
    [self writeData:[string dataUsingEncoding:NSUTF8StringEncoding]
         peripheral:peripheral
     characteristic:characteristic];
}

- (void)writeData:(NSData *)data
       peripheral:(CBPeripheral *)peripheral
   characteristic:(CBCharacteristic *)characteristic {
    [peripheral writeValue:data
         forCharacteristic:characteristic
                      type:CBCharacteristicWriteWithResponse];
    
    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (self.sendCompletion) {
        self.sendCompletion(error == nil, nil);
    }
}

@end
