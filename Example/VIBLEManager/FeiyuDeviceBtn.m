//
//  FeiyuDeviceBtn.m
//  Feiyu_Dev
//
//  Created by 熊国锋 on 2018/4/23.
//  Copyright © 2018年 南京远御网络科技有限公司. All rights reserved.
//

#import "FeiyuDeviceBtn.h"
#import <GFCocoaTools/GFCocoaTools.h>

@interface FeiyuDeviceBtn ()

@property (nonatomic, copy) UIImage     *imagePowerOn;
@property (nonatomic, copy) UIImage     *imageConnected;
@property (nonatomic, copy) UIImage     *imageDisconnected;

@end

@implementation FeiyuDeviceBtn

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.tintColor = [UIColor blackColor];
        
        self.imagePowerOn = [[UIImage imageNamed:@"ic_bluetooth"] imageMaskedWithColor:[UIColor blackColor]];
        self.imageConnected = [[UIImage imageNamed:@"ic_bluetooth_connected"] imageMaskedWithColor:[UIColor blackColor]];
        self.imageDisconnected = [[UIImage imageNamed:@"ic_bluetooth_disconnected"] imageMaskedWithColor:[UIColor blackColor]];
        
        [self setImage:self.imageDisconnected forState:UIControlStateNormal];
    }
    
    return self;
}

- (void)setStatus:(DeviceBtnStatus)status {
    [self stopScan];
    switch (status) {
        case DeviceBtnPowerOff: {
            [self setImage:self.imageDisconnected forState:UIControlStateNormal];
        }
            break;
            
        case DeviceBtnScaning: {
            [self startScan];
        }
            break;
            
        case DeviceBtnConnecting: {
            [self startScan];
        }
            break;
            
        case DeviceBtnConnedted: {
            [self setImage:self.imageConnected forState:UIControlStateNormal];
        }
            
        default:
            break;
    }
}

- (void)startScan {
    self.imageView.animationImages = @[self.imagePowerOn, self.imageConnected];
    self.imageView.animationDuration = 1;
    self.imageView.animationRepeatCount = 1000;
    
    [self.imageView startAnimating];
}

- (void)stopScan {
    [self.imageView stopAnimating];
}

@end
