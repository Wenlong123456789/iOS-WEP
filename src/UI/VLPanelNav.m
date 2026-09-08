/**
 * VansonLoader L2.7 - VLPanelNav
 * 导航栏、Tab切换、SML缩放、拖动焦点、显示隐藏、屏幕旋转
 */

#import "VLPanel+Internal.h"

@implementation VPanelImpl (Nav)

#pragma mark - NavBar

- (void)setupNavBar:(CGFloat)w {
    CGFloat navH = 44;
    self.navBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, navH)];
    self.navBar.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.28];
    [self.bgView addSubview:self.navBar];

    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, navH - 1, w, 1)];
    sep.backgroundColor = VLStrokeColor();
    [self.navBar addSubview:sep];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, w - 60, navH)];
    title.text = @"VansonLoader · 测试";
    title.textColor = VLAccentColor();
    title.font = [UIFont fontWithName:@"Menlo-Bold" size:14];
    [self.navBar addSubview:title];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.frame = CGRectMake(w - 36, 10, 24, 24);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[VLAccentColor() colorWithAlphaComponent:0.58] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    closeBtn.layer.cornerRadius = 12;
    closeBtn.backgroundColor = [VLAccentColor() colorWithAlphaComponent:0.08];
    [closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [self.navBar addSubview:closeBtn];

    self.navTabButtons = @[];
    self.sizeButtons = @[];
}

- (void)onNavTabTap:(UIButton *)btn {
    [self switchToTab:(VLMainTab)btn.tag animated:YES];
}

- (void)updateNavTabHighlight {
    UIColor *cyan = VLAccentColor();
    for (UIButton *btn in self.navTabButtons) {
        BOOL active = (btn.tag == self.currentTab);
        if (active) {
            btn.backgroundColor = [cyan colorWithAlphaComponent:0.12];
            btn.layer.borderWidth = 1;
            btn.layer.borderColor = [cyan colorWithAlphaComponent:0.3].CGColor;
            [btn setTitleColor:cyan forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor clearColor];
            btn.layer.borderWidth = 0;
            [btn setTitleColor:[cyan colorWithAlphaComponent:0.4] forState:UIControlStateNormal];
        }
    }
}

- (void)onSizeTap:(UIButton *)btn {
    self.currentSize = btn.tag;
    [self updateSizeHighlight];
    [self applySize];
}

- (void)updateSizeHighlight {
    UIColor *cyan = VLAccentColor();
    for (UIButton *btn in self.sizeButtons) {
        BOOL active = (btn.tag == self.currentSize);
        btn.layer.borderColor = active ? cyan.CGColor : [cyan colorWithAlphaComponent:0.2].CGColor;
        [btn setTitleColor:active ? cyan : [cyan colorWithAlphaComponent:0.35] forState:UIControlStateNormal];
        btn.backgroundColor = active ? [cyan colorWithAlphaComponent:0.1] : [UIColor clearColor];
    }
}

- (void)applySize {
    CGFloat scale = 1.0;
    if (self.currentSize == 0) scale = 0.6;
    else if (self.currentSize == 1) scale = 0.8;
    scale *= self.portraitBaseScale;

    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.85
          initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.bgView.transform = CGAffineTransformMakeScale(scale, scale);
    } completion:nil];
}

#pragma mark - Tab Switching

- (void)switchToTab:(VLMainTab)tab animated:(BOOL)animated {
    // 重构：强制仅使用内存扫描 Tab
    tab = VLMainTabMemory;
    self.currentTab = tab;
    [self updateNavTabHighlight];

    void (^doSwitch)(void) = ^{
        if (self.pageMemory) self.pageMemory.hidden = (tab != VLMainTabMemory);
        if (self.pageToolbox) self.pageToolbox.hidden = YES;
        if (self.pageTools) self.pageTools.hidden = YES;
        if (self.pageAbout) self.pageAbout.hidden = YES;
    };

    if (animated) {
        [UIView animateWithDuration:0.15 animations:^{
            if (self.pageMemory) self.pageMemory.alpha = (tab == VLMainTabMemory) ? 1 : 0;
            if (self.pageToolbox) self.pageToolbox.alpha = 0;
            if (self.pageTools) self.pageTools.alpha = 0;
            if (self.pageAbout) self.pageAbout.alpha = 0;
        } completion:^(BOOL f) { doSwitch(); }];
    } else {
        if (self.pageMemory) self.pageMemory.alpha = (tab == VLMainTabMemory) ? 1 : 0;
        if (self.pageToolbox) self.pageToolbox.alpha = 0;
        if (self.pageTools) self.pageTools.alpha = 0;
        if (self.pageAbout) self.pageAbout.alpha = 0;
        doSwitch();
    }

    [self updateContentSize];
    [self stopBrowserRefreshTimer];
}

