/**
 * VansonLoader L2.3 - Watchpoint Overlay
 * 硬件断点监控 UI (仅越狱环境显示)
 * - 断点列表 + 状态
 * - 触发弹窗 (堆栈追踪)
 * - 点击堆栈帧 -> 复制 Offset / 发送到 RVA
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLWatchOverlay : NSObject

+ (void)show;
+ (void)showMinimized;
+ (void)hide;
+ (void)toggle;
+ (BOOL)isVisible;
+ (void)reloadData;

// 从内存搜索结果添加监控
+ (void)addWatchForAddress:(uint64_t)address;

// 打开代码检视器 (供面板内嵌调用)
+ (void)showCodeInspectorForHit:(id)hit;

@end

NS_ASSUME_NONNULL_END
