/**
 * VansonLoader L2.6 - Panel Size Helper Implementation
 * 使用 transform 缩放，无需重新布局子视图
 */

#import "VLPanelSizeHelper.h"
#import "../Utils/VLLocalization.h"
#import <objc/runtime.h>

@interface VLPanelSizeHelper : NSObject
+ (void)onSizeBtn:(UIButton *)sender;
@end

@implementation VLPanelSizeHelper

+ (void)onSizeBtn:(UIButton *)sender {
    UIView *panelView = sender.superview;
    if (!panelView) return;

    CGFloat scale = 1.0;
    if (sender.tag == 8001) scale = 0.55;
    else if (sender.tag == 8002) scale = 0.75;

    UIColor *cyan = [UIColor cyanColor];
    for (NSInteger t = 8001; t <= 8003; t++) {
        UIButton *btn = [panelView viewWithTag:t];
        if (btn) {
            BOOL sel = (btn.tag == sender.tag);
            btn.backgroundColor = sel ? [cyan colorWithAlphaComponent:0.25] : [UIColor clearColor];
            [btn setTitleColor:sel ? cyan : [cyan colorWithAlphaComponent:0.45] forState:UIControlStateNormal];
        }
    }

    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.85
          initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        panelView.transform = CGAffineTransformMakeScale(scale, scale);
    } completion:nil];
}

@end

void VLPanelAddSizeButtons(UIView *panelView, CGRect containerBounds __attribute__((unused)),
                           CGFloat originalWidth, CGFloat originalHeight __attribute__((unused))) {
    UIColor *cyan = [UIColor cyanColor];
    CGFloat pw = originalWidth;

    NSArray *titles = @[VL(@"Size_Small"), VL(@"Size_Medium"), VL(@"Size_Large")];
    NSInteger tags[] = {8001, 8002, 8003};

    // 根据最长标题动态计算按钮宽度
    UIFont *font = [UIFont fontWithName:@"Menlo-Bold" size:10];
    CGFloat maxTitleW = 0;
    for (NSString *t in titles) {
        CGFloat tw = [t sizeWithAttributes:@{NSFontAttributeName: font}].width;
        if (tw > maxTitleW) maxTitleW = tw;
    }
    CGFloat btnW = MAX(28, maxTitleW + 12);
    CGFloat btnH = 20, gap = 4;
    CGFloat totalW = btnW * 3 + gap * 2;
    CGFloat startX = (pw - totalW) / 2;
    CGFloat btnY = 10;

    for (int i = 0; i < 3; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(startX + i * (btnW + gap), btnY, btnW, btnH);
        btn.tag = tags[i];
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        btn.titleLabel.font = font;
        btn.titleLabel.adjustsFontSizeToFitWidth = YES;
        btn.titleLabel.minimumScaleFactor = 0.7;
        btn.layer.cornerRadius = 4;
        btn.layer.borderWidth = 1;
        btn.layer.borderColor = [cyan colorWithAlphaComponent:0.4].CGColor;

        BOOL selected = (i == 2); // 大 默认选中
        btn.backgroundColor = selected ? [cyan colorWithAlphaComponent:0.25] : [UIColor clearColor];
        [btn setTitleColor:selected ? cyan : [cyan colorWithAlphaComponent:0.45] forState:UIControlStateNormal];

        [btn addTarget:[VLPanelSizeHelper class] action:@selector(onSizeBtn:)
      forControlEvents:UIControlEventTouchUpInside];
        [panelView addSubview:btn];
    }
}