- (void)updateContentSize {
    UIView *activePage = self.pageMemory;  // 仅内存页
    if (activePage) {
        self.panelBody.contentSize = activePage.frame.size;
    }
    self.panelBody.contentOffset = CGPointZero;
}

#pragma mark - Hit Test / Drag / Focus

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01) return nil;

    if (CGRectContainsPoint(self.bgView.frame, point)) {
        if (self.isFocused) {
            CGPoint bgPoint = [self convertPoint:point toView:self.bgView];
            return [self.bgView hitTest:bgPoint withEvent:event];
        } else {
            return self;
        }
    }

    if (g_touchPassthroughMode) return nil;
    if (self.isFocused) return self;
    return nil;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];

    if (CGRectContainsPoint(self.bgView.frame, point)) {
        self.dragStartPoint = point;
        self.bgStartCenter = self.bgView.center;
        if (!self.isFocused) [self setFocused:YES animated:YES];
        return;
    }

    // 点击空白处直接隐藏，避免半透明残留
    if (self.isFocused) [self close];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.isFocused) return;
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];

    CGFloat dx = point.x - self.dragStartPoint.x;
    CGFloat dy = point.y - self.dragStartPoint.y;
    CGPoint newCenter = CGPointMake(self.bgStartCenter.x + dx, self.bgStartCenter.y + dy);

    CGFloat halfW = self.bgView.frame.size.width / 2;
    CGFloat halfH = self.bgView.frame.size.height / 2;
    newCenter.x = MAX(halfW - 50, MIN(self.bounds.size.width - halfW + 50, newCenter.x));
    newCenter.y = MAX(halfH - 30, MIN(self.bounds.size.height - halfH + 30, newCenter.y));

    self.bgView.center = newCenter;
}

- (void)setFocused:(BOOL)focused animated:(BOOL)animated {
    if (self.isFocused == focused) return;
    self.isFocused = focused;

    void (^animations)(void) = ^{
        self.dimView.alpha = focused ? 1 : 0;
        self.bgView.alpha = focused ? 1.0 : 0.3;
    };

    if (animated) [UIView animateWithDuration:0.25 animations:animations];
    else animations();
}

- (void)onDimTap {
    // 点击空白处直接隐藏面板（修复半透明残留问题）
    [self close];
}

#pragma mark - Show/Hide

- (void)showWithAnimation {
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    self.frame = CGRectMake(0, 0, sw, sh);
    self.dimView.frame = self.bounds;

    CGFloat longSide = MAX(sw, sh);
    CGFloat shortSide = MIN(sw, sh);
    CGFloat newW = MIN(longSide * 0.94, 560);
    CGFloat newH = shortSide * 0.85;

    if (sw < sh) {
        self.portraitBaseScale = (sw * 0.94) / newW;
        if (self.portraitBaseScale > 1.0) self.portraitBaseScale = 1.0;
    } else {
        self.portraitBaseScale = 1.0;
    }

    self.bgView.transform = CGAffineTransformIdentity;
    CGFloat oldW = self.bgView.frame.size.width;
    CGFloat oldH = self.bgView.frame.size.height;
    if (fabs(newW - oldW) > 1 || fabs(newH - oldH) > 1) {
        self.bgView.frame = CGRectMake((sw - newW) / 2, (sh - newH) / 2, newW, newH);
        [self resetFusionViews];
        for (UIView *v in self.bgView.subviews) [v removeFromSuperview];
        [self setupNavBar:newW];
        CGFloat bodyTop = 44;
        self.panelBody = [[UIScrollView alloc] initWithFrame:CGRectMake(0, bodyTop, newW, newH - bodyTop)];
        self.panelBody.showsVerticalScrollIndicator = NO;
        self.panelBody.bounces = YES;
        [self.bgView addSubview:self.panelBody];
        [self setupMemoryPage:newW];
        // 重构：仅保留内存页
        // [self setupToolboxPage:newW];
        // [self setupToolsPage:newW];
        // [self setupAboutPage:newW];
        [self switchToTab:VLMainTabMemory animated:NO];
    } else {
        self.bgView.center = CGPointMake(sw / 2, sh / 2);
    }

    self.hidden = NO;
    self.isFocused = YES;
    self.bgView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    self.bgView.alpha = 0;
    self.dimView.alpha = 0;

    CGFloat scale = 1.0;
    if (self.currentSize == 0) scale = 0.6;
    else if (self.currentSize == 1) scale = 0.8;
    scale *= self.portraitBaseScale;

    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
        self.bgView.transform = CGAffineTransformMakeScale(scale, scale);
        self.bgView.alpha = 1;
        self.dimView.alpha = 1;
    } completion:nil];
}

