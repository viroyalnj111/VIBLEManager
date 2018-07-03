//
//  ViewController.m
//  VIBLEManager
//
//  Created by fanliangliang441 on 07/03/2018.
//  Copyright (c) 2018 fanliangliang441. All rights reserved.
//

#import "ViewController.h"
#import <VIBLEManager/BLEManager.h>
#import <Masonry/Masonry.h>

@interface LogCell : UITableViewCell

@property (nonatomic, copy) NSString        *message;

@end

@implementation LogCell

+ (NSString *)reuseIdentifier {
    return NSStringFromClass(self);
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        
    }
    
    return self;
}

- (void)setMessage:(NSString *)message {
    self.textLabel.text = message;
}

@end

@interface ViewController () < BLEManagerDelegate, UITableViewDataSource, UITableViewDelegate >

@property (nonatomic, strong) UITableView       *tableView;
@property (nonatomic, strong) NSMutableArray    *logData;

@end

@implementation ViewController

- (void)loadView {
    UIView *view = [UIView new];
    view.backgroundColor = [UIColor grayColor];
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    tableView.dataSource = self;
    tableView.delegate = self;
    [view addSubview:tableView];
    [tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(view);
        make.top.equalTo(view);
        make.right.equalTo(view);
    }];
    
    tableView.tableFooterView = [UIView new];
    [tableView registerClass:[LogCell class]
      forCellReuseIdentifier:[LogCell reuseIdentifier]];
    
    UIToolbar *toolBar = [UIToolbar new];
    UIBarButtonItem *fm = [[UIBarButtonItem alloc] initWithTitle:@"设置调频"
                                                           style:UIBarButtonItemStyleDone
                                                          target:self
                                                          action:@selector(bleSetFM)];
    
    UIBarButtonItem *acceptCall = [[UIBarButtonItem alloc] initWithTitle:@"接听来电"
                                                                   style:UIBarButtonItemStyleDone
                                                                  target:self
                                                                  action:@selector(acceptCall)];
    
    toolBar.items = @[fm, acceptCall];
    
    [view addSubview:toolBar];
    [toolBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(view);
        make.right.equalTo(view);
        make.top.equalTo(tableView.mas_bottom).offset(8);
        make.bottom.equalTo(view).offset(-8);
        make.height.equalTo(@48);
    }];
    
    self.view = view;
    self.tableView = tableView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"指令调试";
    
    self.logData = [NSMutableArray new];
    
    [BLEManager manager].delegate = self;
}

- (void)bleSetFM {
    [[BLEManager manager] setRadioFrequency:93.3
                             withCompletion:^(BOOL success, NSDictionary * _Nullable info) {
                                 if (success) {
                                     [self logMessage:@"设置调频: 成功"];
                                 }
                                 else {
                                     [self logMessage:[NSString stringWithFormat:@"设置调频失败: %@", info[@"error_msg"]]];
                                 }
                             }];
}

- (void)acceptCall {
    [[BLEManager manager] answerCallWithCompletion:^(BOOL success, NSDictionary * _Nullable info) {
        if (success) {
            [self logMessage:@"接听来电: 成功"];
        }
        else {
            [self logMessage:[NSString stringWithFormat:@"接听来电: %@", info[@"error_msg"]]];
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)logMessage:(NSString *)msg {
    [self.logData addObject:msg];
    
    NSInteger row = [self.tableView numberOfRowsInSection:0];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    
    [self.tableView beginUpdates];
    
    [self.tableView insertRowsAtIndexPaths:@[indexPath]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
    
    [self.tableView endUpdates];
    
    [self.tableView scrollToRowAtIndexPath:indexPath
                          atScrollPosition:UITableViewScrollPositionBottom
                                  animated:YES];
}

#pragma mark - BLEManagerDelegate

- (void)bleManager:(BLEManager *)manager stateDidChange:(CBManagerState)state {
    switch (state) {
            case CBManagerStatePoweredOn: {
                [self logMessage:@"蓝牙上电"];
            }
            break;
            
            case CBManagerStatePoweredOff: {
                [self logMessage:@"蓝牙关机"];
            }
            break;
            
            case CBManagerStateUnsupported: {
                [self logMessage:@"蓝牙硬件不支持"];
            }
            break;
            
        default: {
            [self logMessage:[NSString stringWithFormat:@"BLE stateDidChange: %ld", (long)state]];
        }
            break;
    }
}

- (void)bleManager:(BLEManager *)manager scaningDidChange:(BOOL)scaning {
    [self logMessage:scaning?@"开始扫描设备":@"停止扫描设备"];
}

- (BOOL)bleManager:(BLEManager *)manager shouldPairDeviceWithName:(NSString *)name {
    [self logMessage:[NSString stringWithFormat:@"扫描到设备 %@", name]];
    if ([name isEqualToString:@"Q11"]) {
        return YES;
    }
    
    return NO;
}

- (void)bleManager:(BLEManager *)manager devicePaired:(NSString *)name {
    [self logMessage:[NSString stringWithFormat:@"设备 %@ 配对成功", name]];
}

- (void)bleManagerDeviceSearchDidFailed:(BLEManager *)manager {
    [self logMessage:@"扫描失败"];
}

- (void)bleManager:(BLEManager *)manager deviceDidDisconnected:(NSString *)name {
    [self logMessage:@"设备断开连接"];
}

#pragma mark - UITableViewDataSource, UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.logData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [tableView dequeueReusableCellWithIdentifier:[LogCell reuseIdentifier]
                                           forIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(LogCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.message = self.logData[indexPath.row];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}

@end
