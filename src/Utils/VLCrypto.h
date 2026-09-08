/**
 * VansonLoader L2.3 - 加密解密工具
 * 完全兼容 VansonMod 2.4 加密格式
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLCrypto : NSObject

/**
 * 获取 VM 2.4 魔数
 */
+ (uint32_t)getVM24Magic;

/**
 * 检查是否为 VM 2.4 格式
 */
+ (BOOL)isVM24Format:(NSData *)data;

/**
 * 解密 VM 2.4 格式数据
 * @param data 加密数据 (包含4字节魔数头)
 * @return 解密后的 JSON 数据，失败返回 nil
 */
+ (nullable NSData *)decryptVM24Data:(NSData *)data;

/**
 * 加密为 VM 2.4 格式
 * @param data 原始 JSON 数据
 * @return 加密后的数据 (包含4字节魔数头)
 */
+ (nullable NSData *)encryptToVM24Data:(NSData *)data;

/**
 * Hex 字符串转 NSData
 */
+ (nullable NSData *)dataFromHexString:(NSString *)hex;

/**
 * NSData 转 Hex 字符串
 */
+ (NSString *)hexStringFromData:(NSData *)data;

@end

// 兼容别名
typedef VLCrypto VCrypto;

NS_ASSUME_NONNULL_END
