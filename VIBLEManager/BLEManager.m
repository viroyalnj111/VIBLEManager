//
//  BLEManager.m
//
//  Created by 熊国锋 on 2018/2/5.
//  Copyright © 2018年 南京远御网络科技有限公司. All rights reserved.
//

#import "BLEManager.h"

typedef enum : NSUInteger {
    BtCmdStateInit,         // 初始状态
    BtCmdStateSending,      // 发送中
    BtCmdStateSent,         // 已经发送
    BtCmdStateEcho,         // 收到回应
    BtCmdStateFailed,       // 处理完毕
    BtCmdStateFinished      // 处理完毕
} BtCmdState;

@interface BTCommand : NSObject

@property (nonatomic, copy) NSString        *cmdString;
@property (nonatomic, assign) BtCmdState    state;
@property (nonatomic, copy) CommonBlock     completion;
@property (nonatomic, copy) NSDate          *date;

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

@property (nonatomic, strong) CBPeripheral      *peripheral;
@property (nonatomic, strong) CBCharacteristic  *characteristic;
@property (nonatomic, strong) NSMutableArray    *arrCommand;
@property (nonatomic, assign) BOOL              connecting;
@property (nonatomic, assign) BOOL              powerOn;

@property (nonatomic, copy)   NSUUID            *serviceID;

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
        self.serviceID = @"FF10";
        
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                   queue:nil
                                                                 options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
        
        [self.centralManager addObserver:self
                              forKeyPath:@"isScanning"
                                 options:NSKeyValueObservingOptionNew
                                 context:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioSessionRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:[AVAudioSession sharedInstance]];
    }
    
    return self;
}

- (BOOL)scaning {
    return self.centralManager.isScanning;
}

- (BOOL)connected {
    return self.centralManager.state == CBManagerStatePoweredOn && self.peripheral && self.characteristic;
}

- (NSString *)deviceName {
    return self.connected?self.peripheral.name:nil;
}

- (NSString *)currentRouteName {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    AVAudioSessionPortDescription *port = session.currentRoute.outputs.firstObject;
    return port.portName;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"isScanning"]) {
        NSNumber *value = change[NSKeyValueChangeNewKey];
        BOOL scaning = [value boolValue];
        NSLog(@"BLE scaning: %@", scaning?@"ON":@"OFF");
        [self.delegate bleManager:self scaningDidChange:scaning];
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)noti {
    CBCentralManager *centralManager = self.centralManager;
    if (!self.connected && self.serviceID) {
        CBPeripheral *peripheral = [self.centralManager retrieveConnectedPeripheralsWithServices:@[self.serviceID]].firstObject;
        if (peripheral) {
            // 目前已经有连上的设备
            CBService *service = peripheral.services.firstObject;
            CBCharacteristic *characteristic = service.characteristics.firstObject;
            if (service && characteristic) {
                NSLog(@"BLE service: %@, characteristic: %@", service, characteristic.UUID);
                
                self.peripheral = peripheral;
                self.characteristic = characteristic;
                self.arrCommand = [NSMutableArray new];
                
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                [self.delegate bleManager:self didConnectedToDevice:peripheral.name];
            }
        }
    }
    
    if (centralManager.state == CBManagerStatePoweredOn && !centralManager.isScanning && !self.connected && !self.connecting) {
        [self startScan];
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)noti {
    [self.centralManager stopScan];
}

- (void)audioSessionRouteChange:(NSNotification *)noti {
    AVAudioSessionRouteDescription *preRoute = noti.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate audioSessionChangeFrom:preRoute to:[AVAudioSession sharedInstance].currentRoute];
    });
}

- (void)startScan {
    [self.centralManager scanForPeripheralsWithServices:nil
                                                options:nil];
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
            cmd.state = BtCmdStateSending;
            cmd.date = [NSDate date];
        }
        else if (cmd.state == BtCmdStateFinished) {
            [self.arrCommand removeObjectAtIndex:0];
            
            [self nextCommand];
        }
        else {
            if (cmd.state == BtCmdStateFailed || [[NSDate date] timeIntervalSinceDate:cmd.date] > 3) {
                // 发送失败或者超时，直接移除
                [self.arrCommand removeObjectAtIndex:0];
                if (cmd.completion) {
                    cmd.completion(NO, @{@"error_msg" : @"蓝牙连接已断开"});
                }
                
                [self nextCommand];
            }
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
            [self startScan];
            break;
            
        default:
            break;
    }
    
    self.powerOn = central.state == CBManagerStatePoweredOn;
    
    // 硬件电源状态改变，连接全部失效
    self.peripheral = nil;
    
    [self.delegate bleManager:self stateDidChange:central.state];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSString *name = peripheral.name;
    
    if ([name length] > 0
        && !self.connected
        && [self.delegate respondsToSelector:@selector(bleManager:shouldPairDeviceWithName:)]
        && [self.delegate bleManager:self shouldPairDeviceWithName:name]) {
        
        NSLog(@"BLE didDiscoverPeripheral: %@", peripheral);
        [self.peripherals addObject:peripheral];
        
        // 连接之前，先终止扫描
        [central stopScan];
        
        self.connecting = YES;
        [central connectPeripheral:peripheral options:nil];
        
        [self.delegate bleManager:self startToConnectToDevice:peripheral.name];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self.delegate bleManager:self didFailedConnectingToDevice:peripheral.name];
    self.connecting = NO;
    
    [self startScan];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"BLE didConnectPeripheral: %@", peripheral.name);
    
    self.connecting = NO;
    
    if (self.peripheral) {
        // 可能已经有连上的 BLE，此处断开，以避免多个连接
        [self.centralManager cancelPeripheralConnection:self.peripheral];
    }
    
    self.peripheral = peripheral;
    
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"BLE didDisconnectPeripheral: %@", peripheral.name);
    
    self.connecting = NO;
    if (self.peripheral == peripheral) {
        self.peripheral = nil;
        
        [self.delegate bleManager:self deviceDidDisconnected:peripheral.name];
    }
    
    [self startScan];
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
        // 这时候就认为是连接上了，不做其它判断
        NSLog(@"BLE characteristic: %@", item.UUID);
        
        self.characteristic = item;
        self.arrCommand = [NSMutableArray new];
        
        self.serviceID = service.UUID;
        
        [peripheral setNotifyValue:YES forCharacteristic:item];
        [self.delegate bleManager:self didConnectedToDevice:peripheral.name];
        
        break;
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
    BTCommand *cmd = self.arrCommand.firstObject;
    if (cmd && cmd.state == BtCmdStateSending) {
        if (!error) {
            cmd.state = BtCmdStateSent;
        }
        else {
            // 写入失败
            cmd.state = BtCmdStateFailed;
        }
    }
    
    [self nextCommand];
}

@end
