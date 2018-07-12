//
//  FeiyuDeviceBtn.h
//  Feiyu_Dev
//
//  Created by 熊国锋 on 2018/4/23.
//  Copyright © 2018年 南京远御网络科技有限公司. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    DeviceBtnPowerOff,
    DeviceBtnNormal,
    DeviceBtnScaning,
    DeviceBtnConnecting,
    DeviceBtnConnedted
}DeviceBtnStatus;

@interface FeiyuDeviceBtn : UIButton

@property (nonatomic, assign) DeviceBtnStatus status;

@end
