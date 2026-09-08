/**
 * VansonLoader - Language Manager
 * 多语言管理器
 */

#ifndef VL_LANG_MANAGER_HPP
#define VL_LANG_MANAGER_HPP

#include <map>
#include <string>
#include <vector>

// 语言代码枚举 (使用 VLangCode 避免与 MacTypes.h 冲突)
enum class VLangCode {
    Auto = 0,   // 自动检测
    EN,         // English
    CN,         // 简体中文
    TW,         // 繁體中文
    JA,         // 日本語
    KO,         // 한국어
    RU,         // Русский
    ES,         // Español
    VI,         // Tiếng Việt
    TH,         // ไทย
    PT,         // Português
    FR,         // Français
    DE,         // Deutsch
    AR,         // العربية
    COUNT
};

// 语言信息结构
struct LangInfo {
    VLangCode code;
    std::string codeStr;      // "en", "zh-Hans", etc.
    std::string nativeName;   // 本地名称
    std::string englishName;  // 英文名称
};

// 获取各语言字典的函数声明
std::map<std::string, std::string> getLangEN();
std::map<std::string, std::string> getLangCN();
std::map<std::string, std::string> getLangTW();
std::map<std::string, std::string> getLangJA();
std::map<std::string, std::string> getLangKO();
std::map<std::string, std::string> getLangRU();
std::map<std::string, std::string> getLangES();
std::map<std::string, std::string> getLangVI();
std::map<std::string, std::string> getLangTH();
std::map<std::string, std::string> getLangPT();
std::map<std::string, std::string> getLangFR();
std::map<std::string, std::string> getLangDE();
std::map<std::string, std::string> getLangAR();

class VLLangManager {
public:
    static VLLangManager& shared();
    
    // 获取本地化字符串
    std::string getString(const std::string& key);
    
    // 设置语言
    void setLanguage(VLangCode code);
    
    // 获取当前语言
    VLangCode getCurrentLanguage() const { return currentLang; }
    
    // 获取所有支持的语言列表
    const std::vector<LangInfo>& getSupportedLanguages() const { return supportedLangs; }
    
    // 根据系统语言自动检测
    VLangCode detectSystemLanguage();
    
    // 获取语言信息
    const LangInfo* getLangInfo(VLangCode code) const;
    
private:
    VLLangManager();
    void loadLanguage(VLangCode code);
    
    VLangCode currentLang;
    std::map<std::string, std::string> currentDict;
    std::vector<LangInfo> supportedLangs;
};

// 兼容别名
typedef VLLangManager LangManager;

#endif // VL_LANG_MANAGER_HPP
