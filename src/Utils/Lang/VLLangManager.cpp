/**
 * VansonLoader - Language Manager Implementation
 */

#include "VLLangManager.hpp"

VLLangManager& VLLangManager::shared() {
    static VLLangManager instance;
    return instance;
}

VLLangManager::VLLangManager() : currentLang(VLangCode::Auto) {
    // 初始化支持的语言列表
    supportedLangs = {
        {VLangCode::Auto, "auto", "Auto", "Auto"},
        {VLangCode::EN, "en", "English", "English"},
        {VLangCode::CN, "zh-Hans", "简体中文", "Simplified Chinese"},
        {VLangCode::TW, "zh-Hant", "繁體中文", "Traditional Chinese"},
        {VLangCode::JA, "ja", "日本語", "Japanese"},
        {VLangCode::KO, "ko", "한국어", "Korean"},
        {VLangCode::RU, "ru", "Русский", "Russian"},
        {VLangCode::ES, "es", "Español", "Spanish"},
        {VLangCode::VI, "vi", "Tiếng Việt", "Vietnamese"},
        {VLangCode::TH, "th", "ไทย", "Thai"},
        {VLangCode::PT, "pt", "Português", "Portuguese"},
        {VLangCode::FR, "fr", "Français", "French"},
        {VLangCode::DE, "de", "Deutsch", "German"},
        {VLangCode::AR, "ar", "العربية", "Arabic"},
    };
    
    // 默认加载英语
    loadLanguage(VLangCode::EN);
}

void VLLangManager::loadLanguage(VLangCode code) {
    switch (code) {
        case VLangCode::EN:
            currentDict = getLangEN();
            break;
        case VLangCode::CN:
            currentDict = getLangCN();
            break;
        case VLangCode::TW:
            currentDict = getLangTW();
            break;
        case VLangCode::JA:
            currentDict = getLangJA();
            break;
        case VLangCode::KO:
            currentDict = getLangKO();
            break;
        case VLangCode::RU:
            currentDict = getLangRU();
            break;
        case VLangCode::ES:
            currentDict = getLangES();
            break;
        case VLangCode::VI:
            currentDict = getLangVI();
            break;
        case VLangCode::TH:
            currentDict = getLangTH();
            break;
        case VLangCode::PT:
            currentDict = getLangPT();
            break;
        case VLangCode::FR:
            currentDict = getLangFR();
            break;
        case VLangCode::DE:
            currentDict = getLangDE();
            break;
        case VLangCode::AR:
            currentDict = getLangAR();
            break;
        default:
            currentDict = getLangEN();
            break;
    }
}

std::string VLLangManager::getString(const std::string& key) {
    auto it = currentDict.find(key);
    if (it != currentDict.end()) {
        return it->second;
    }
    // 如果当前语言没有，尝试从英语获取
    if (currentLang != VLangCode::EN) {
        auto enDict = getLangEN();
        auto enIt = enDict.find(key);
        if (enIt != enDict.end()) {
            return enIt->second;
        }
    }
    return key; // 返回 key 本身作为 fallback
}

void VLLangManager::setLanguage(VLangCode code) {
    if (code == VLangCode::Auto) {
        code = detectSystemLanguage();
    }
    currentLang = code;
    loadLanguage(code);
}

VLangCode VLLangManager::detectSystemLanguage() {
    // 这个函数会在 Objective-C 桥接层被调用
    // 默认返回英语
    return VLangCode::EN;
}

const LangInfo* VLLangManager::getLangInfo(VLangCode code) const {
    for (const auto& info : supportedLangs) {
        if (info.code == code) {
            return &info;
        }
    }
    return nullptr;
}
