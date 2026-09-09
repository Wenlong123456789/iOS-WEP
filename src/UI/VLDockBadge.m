/**
 * VansonLoader L2.3 - VLDockBadge 实现
 * 可拖动的缩小角标组件
 */

#import "VLDockBadge.h"

@interface VLDockBadge ()
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) CGPoint badgeStartCenter;
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) BOOL isDockedToEdge;
@property (nonatomic, assign) NSInteger idleCount;
@property (nonatomic, strong) NSTimer *idleTimer;
@property (nonatomic, assign) CGPoint lastPosition;
@end

// 全局槽位管理 (最多支持10个悬浮窗)
#define MAX_SLOTS 10
static BOOL g_occupiedSlots[MAX_SLOTS] = {NO};
static NSLock *g_slotLock = nil;

@implementation VLDockBadge

+ (void)initialize {
    if (self == [VLDockBadge class]) {
        g_slotLock = [[NSLock alloc] init];
    }
}

+ (CGFloat)safeTopMargin {
    CGFloat safeTop = 70; // 默认安全顶部距离（避开灵动岛）
    if (@available(iOS 11.0, *)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
        if (window) {
            safeTop = MAX(window.safeAreaInsets.top + 15, 70);
        }
    }
    return safeTop;
}

#pragma mark - 全局槽位管理

+ (NSInteger)acquireSlot {
    [g_slotLock lock];
    NSInteger slot = -1;
    for (NSInteger i = 0; i < MAX_SLOTS; i++) {
        if (!g_occupiedSlots[i]) {
            g_occupiedSlots[i] = YES;
            slot = i;
            break;
        }
    }
    [g_slotLock unlock];
    return slot;
}

+ (void)releaseSlot:(NSInteger)slot {
    if (slot < 0 || slot >= MAX_SLOTS) return;
    [g_slotLock lock];
    g_occupiedSlots[slot] = NO;
    [g_slotLock unlock];
}

+ (CGFloat)yPositionForSlot:(NSInteger)slot {
    CGFloat safeTop = [self safeTopMargin];
    // 每个槽位高度 54 (44角标 + 10间距)
    return safeTop + 22 + slot * 54;
}

- (instancetype)initWithIcon:(NSString *)icon {
    return [self initWithImage:nil fallbackIcon:icon];
}

- (instancetype)initWithImage:(UIImage *)image fallbackIcon:(NSString *)icon {
    if (self = [super initWithFrame:CGRectMake(0, 0, 44, 44)]) {
        _icon = icon;
        _iconImage = image;
        _isDragging = NO;
        _isDockedToEdge = NO;
        _idleCount = 0;
        _slotIndex = -1; // 初始化槽位索引
        [self setupUI];
        [self setupGestures];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor]; // 透明背景
    self.layer.cornerRadius = 8;
    self.layer.borderWidth = 1.5;
    self.layer.borderColor = [UIColor cyanColor].CGColor;
    self.layer.shadowColor = [UIColor cyanColor].CGColor;
    self.layer.shadowRadius = 6;
    self.layer.shadowOpacity = 0.4;
    self.layer.shadowOffset = CGSizeZero;
    
    // 图片视图 - 填满整个区域
    _iconImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    _iconImageView.contentMode = UIViewContentModeScaleAspectFill;
    _iconImageView.layer.cornerRadius = 8;
    _iconImageView.clipsToBounds = YES;
    _iconImageView.backgroundColor = [UIColor clearColor];
    [self addSubview:_iconImageView];
    
    // 文字标签 (fallback)
    _iconLabel = [[UILabel alloc] initWithFrame:self.bounds];
    _iconLabel.text = _icon ?: @"📋";
    _iconLabel.font = [UIFont systemFontOfSize:20];
    _iconLabel.textAlignment = NSTextAlignmentCenter;
    _iconLabel.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.95];
    _iconLabel.layer.cornerRadius = 8;
    _iconLabel.clipsToBounds = YES;
    [self addSubview:_iconLabel];
    
    [self updateIconDisplay];
}

