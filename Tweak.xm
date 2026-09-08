/**
 * VansonLoader - Tweak Entry (精简版)
 * 仅内存扫描/修改 + 悬浮按钮/面板
 */

#import "VansonLoader.h"
#import <objc/runtime.h>

static BOOL g_vlFloatingUIInstalled = NO;

static NSArray<UIWindow *> *VLAllApplicationWindows(void) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive &&
                scene.activationState != UISceneActivationStateForegroundInactive) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            [windows addObjectsFromArray:windowScene.windows];
        }
    }
    [windows addObjectsFromArray:UIApplication.sharedApplication.windows];
    return windows;
}

extern "C" UIWindow *GetSafeWindow(void) {
    Class overlayClass = NSClassFromString(@"VLOverlayWindow");
    if (overlayClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        SEL sharedSel = NSSelectorFromString(@"shared");
        if ([overlayClass respondsToSelector:sharedSel]) {
            UIWindow *overlay = [overlayClass performSelector:sharedSel];
            if (overlay) {
                SEL attachSel = NSSelectorFromString(@"attachActiveSceneIfNeeded");
                if ([overlay respondsToSelector:attachSel]) {
                    [overlay performSelector:attachSel];
                }
                overlay.hidden = NO;
                return overlay;
            }
        }
#pragma clang diagnostic pop
    }

    for (UIWindow *w in VLAllApplicationWindows()) {
        if (w.isKeyWindow) return w;
    }
    for (UIWindow *w in VLAllApplicationWindows()) {
        if (!w.hidden && w.alpha > 0.01) return w;
    }
    return VLAllApplicationWindows().firstObject;
}

extern "C" void showToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = GetSafeWindow();
        if (!win) return;

        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 50)];
        l.center = win.center;
        l.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        l.textColor = [UIColor whiteColor];
        l.textAlignment = NSTextAlignmentCenter;
        l.text = msg;
        l.layer.cornerRadius = 10;
        l.clipsToBounds = YES;
        [win addSubview:l];

        [UIView animateWithDuration:0.3 delay:1.0 options:0 animations:^{
            l.alpha = 0;
        } completion:^(BOOL f) {
            [l removeFromSuperview];
        }];
    });
}

static BOOL VLInstallFloatingUIIfPossible(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            VLInstallFloatingUIIfPossible();
        });
        return NO;
    }

    Class btnClass = NSClassFromString(@"VLFloatingButton");
    if (!btnClass) return NO;

    Class overlayClass = NSClassFromString(@"VLOverlayWindow");
    UIWindow *w = nil;
    if (overlayClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        SEL sharedSel = NSSelectorFromString(@"shared");
        if ([overlayClass respondsToSelector:sharedSel]) {
            w = [overlayClass performSelector:sharedSel];
        }
#pragma clang diagnostic pop
    }
    if (!w) w = GetSafeWindow();
    if (!w) return NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL installSel = NSSelectorFromString(@"installIfNeeded");
    if ([btnClass respondsToSelector:installSel]) {
        [btnClass performSelector:installSel];
    }
#pragma clang diagnostic pop

    Class panelClass = NSClassFromString(@"VLPanel");
    if (panelClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        SEL initSel = NSSelectorFromString(@"initializeIfNeeded");
        if ([panelClass respondsToSelector:initSel]) {
            [panelClass performSelector:initSel];
        }
#pragma clang diagnostic pop
    }

    g_vlFloatingUIInstalled = YES;
    return YES;
}

static void VLScheduleFloatingUIInstall(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        VLInstallFloatingUIIfPossible();
    });
}

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        VLInstallFloatingUIIfPossible();
        __block NSInteger retry = 0;
        NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            retry++;
            BOOL installed = VLInstallFloatingUIIfPossible();
            if ((installed && retry >= 8) || retry >= 120) {
                [timer invalidate];
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
            VLScheduleFloatingUIInstall();
        }];
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
            VLScheduleFloatingUIInstall();
        }];
        [center addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
            VLScheduleFloatingUIInstall();
        }];
        if (@available(iOS 13.0, *)) {
            [center addObserverForName:UISceneDidActivateNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
                VLScheduleFloatingUIInstall();
            }];
        }
    });
}
