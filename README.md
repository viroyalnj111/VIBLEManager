# VIBLEManager

远御车载语音支架的蓝牙通信模块，负责蓝牙设备的扫描、配对、指令下发

## 安装

VIBLEManager 是一个独立的模块，依赖于 CoreBluetooth，可以通过 [CocoaPods](https://cocoapods.org) 来安装，
只需要在 Podfile 中增加如下代码

```ruby
pod 'VIBLEManager', :git => 'https://github.com/guofengld/VIBLEManager.git'
```

或者下载 [源代码](https://github.com/guofengld/VIBLEManager/tree/master/VIBLEManager)，手动添加
到工程中便可，别忘了在工程文件中 link CoreBluetooth.framework

## 使用

### 初始化

```objective-c
BLEManager *manager = [BLEManager manager];
manager.delegate = self;
```

### BLEManagerDelegate 实现

```objective-c
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
```

### 指令下发

```objective-c
/*
 * 向蓝牙设备发送指令，所有的指令会按照先后顺序，逐条发送，指令处理完成后，会调用 completion
 @param string 指令内容，非空
 @completion 完成回调
 */
- (void)sendCommand:(NSString *)string
     withCompletion:(nullable CommonBlock)completion;
     
```

## 贡献

如果有新的需求，请提交 [issue](https://github.com/guofengld/VIBLEManager/issues)

欢迎 [pr](https://github.com/guofengld/VIBLEManager/pulls)

## License

[MIT](./LICENSE)