- (void)updateIconDisplay {
    if (_iconImage) {
        _iconImageView.image = _iconImage;
        _iconImageView.hidden = NO;
        _iconLabel.hidden = YES;
    } else {
        _iconImageView.hidden = YES;
        _iconLabel.hidden = NO;
        _iconLabel.text = _icon ?: @"📋";
    }
}

- (void)setupGestures {
    // 点击手势
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self addGestureRecognizer:tap];
    
    // 拖动手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];
}

- (void)setIcon:(NSString *)icon {
    _icon = icon;
    [self updateIconDisplay];
}

- (void)setIconImage:(UIImage *)iconImage {
    _iconImage = iconImage;
    [self updateIconDisplay];
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    if (_isDragging) return;
    
    // 如果已吸入边缘，先唤醒
    if (_isDockedToEdge) {
        [self wakeFromEdge];
        return;
    }
    
    // 点击动画
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];
    
    if (_onTap) _onTap();
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (!self.superview) return;
    
    CGPoint point = [gesture locationInView:self.superview];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _isDragging = YES;
        _idleCount = 0;
        _dragStartPoint = point;
        _badgeStartCenter = self.center;
        
        // 如果已吸入边缘，先唤醒
        if (_isDockedToEdge) {
            _isDockedToEdge = NO;
            [UIView animateWithDuration:0.15 animations:^{
                self.alpha = 1.0;
            }];
        }
        
        // 拖动开始：高亮效果
        [UIView animateWithDuration:0.15 animations:^{
            self.transform = CGAffineTransformMakeScale(1.1, 1.1);
            self.layer.shadowOpacity = 0.8;
        }];
    }
    else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = point.x - _dragStartPoint.x;
        CGFloat dy = point.y - _dragStartPoint.y;
        CGPoint newCenter = CGPointMake(_badgeStartCenter.x + dx, _badgeStartCenter.y + dy);
        
        // 边界限制（避开灵动岛）
        CGFloat sw = self.superview.bounds.size.width;
        CGFloat sh = self.superview.bounds.size.height;
        CGFloat safeTop = [VLDockBadge safeTopMargin];
        
        newCenter.x = MAX(22, MIN(sw - 22, newCenter.x));
        newCenter.y = MAX(safeTop + 22, MIN(sh - 60, newCenter.y));
        
        self.center = newCenter;
    }
    else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        _isDragging = NO;
        
        // 吸附到边缘
        [self snapToEdge];
    }
}

- (void)snapToEdge {
    if (!self.superview) return;
    
    CGFloat sw = self.superview.bounds.size.width;
    CGFloat sh = self.superview.bounds.size.height;
    CGFloat safeTop = [VLDockBadge safeTopMargin];
    
    // 吸附到最近的边缘
    CGFloat targetX;
    if (self.center.x < sw / 2) {
        targetX = 22; // 左边
    } else {
        targetX = sw - 22; // 右边
    }
    
    // Y 轴限制在安全区域
    CGFloat targetY = MAX(safeTop + 22, MIN(self.center.y, sh - 60));
    
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
        self.center = CGPointMake(targetX, targetY);
        self.transform = CGAffineTransformIdentity;
        self.layer.shadowOpacity = 0.4;
    } completion:nil];
    
    _lastPosition = CGPointMake(targetX, targetY);
    _idleCount = 0;
    
    // 启动空闲计时器
    [self startIdleTimer];
}

- (void)startIdleTimer {
    [_idleTimer invalidate];
    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkIdle) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_idleTimer forMode:NSRunLoopCommonModes];
}

- (void)stopIdleTimer {
    [_idleTimer invalidate];
    _idleTimer = nil;
}

- (void)checkIdle {
    if (_isDockedToEdge || _isDragging || self.hidden) return;
    
    _idleCount++;
    
    // 3秒后吸入边缘并半透明
    if (_idleCount >= 3) {
        [self dockIntoEdge];
    }
}

