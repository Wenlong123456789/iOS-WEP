/**
 * VansonLoader L2.3 - VLIconManager
 * 统一图标管理器
 * 使用 IC(@"icon_name") 宏获取图标
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 便捷宏：IC(@"icon_name") 获取 UIImage
#define IC(name) [VLIconManager imageForKey:name]

@interface VLIconManager : NSObject

/// 根据 key 获取图标 UIImage
+ (nullable UIImage *)imageForKey:(NSString *)key;

/// 获取所有可用的图标 key 列表
+ (NSArray<NSString *> *)allKeys;

@end

NS_ASSUME_NONNULL_END
