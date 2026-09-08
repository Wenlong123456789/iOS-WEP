/**
 * VansonLoader L2.6 - Panel Size Helper
 * 为悬浮面板标题栏添加 大/中/小 缩放按钮
 */

#import <UIKit/UIKit.h>

/// 在 panelView 标题栏正中间添加 大/中/小 三个缩放按钮
/// @param panelView 面板视图
/// @param containerBounds 容器 bounds (用于居中计算)
/// @param originalWidth 面板原始宽度 (大 尺寸)
/// @param originalHeight 面板原始高度 (大 尺寸)
void VLPanelAddSizeButtons(UIView *panelView, CGRect containerBounds,
                           CGFloat originalWidth, CGFloat originalHeight);