- (void)dockIntoEdge {
    if (_isDockedToEdge || !self.superview) return;
    _isDockedToEdge = YES;
    
    CGFloat sw = self.superview.bounds.size.width;
    
    // 吸入边缘（只露出约1/3）
    CGFloat targetX;
    if (self.center.x < sw / 2) {
        targetX = 8; // 左边露出一点
    } else {
        targetX = sw - 8; // 右边露出一点
    }
    
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.3 options:0 animations:^{
        self.center = CGPointMake(targetX, self.center.y);
        self.alpha = 0.4; // 半透明
        self.layer.shadowOpacity = 0.2;
    } completion:nil];
}

- (void)wakeFromEdge {
    if (!_isDockedToEdge) return;
    
    _isDockedToEdge = NO;
    _idleCount = 0;
    
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
        self.center = self->_lastPosition;
        self.alpha = 1.0;
        self.layer.shadowOpacity = 0.4;
    } completion:nil];
}

- (void)showAtPosition:(CGPoint)position inView:(UIView *)parentView {
    if (!parentView) return;
    
    CGFloat sw = parentView.bounds.size.width;
    CGFloat sh = parentView.bounds.size.height;
    CGFloat safeTop = [VLDockBadge safeTopMargin];
    
    // 决定显示在左边还是右边
    CGFloat badgeX = (position.x < sw / 2) ? 22 : sw - 22;
    
    // Y坐标：避开灵动岛
    CGFloat badgeY = position.y;
    if (badgeY < safeTop + 22) {
        badgeY = safeTop + 22;
    }
    if (badgeY > sh - 60) {
        badgeY = sh - 60;
    }
    
    self.center = CGPointMake(badgeX, badgeY);
    _lastPosition = self.center;
    self.alpha = 0;
    self.transform = CGAffineTransformMakeScale(0.5, 0.5);
    _isDockedToEdge = NO;
    _idleCount = 0;
    
    if (!self.superview) {
        [parentView addSubview:self];
    }
    self.hidden = NO;
    
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        // 启动空闲计时器
        [self startIdleTimer];
    }];
}

- (void)showInQueueInView:(UIView *)parentView {
    if (!parentView) return;
    
    // 释放旧槽位
    if (_slotIndex >= 0) {
        [VLDockBadge releaseSlot:_slotIndex];
    }
    
    // 获取新槽位
    _slotIndex = [VLDockBadge acquireSlot];
    if (_slotIndex < 0) {
        // 没有可用槽位，使用默认位置
        [self showAtPosition:CGPointMake(parentView.bounds.size.width - 22, [VLDockBadge safeTopMargin] + 22) inView:parentView];
        return;
    }
    
    CGFloat sw = parentView.bounds.size.width;
    CGFloat badgeX = sw - 22; // 固定在右边
    CGFloat badgeY = [VLDockBadge yPositionForSlot:_slotIndex];
    
    self.center = CGPointMake(badgeX, badgeY);
    _lastPosition = self.center;
    self.alpha = 0;
    self.transform = CGAffineTransformMakeScale(0.5, 0.5);
    _isDockedToEdge = NO;
    _idleCount = 0;
    
    if (!self.superview) {
        [parentView addSubview:self];
    }
    self.hidden = NO;
    
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:0 animations:^{
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [self startIdleTimer];
    }];
}

- (void)hideAnimated:(BOOL)animated {
    [self stopIdleTimer];
    _isDockedToEdge = NO;
    
    // 释放槽位
    if (_slotIndex >= 0) {
        [VLDockBadge releaseSlot:_slotIndex];
        _slotIndex = -1;
    }
    
    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 0;
            self.transform = CGAffineTransformMakeScale(0.5, 0.5);
        } completion:^(BOOL finished) {
            self.hidden = YES;
            self.transform = CGAffineTransformIdentity;
        }];
    } else {
        self.hidden = YES;
    }
}

- (void)dealloc {
    [self stopIdleTimer];
}

@end
