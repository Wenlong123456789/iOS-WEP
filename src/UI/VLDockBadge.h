/**
 * VansonLoader L2.3 - VLDockBadge
 * 可拖动的缩小角标组件
 * 支持拖动、避开灵动岛
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLDockBadge : UIView

@property (nonatomic, copy) void (^onTap)(void);  // 点击回调
@property (nonatomic, copy) NSString *icon;       // 显示的图标 (emoji)
@property (nonatomic, strong, nullable) UIImage *iconImage;  // 显示的图片 (优先于 icon)
@property (nonatomic, assign) NSInteger slotIndex; // 排队槽位索引

- (instancetype)initWithIcon:(NSString *)icon;
- (instancetype)initWithImage:(nullable UIImage *)image fallbackIcon:(NSString *)icon;

// 显示在指定位置（自动避开灵动岛）
- (void)showAtPosition:(CGPoint)position inView:(UIView *)parentView;
// 显示在自动排队位置（右侧边缘，自动往下排）
- (void)showInQueueInView:(UIView *)parentView;
- (void)hideAnimated:(BOOL)animated;

// 获取安全的Y坐标（避开灵动岛）
+ (CGFloat)safeTopMargin;

// 全局槽位管理
+ (NSInteger)acquireSlot;
+ (void)releaseSlot:(NSInteger)slot;
+ (CGFloat)yPositionForSlot:(NSInteger)slot;

@end

NS_ASSUME_NONNULL_END
