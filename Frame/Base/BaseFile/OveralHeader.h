//
//  OveralHeader.h
//  Frame
//
//  Created by 冯汉栩 on 2021/2/8.
//

//如果有新出的机型打开模拟器 截图查看尺寸(就知道新机型的分辨率)，填上去就可以了。
//资源来自  https://www.jianshu.com/p/5102196a74eb

// ============ iphone机型宏定义 ============

#define isIphone5 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 1136), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIphone5S ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 1136), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIphone5C ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 1136), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIphoneSEtwo ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(750, 1334), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIphoneSE ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(640, 1136), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone6 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(750, 1334), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone6S ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(750, 1334), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone7 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(750, 1334), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone8 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(750, 1334), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone6Plus ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1242, 2208), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone6SPlus ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1242, 2208), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone7Plus ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1242, 2208), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone8Plus ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1242, 2208), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhoneX ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1125, 2436), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhoneXR ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(828, 1792), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhoneXSMax ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1242, 2688), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhoneXS ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1125, 2436), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone11 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(828, 1792), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone11Pro ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1125, 2436), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone11ProMax ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1242, 2688), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone12 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1170, 2532), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone12Pro ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1170, 2532), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone12ProMax ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1284, 2778), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone12Min ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1080, 2340), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone13 ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1170, 2532), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone13Pro ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1170, 2532), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone13ProMax ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1284, 2778), [[UIScreen mainScreen] currentMode].size) : NO)

#define isIPhone13Min ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1080, 2340), [[UIScreen mainScreen] currentMode].size) : NO)

// ============ 基础宏定义 ============

// 获取关键窗口（简化版）
#define KEY_WINDOW \
({ \
    UIWindow *window = nil; \
    NSSet<UIScene *> *scenes = [UIApplication sharedApplication].connectedScenes; \
    for (UIScene *scene in scenes) { \
        if ([scene isKindOfClass:[UIWindowScene class]]) { \
            UIWindowScene *windowScene = (UIWindowScene *)scene; \
            for (UIWindow *w in windowScene.windows) { \
                if (w.isKeyWindow) { \
                    window = w; \
                    break; \
                } \
            } \
            if (window) break; \
        } \
    } \
    window ?: [UIApplication sharedApplication].delegate.window; \
})

// 状态栏高度
#define STATUS_BAR_HEIGHT \
({ \
    CGFloat height = 0; \
    NSSet<UIScene *> *scenes = [UIApplication sharedApplication].connectedScenes; \
    for (UIScene *scene in scenes) { \
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) { \
            UIWindowScene *windowScene = (UIWindowScene *)scene; \
            height = windowScene.statusBarManager.statusBarFrame.size.height; \
            break; \
        } \
    } \
    (height > 0) ? height : 44.0; \
})

// ============ 顶部相关高度 ============

// 安全区域顶部高度
#define SAFE_AREA_TOP_HEIGHT (KEY_WINDOW.safeAreaInsets.top ?: STATUS_BAR_HEIGHT)

// 导航栏高度
#define NAV_BAR_HEIGHT(vc) (vc.navigationController.navigationBar.frame.size.height ?: 44.0)

// 顶部总高度 = 状态栏高度 + 导航栏高度
#define TOTAL_TOP_HEIGHT(vc) (STATUS_BAR_HEIGHT + NAV_BAR_HEIGHT(vc))


// ============ 底部相关高度 ============

// 安全区域底部高度
#define SAFE_AREA_BOTTOM (KEY_WINDOW.safeAreaInsets.bottom)

// TabBar实际高度（包含安全区域）
#define TOTAL_BOTTOM_HEIGHT(vc) \
({ \
    CGFloat tabBarHeight = 49.0; \
    if (vc && vc.tabBarController && !vc.tabBarController.tabBar.hidden) { \
        tabBarHeight = vc.tabBarController.tabBar.frame.size.height; \
    } \
    tabBarHeight; \
})

// ============ 工具宏定义 ============

// 判断是否有刘海屏
#define HAS_NOTCH (SAFE_AREA_BOTTOM > 0)

// 安全区域Insets
#define SAFE_AREA_INSETS (KEY_WINDOW.safeAreaInsets)

// 屏幕宽度
#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)

// 屏幕高度
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)

// 安全区域内的屏幕高度
#define SAFE_SCREEN_HEIGHT (SCREEN_HEIGHT - SAFE_AREA_TOP - SAFE_AREA_BOTTOM)

// ============ 强引用 + 弱引用 ============

#define WeakObj(o) try{}@finally{} __weak typeof(o) o##Weak = o;
/** 使用
 @WeakObj(self);
 selfWeak.XXXX
 */
#define StrongObj(o) autoreleasepool{} __strong typeof(o) o = o##Weak;

// ============ DEBUG打印 ============

#ifdef DEBUG
    //DEBUG模式下 打印日志 具体显示到那个控制器哪一行
    #define DEBUGLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
    //relsase模式下 不打印日志
    #define DEBUGLog(...)
#endif
