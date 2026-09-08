/**
 * VansonLoader - 精简版头文件
 * 仅内存扫描/修改 + 悬浮面板
 */

#ifndef VansonLoader_h
#define VansonLoader_h

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Core / Engine
#import "src/Core/VLCore.hpp"
#import "src/Core/VLMemCore.hpp"
#import "src/Core/VLMemTypes.hpp"
#import "src/Engine/VLMemEngine.h"

// Utils
#import "src/Utils/VLLocalization.h"
#import "src/Utils/VLIconManager.h"
#import "src/Utils/VLCrypto.h"

// UI
#import "src/UI/VLOverlayWindow.h"
#import "src/UI/VLFloatingButton.h"
#import "src/UI/VLPanel.h"
#import "src/UI/VLMemorySearch.h"
#import "src/UI/VLMemoryBrowser.h"
#import "src/UI/VLMemResults.h"
#import "src/UI/VLStringEditorViewController.h"
#import "src/UI/VLStringMemorySession.h"
#import "src/UI/VLPanelSizeHelper.h"

#endif /* VansonLoader_h */
