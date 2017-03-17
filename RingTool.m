//
//  RingTool.m
//  HandheldBloodDoctor
//
//  Created by fangfei on 2017/3/9.
//  Copyright © 2017年 team. All rights reserved.
//

#import "RingTool.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface RingTool()<CBCentralManagerDelegate,CBPeripheralDelegate>
{
    CBCentralManager *theManager;
    CBPeripheral *thePerpher;    // 发送命令用的 确定
    CBCharacteristic *theSakeCC; // 发送命令用的 正式用ff05 测试用ff06
    
    
    CBCharacteristic *FF01;  // 电量
    CBCharacteristic *FF02;  // 手环参数校准状态
    CBCharacteristic *FF03;  // 用户体征值
    CBCharacteristic *FF04;  // 手环振动开关
    CBCharacteristic *FF05;  // 手环某些功能的测试接口   测试用
    CBCharacteristic *FF06;  // 测试接口的返回数据      测试用
    CBCharacteristic *FF07;  // 手环时钟读取和同步
    CBCharacteristic *FF08;  // 体征数据缓存量
    CBCharacteristic *FF09;  // 用户偏好设置
    CBCharacteristic *FF10; // 在手环独立工作时缓存的体征数据，
    CBCharacteristic *FF11; // 控制命令写入接口         正式用
    CBCharacteristic *FF12; // 控制命令执行结果返回接口  正式用
    
    
    // 默认检测时间为10s
    NSTimer *timer;
    
}

@end

@implementation RingTool