- (void)hideWithAnimation {
    [UIView animateWithDuration:0.2 animations:^{
        self.bgView.alpha = 0;
        self.dimView.alpha = 0;
    } completion:^(BOOL finished) {
        self.hidden = YES;
        CGFloat sw = [UIScreen mainScreen].bounds.size.width;
        CGFloat sh = [UIScreen mainScreen].bounds.size.height;
        self.bgView.center = CGPointMake(sw / 2, sh / 2);
    }];
}

- (void)close {
    [self hideWithAnimation];
}

#pragma mark - Orientation

- (void)onOrientationChanged {
    if (self.hidden) return;

    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    CGFloat sh = [UIScreen mainScreen].bounds.size.height;
    CGFloat longSide = MAX(sw, sh);
    CGFloat shortSide = MIN(sw, sh);
    CGFloat newW = MIN(longSide * 0.94, 560);
    CGFloat newH = shortSide * 0.85;

    if (sw < sh) {
        self.portraitBaseScale = (sw * 0.94) / newW;
        if (self.portraitBaseScale > 1.0) self.portraitBaseScale = 1.0;
    } else {
        self.portraitBaseScale = 1.0;
    }

    CGFloat oldW = self.bgView.frame.size.width;
    CGFloat oldH = self.bgView.frame.size.height;
    if (fabs(newW - oldW) < 1 && fabs(newH - oldH) < 1) return;

    self.frame = [UIScreen mainScreen].bounds;
    self.dimView.frame = self.bounds;

    self.bgView.transform = CGAffineTransformIdentity;
    self.bgView.frame = CGRectMake((sw - newW) / 2, (sh - newH) / 2, newW, newH);

    [self resetFusionViews];
    for (UIView *v in self.bgView.subviews) [v removeFromSuperview];

    [self setupNavBar:newW];

    CGFloat bodyTop = 44;
    self.panelBody = [[UIScrollView alloc] initWithFrame:CGRectMake(0, bodyTop, newW, newH - bodyTop)];
    self.panelBody.showsVerticalScrollIndicator = NO;
    self.panelBody.bounces = YES;
    [self.bgView addSubview:self.panelBody];

    [self setupMemoryPage:newW];
    // 重构：仅保留内存页
    // [self setupToolboxPage:newW];
    // [self setupToolsPage:newW];
    // [self setupAboutPage:newW];
    [self switchToTab:VLMainTabMemory animated:NO];

    CGFloat scale = 1.0;
    if (self.currentSize == 0) scale = 0.6;
    else if (self.currentSize == 1) scale = 0.8;
    scale *= self.portraitBaseScale;
    self.bgView.transform = CGAffineTransformMakeScale(scale, scale);
}

- (void)resetFusionViews {
    self.watchFusionView = nil; self.watchSlotTable = nil; self.watchHitTable = nil;
    self.watchInspectTable = nil; self.watchInspectToolbar = nil; self.watchBackBtn = nil;
    self.watchNavState = 0; self.watchInspectHit = nil; self.watchInspectLines = nil;
    self.browserFusionView = nil; self.browserTable = nil; self.browserAddrField = nil; self.browserTypeSeg = nil;
}

@end
