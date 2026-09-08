/**
 * VansonLoader L2.3 - Memory Browser & Hex Editor
 * 内存浏览器和 Hex 编辑器
 * 支持拖动、缩小功能
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// 内存浏览器
@interface VLMemoryBrowserVC : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) NSUInteger dataType;
+ (void)showFromWindow:(UIWindow *)window address:(uint64_t)addr;
+ (void)showWithAddress:(uint64_t)addr;  // 便捷方法，自动获取窗口
+ (void)showMinimized;  // 直接显示为悬浮图标
+ (void)hide;
+ (void)toggle;
+ (BOOL)isVisible;
@end

// Hex 编辑器
@interface VLHexEditorVC : NSObject
@property (nonatomic, assign) uint64_t address;
+ (void)showFromWindow:(UIWindow *)window address:(uint64_t)addr;
+ (void)hide;
+ (void)toggle;
+ (BOOL)isVisible;
@end

// 兼容别名
typedef VLMemoryBrowserVC VMemoryBrowserVC;
typedef VLHexEditorVC VHexEditorVC;

NS_ASSUME_NONNULL_END