//单例模式
+ (instancetype)shareBluetooth {
    static RingTool *share = nil;
    static dispatch_once_t oneToken;
    dispatch_once(&oneToken, ^{
        share = [[RingTool alloc]init];
    });
    return share;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        //初始化对象
       
    }
    return self;
}
#pragma mark - 传输命令方法
- (void)sendOrderWithData:(NSData *)data
{
    if (thePerpher && theSakeCC) {
        [thePerpher writeValue:data forCharacteristic:theSakeCC type:CBCharacteristicWriteWithResponse];
    }
}
- (void)readRingValue:(ResType)type
{
    switch (type) {
        case ReadTypeBuffer:
             [thePerpher readValueForCharacteristic:FF08];
            break;
        case ReadTypeBattery:
            [thePerpher readValueForCharacteristic:FF01];
            break;
        case ReadTypePreference:
            [thePerpher readValueForCharacteristic:FF09];
            break;
        default:
            break;
    }
}
- (void)scanRing
{
     theManager = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
}
- (void)stopScanRing
{
    [timer invalidate];
    timer = nil;
    [theManager stopScan];
}
- (void)disconnectRing
{
    [theManager cancelPeripheralConnection:thePerpher];
    thePerpher = nil;
    theSakeCC = nil;
    [[NSUserDefaults standardUserDefaults] setObject:@"未连接" forKey:@"bluetoothState"];
}
#pragma mark - 代理方法
//从这个代理方法中你可以看到所有的状态，其实我们需要的只有on和off连个状态
- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    switch (central.state) {
        case CBCentralManagerStateUnknown:
            NSLog(@"未知");
            break;
        case CBCentralManagerStateResetting:
            NSLog(@"重置");
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@"不支持");
            break;
        case CBCentralManagerStateUnauthorized:
            NSLog(@"设备关闭");
            break;
        case CBCentralManagerStatePoweredOff:
            NSLog(@"关闭状态");
            if([self.delegate respondsToSelector:@selector(getBluetoothState:)]) {
                [self.delegate getBluetoothState:NO];
            }
            break;
        case CBCentralManagerStatePoweredOn:
            NSLog(@"可以开始");
          
            if([self.delegate respondsToSelector:@selector(getBluetoothState:)]) {
                   [self.delegate getBluetoothState:YES];
            }
            [theManager scanForPeripheralsWithServices:nil options:nil];

            break;
        default:
            break;
    }
}
//扫描到设备会进入方法
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{

    timer = [NSTimer scheduledTimerWithTimeInterval:10 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if([self.delegate respondsToSelector:@selector(searchRingResult:)]) {
            [self.delegate searchRingResult:NO];
        }
        [self stopScanRing];
    }];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    
    if ([peripheral.name hasSuffix:@"TEST"]) {
        
        [timer invalidate];
        timer = nil;
        thePerpher = peripheral;
        [central stopScan];
        [central connectPeripheral:peripheral options:nil];
    }else
    {
        [[NSUserDefaults standardUserDefaults] setObject:@"未连接" forKey:@"bluetoothState"];
    }
}
#pragma mark 设备扫描与连接的代理
//连接到Peripherals-成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
}
//连接外设失败
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if([self.delegate respondsToSelector:@selector(searchRingResult:)]) {
       [self.delegate searchRingResult:NO];
    }
    [self stopScanRing];
}
//扫描到服务
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if (error)
    {
        if([self.delegate respondsToSelector:@selector(searchRingResult:)]) {
            [self.delegate searchRingResult:NO];
        }
        [self stopScanRing];
        return;
    }
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
    
}
//扫描到特征
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if (error)
    {
        if([self.delegate respondsToSelector:@selector(searchRingResult:)]) {
            [self.delegate searchRingResult:NO];
        }
        [self stopScanRing];
        return;
    }
    //获取Characteristic的值
    for (CBCharacteristic *characteristic in service.characteristics){
        {
            // 获取编号
            if ([characteristic.UUID.UUIDString isEqualToString:@"2A25"])
            {
                 [peripheral readValueForCharacteristic:characteristic];
            }
            // 设置接受命令行
            if ([characteristic.UUID.UUIDString isEqualToString:@"FF0C"])
            {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
            // 设置发送命令行  测试用FF05 正式用FF0B
            if ([characteristic.UUID.UUIDString isEqualToString:@"FF0B"])
            {
                theSakeCC = characteristic;
            }
            // 电量行
            if ([characteristic.UUID.UUIDString isEqualToString:@"FF01"])
            {
                FF01 = characteristic;
            }
            if ([characteristic.UUID.UUIDString isEqualToString:@"FF02"])
            {
                
            }
            if ([characteristic.UUID.UUIDString isEqualToString:@"FF03"])
            {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }
            if ([characteristic.UUID.UUIDString isEqualToString:@"FF04"])
            {
            }
            if ([characteristic.UUID.UUIDString isEqualToString:@"FF07"])
            {
                
            }
            if ([characteristic.UUID.UUIDString isEqualToString:@"FF08"])
            {
                FF08 = characteristic;
            }
            if ([characteristic.UUID.UUIDString isEqualToString:@"FF09"])
            {
                FF09 = characteristic;
            }
        }
    }
}
#pragma mark 设备信息处理
//扫描到具体的值
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (error) {
        if([self.delegate respondsToSelector:@selector(searchRingResult:)]) {
            [self.delegate searchRingResult:NO];
        }
        [self stopScanRing];
        return;
    }

    // 最终得到的数据
    if ([characteristic.UUID.UUIDString isEqualToString:@"2A25"])
    {
        NSString *getRingID = [NSString stringWithFormat:@"%@",characteristic.value];
    
        // 如果本地有数据 判断这个数据  一样直接连接 不一样就断开连接   如果没有 就是未绑定  直接连接
        NSString *ringID = [[NSUserDefaults standardUserDefaults] objectForKey:@"bluetooth"];
        NSString *state = [[NSUserDefaults standardUserDefaults] objectForKey:@"add"];
        
        if ([getRingID isEqualToString:ringID] || [state isEqualToString:@"add"])
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"add"];
            [[NSUserDefaults standardUserDefaults] setObject:@"已连接" forKey:@"bluetoothState"];
            [SVProgressHUD showSuccessWithStatus:@"已连接蓝牙"];
            if([self.delegate respondsToSelector:@selector(getRingID:)]) {
                [self.delegate getRingID:getRingID];
            }
        }else
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"add"];
            [[NSUserDefaults standardUserDefaults] setObject:@"未连接" forKey:@"bluetoothState"];
            [self disconnectRing];
            return;
        }
    }
    // 得到的数据
    NSData *data = characteristic.value;
    
    if ([self.delegate respondsToSelector:@selector(getRingData:WithType:)])
    {
        [self.delegate getRingData:data WithType:characteristic.UUID.UUIDString];
    }
}
#pragma mark - 接到手环返回的值
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (characteristic.isNotifying)
    {
        [peripheral readValueForCharacteristic:characteristic];
    }

}
#pragma mark - 代理回调方法
@end
