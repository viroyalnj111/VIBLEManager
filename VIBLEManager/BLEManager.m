//
//  BLEManager.m
//
//  Created by 熊国锋 on 2018/2/5.
//  Copyright © 2018年 南京远御网络科技有限公司. All rights reserved.
//

#import "BLEManager.h"

typedef enum : NSUInteger {
    BtCmdStateInit,         // 初始状态
    BtCmdStateSent,         // 已经发送
    BtCmdStateEcho,         // 收到回应
    BtCmdStateFinished      // 处理完毕
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

@property (nonatomic, strong) CBPeripheral      *peripheral;
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
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

- (void)applicationDidBecomeActive:(NSNotification *)noti {
    CBCentralManager *centralManager = self.centralManager;
    if (centralManager.state == CBManagerStatePoweredOn && !centralManager.isScanning) {
        [centralManager scanForPeripheralsWithServices:nil
                                               options:nil];
    }
}

- (void)sendCommand:(NSString *)string withCompletion:(CommonBlock)completion {
    if (!self.connected) {
        if (completion) {
            completion(NO, @{@"error_msg" : @"蓝牙连接已断开"});
        }
        
        return;
    }
    
    BTCommand *cmd = [BTCommand commandWithString:string completion:completion];
    [self.arrCommand addObject:cmd];
    
    [self nextCommand];
}

- (void)nextCommand {
    BTCommand *cmd = self.arrCommand.firstObject;
    if (cmd) {
        if (cmd.state == BtCmdStateInit) {
            [self sendString:cmd.cmdString];
            cmd.state = BtCmdStateSent;
        }
        else if (cmd.state == BtCmdStateFinished) {
            [self.arrCommand removeObjectAtIndex:0];
            
            [self nextCommand];
        }
    }
}

- (void)sendString:(NSString *)string {
    [self writeString:string
           peripheral:self.peripheral
       characteristic:self.characteristic];
}

- (void)setRadioFrequency:(CGFloat)frequency
           withCompletion:(nullable CommonBlock)completion {
    NSString *string = [NSString stringWithFormat:@"AT+FMFREQ=%.0f", frequency * 10];
    [self sendCommand:string
       withCompletion:completion];
}

- (void)answerCallWithCompletion:(nullable CommonBlock)completion {
    [self sendCommand:@"AT+CALLANSW"
       withCompletion:completion];
}

- (void)rejectCallWithCompletion:(nullable CommonBlock)completion {
    [self sendCommand:@"AT+CALLEND"
       withCompletion:completion];
}

- (void)makeCall:(NSString *)number
      completion:(nullable CommonBlock)completion {
    [self sendCommand:[NSString stringWithFormat:@"AT+DIAL=%@", number]
    withCompletion:completion];
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
    
    if ([name length] > 0 && [self.delegate respondsToSelector:@selector(bleManager:shouldPairDeviceWithName:)] &&
        [self.delegate bleManager:self shouldPairDeviceWithName:name]) {
        
        NSLog(@"BLE name: %@ advertisementData: %@", peripheral.name, advertisementData);
        [self.peripherals addObject:peripheral];
        
        // 连接之前，先终止扫描
        [central stopScan];
        [central connectPeripheral:peripheral options:nil];
        
        [self.delegate bleManager:self startToConnectToDevice:peripheral.name];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self.delegate bleManagerDeviceSearchDidFailed:self];
    
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"BLE didConnectPeripheral: %@", peripheral.name);
    
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"BLE didDisconnectPeripheral: %@", peripheral.name);
    
    self.connected = NO;
    self.deviceName = nil;
    self.peripherals = nil;
    
    [self.delegate bleManager:self deviceDidDisconnected:peripheral.name];
    
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *item in peripheral.services) {
        NSLog(@"BLE didDiscoverServices: %@", item.UUID);
        [peripheral discoverCharacteristics:nil forService:item];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *item in service.characteristics) {
        NSLog(@"BLE didDiscoverCharacteristic: %@", item.UUID);
        if (item.properties & CBCharacteristicPropertyWrite || item.properties & CBCharacteristicPropertyWriteWithoutResponse) {
            // 这时候就认为是连接上了，不做其它判断
            self.connected = YES;
            self.deviceName = peripheral.name;
            self.peripheral = peripheral;
            self.characteristic = item;
            self.arrCommand = [NSMutableArray new];
            
            [peripheral setNotifyValue:YES forCharacteristic:item];
            [self.delegate bleManager:self didConnectedToDevice:peripheral.name];
            
            break;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSString *value = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    value = [value stringByReplacingOccurrencesOfString:@"\r\n" withString:@" "];
    
    NSArray *arr = [value componentsSeparatedByString:@" "];
    for (NSString *item in arr) {
        if (item.length == 0) {
            continue;
        }
        
        NSLog(@"BLE >> %@", item);
        BOOL processed = NO;
        for (BTCommand *cmd in self.arrCommand) {
            switch (cmd.state) {
                case BtCmdStateInit: {
                    
                }
                break;
                
                case BtCmdStateSent: {
                    /*
                     * 下发指令是这样 AT+FMFREQ=969
                     * 收到回应是这样 +FMFREQ:969
                     * 此处需要将两者匹配
                     */
                    
                    NSString *tmp = [item stringByReplacingOccurrencesOfString:@":" withString:@"="];
                    tmp = [@"AT" stringByAppendingString:tmp];
                    if ([cmd.cmdString isEqualToString:tmp]) {
                        cmd.state = BtCmdStateEcho;
                        processed = YES;
                    }
                }
                
                break;
                
                case BtCmdStateEcho: {
                    if ([item isEqualToString:@"OK"]) {
                        cmd.state = BtCmdStateFinished;
                        if (cmd.completion) {
                            cmd.completion(YES, @{@"response" : item});
                        }
                        
                        processed = YES;
                    }
                }
                
                break;
                
                default:
                break;
            }
            
            if (processed) {
                break;
            }
        }
        
        if (!processed) {
            // 没有处理，可能是主动上报的命令
            if ([item containsString:@"AT+WAKEUP"]) {
                [self sendString:@"AT+WAKEUP\r\nOK\r\n"];
                
                [self.delegate bleManagerDeviceDidWakeup:self];
            }
        }
    }
    
    [self nextCommand];
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
