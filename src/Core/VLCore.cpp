/**
 * VansonLoader L2.3 - C++ Core Implementation
 */

#include "VLCore.hpp"
#include <cstring>
#include <cstdlib>
#include <cstdio>

#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <libkern/OSCacheControl.h>

// mach_vm 声明
extern "C" {
    kern_return_t mach_vm_write(vm_map_t, mach_vm_address_t, vm_offset_t, mach_msg_type_number_t);
    kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t, mach_vm_size_t, boolean_t, vm_prot_t);
    kern_return_t mach_vm_read_overwrite(vm_map_t, mach_vm_address_t, mach_vm_size_t, mach_vm_address_t, mach_vm_size_t*);
    kern_return_t mach_vm_region(vm_map_t, mach_vm_address_t*, mach_vm_size_t*, vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t*, mach_port_t*);
}

namespace vcore {

// ═══════════════════════════════════════════════════════════════
// MemEngine
// ═══════════════════════════════════════════════════════════════

MemEngine& MemEngine::inst() {
    static MemEngine s;
    return s;
}

uint64_t MemEngine::modBase(const char* name) {
    uint32_t cnt = _dyld_image_count();
    
    if (!name || !name[0] || strcmp(name, "virtual") == 0) {
        return (uint64_t)_dyld_get_image_header(0);
    }
    
    for (uint32_t i = 0; i < cnt; i++) {
        const char* p = _dyld_get_image_name(i);
        if (!p) continue;
        
        const char* last = strrchr(p, '/');
        const char* img = last ? last + 1 : p;
        
        if (strcmp(img, name) == 0 || strstr(img, name)) {
            return (uint64_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

uint64_t MemEngine::modSize(const char* name) {
    uint32_t cnt = _dyld_image_count();
    
    for (uint32_t i = 0; i < cnt; i++) {
        const char* p = _dyld_get_image_name(i);
        if (!p) continue;
        
        const char* last = strrchr(p, '/');
        const char* img = last ? last + 1 : p;
        
        bool match = (!name && i == 0) || (name && (strcmp(img, name) == 0 || strstr(img, name)));
        
        if (match) {
            auto* hdr = (const struct mach_header_64*)_dyld_get_image_header(i);
            if (!hdr) return 0;
            
            uint64_t sz = 0;
            auto* cmd = (struct load_command*)((char*)hdr + sizeof(struct mach_header_64));
            
            for (uint32_t j = 0; j < hdr->ncmds; j++) {
                if (cmd->cmd == LC_SEGMENT_64) {
                    auto* seg = (struct segment_command_64*)cmd;
                    sz += seg->vmsize;
                }
                cmd = (struct load_command*)((char*)cmd + cmd->cmdsize);
            }
            return sz;
        }
    }
    return 0;
}

bool MemEngine::readMem(uint64_t addr, void* buf, size_t len) {
    if (!addr || !buf || !len) return false;
    
    mach_vm_size_t rd = 0;
    kern_return_t kr = mach_vm_read_overwrite(
        mach_task_self(),
        (mach_vm_address_t)addr,
        len,
        (mach_vm_address_t)buf,
        &rd
    );
    return kr == KERN_SUCCESS && rd == len;
}

bool MemEngine::writeMem(uint64_t addr, const void* buf, size_t len) {
    if (!addr || !buf || !len) return false;
    
    mach_port_t task = mach_task_self();
    
    kern_return_t kr = mach_vm_write(task, addr, (vm_offset_t)buf, (mach_msg_type_number_t)len);
    if (kr == KERN_SUCCESS) {
        // 刷新指令缓存 (ARM64 代码段修改必须)
        sys_icache_invalidate((void *)addr, len);
        return true;
    }
    
    kr = mach_vm_protect(task, addr, len, 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return false;
    
    kr = mach_vm_write(task, addr, (vm_offset_t)buf, (mach_msg_type_number_t)len);
    mach_vm_protect(task, addr, len, 0, VM_PROT_READ | VM_PROT_EXECUTE);
    
    if (kr == KERN_SUCCESS) {
        sys_icache_invalidate((void *)addr, len);
    }
    
    return kr == KERN_SUCCESS;
}

uint64_t MemEngine::resolveChain(uint64_t base, uint64_t baseOff, const int64_t* offs, size_t count) {
    if (!base) return 0;
    
    uint64_t addr = base + baseOff;
    
    for (size_t i = 0; i < count; i++) {
        uint64_t ptr = 0;
        if (!readMem(addr, &ptr, 8) || !ptr) return 0;
        addr = ptr + offs[i];
    }
    return addr;
}

size_t MemEngine::typeSize(DataType t) {
    switch (t) {
        case DT_I8:  return 1;
        case DT_I16: return 2;
        case DT_I32: return 4;
        case DT_I64: return 8;
        case DT_U8:  return 1;
        case DT_U16: return 2;
        case DT_U32: return 4;
        case DT_U64: return 8;
        case DT_F32: return 4;
        case DT_F64: return 8;
    }
    return 4;
}

bool MemEngine::readVal(uint64_t addr, DataType type, char* out, size_t outLen) {
    if (!addr || !out || !outLen) return false;
    
    size_t sz = typeSize(type);
    uint8_t buf[8] = {0};
    
    if (!readMem(addr, buf, sz)) return false;
    
    switch (type) {
        case DT_I8:  snprintf(out, outLen, "%d", *(int8_t*)buf); break;
        case DT_I16: snprintf(out, outLen, "%d", *(int16_t*)buf); break;
        case DT_I32: snprintf(out, outLen, "%d", *(int32_t*)buf); break;
        case DT_I64: snprintf(out, outLen, "%lld", *(int64_t*)buf); break;
        case DT_U8:  snprintf(out, outLen, "%u", *(uint8_t*)buf); break;
        case DT_U16: snprintf(out, outLen, "%u", *(uint16_t*)buf); break;
        case DT_U32: snprintf(out, outLen, "%u", *(uint32_t*)buf); break;
        case DT_U64: snprintf(out, outLen, "%llu", *(uint64_t*)buf); break;
        case DT_F32: snprintf(out, outLen, "%.2f", *(float*)buf); break;
        case DT_F64: snprintf(out, outLen, "%.2lf", *(double*)buf); break;
    }
    return true;
}

bool MemEngine::writeVal(uint64_t addr, DataType type, const char* val) {
    if (!addr || !val) return false;
    
    uint8_t buf[8] = {0};
    size_t sz = typeSize(type);
    
    switch (type) {
        case DT_I8:  { int8_t v = (int8_t)atoi(val); memcpy(buf, &v, 1); break; }
        case DT_I16: { int16_t v = (int16_t)atoi(val); memcpy(buf, &v, 2); break; }
        case DT_I32: { int32_t v = (int32_t)atoi(val); memcpy(buf, &v, 4); break; }
        case DT_I64: { int64_t v = atoll(val); memcpy(buf, &v, 8); break; }
        case DT_U8:  { uint8_t v = (uint8_t)strtoul(val, NULL, 10); memcpy(buf, &v, 1); break; }
        case DT_U16: { uint16_t v = (uint16_t)strtoul(val, NULL, 10); memcpy(buf, &v, 2); break; }
        case DT_U32: { uint32_t v = (uint32_t)strtoul(val, NULL, 10); memcpy(buf, &v, 4); break; }
        case DT_U64: { uint64_t v = strtoull(val, NULL, 10); memcpy(buf, &v, 8); break; }
        case DT_F32: { float v = (float)atof(val); memcpy(buf, &v, 4); break; }
        case DT_F64: { double v = atof(val); memcpy(buf, &v, 8); break; }
    }
    
    return writeMem(addr, buf, sz);
}

std::vector<uint64_t> MemEngine::sigScan(const char* sig, const char* mod, size_t maxResults) {
    std::vector<uint64_t> results;
    if (!sig || !sig[0]) return results;
    
    uint64_t base = modBase(mod);
    uint64_t size = modSize(mod);
    
    if (!base || !size) {
        base = 0x100000000ULL;
        size = 0x100000000ULL;
    }
    
    // 解析特征码
    std::vector<uint8_t> pattern;
    std::vector<uint8_t> mask;
    int anchorIdx = -1;
    uint8_t anchorByte = 0;
    
    size_t slen = strlen(sig);
    for (size_t i = 0; i < slen; ) {
        while (i < slen && (sig[i] == ' ' || sig[i] == '\t')) i++;
        if (i + 1 >= slen) break;
        
        char c1 = sig[i], c2 = sig[i + 1];
        i += 2;
        
        if ((c1 == '?' && c2 == '?') || (c1 == '*' && c2 == '*') || (c1 == '-' && c2 == '-')) {
            pattern.push_back(0);
            mask.push_back(0);
        } else {
            auto hexVal = [](char c) -> int {
                if (c >= '0' && c <= '9') return c - '0';
                if (c >= 'A' && c <= 'F') return c - 'A' + 10;
                if (c >= 'a' && c <= 'f') return c - 'a' + 10;
                return 0;
            };
            uint8_t b = (hexVal(c1) << 4) | hexVal(c2);
            pattern.push_back(b);
            mask.push_back(1);
            
            if (anchorIdx == -1) {
                anchorIdx = (int)(pattern.size() - 1);
                anchorByte = b;
            }
        }
    }
    
    if (pattern.empty()) return results;
    
    size_t patLen = pattern.size();
    mach_port_t task = mach_task_self();
    mach_vm_address_t addr = base;
    mach_vm_address_t endLimit = base + size;
    
    while (addr < endLimit && results.size() < maxResults) {
        mach_vm_size_t regionSize = 0;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t objectName;
        
        kern_return_t kr = mach_vm_region(task, &addr, &regionSize, VM_REGION_BASIC_INFO_64,
                                          (vm_region_info_t)&info, &infoCount, &objectName);
        if (kr != KERN_SUCCESS) break;
        
        if ((info.protection & VM_PROT_READ) && regionSize > patLen && regionSize <= 128 * 1024 * 1024) {
            uint8_t* buf = (uint8_t*)malloc(regionSize);
            if (buf) {
                mach_vm_size_t rd = regionSize;
                kr = mach_vm_read_overwrite(task, addr, regionSize, (mach_vm_address_t)buf, &rd);
                
                if (kr == KERN_SUCCESS && rd >= patLen) {
                    size_t scanLimit = rd - patLen + 1;
                    size_t i = 0;
                    
                    while (i < scanLimit && results.size() < maxResults) {
                        if (anchorIdx != -1) {
                            void* found = memchr(buf + i + anchorIdx, anchorByte, rd - (i + anchorIdx));
                            if (!found) break;
                            
                            size_t foundPos = (uint8_t*)found - buf;
                            if (foundPos < (size_t)anchorIdx) { i++; continue; }
                            
                            size_t start = foundPos - anchorIdx;
                            if (start < i) { i = foundPos + 1; continue; }
                            if (start >= scanLimit) break;
                            
                            bool match = true;
                            for (size_t j = 0; j < patLen; j++) {
                                if (mask[j] && buf[start + j] != pattern[j]) {
                                    match = false;
                                    break;
                                }
                            }
                            
                            if (match) results.push_back(addr + start);
                            i = start + 1;
                        } else {
                            results.push_back(addr + i);
                            i++;
                        }
                    }
                }
                free(buf);
            }
        }
        addr += regionSize;
    }
    
    return results;
}

} // namespace vcore


// ═══════════════════════════════════════════════════════════════
// SecCore - 安全防护
// ═══════════════════════════════════════════════════════════════

#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <unistd.h>
#include <dlfcn.h>
#include <pthread.h>

// ptrace 常量
#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif

extern "C" {
    int ptrace(int, pid_t, caddr_t, int);
}

namespace vcore {

SecCore& SecCore::inst() {
    static SecCore s;
    return s;
}

bool SecCore::isJailbroken() {
    if (_jbCached) return _jbResult;
    
    // 检测常见越狱路径 (使用混淆字符串)
    const char* paths[] = {
        "/var/jb",
        "/Applications/Cydia.app",
        "/Applications/Sileo.app",
        "/var/binpack",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt",
        "/usr/bin/ssh"
    };
    
    for (int i = 0; i < 9; i++) {
        struct stat s;
        if (stat(paths[i], &s) == 0) {
            _jbCached = true;
            _jbResult = true;
            return true;
        }
    }
    
    // 检测是否能打开越狱相关的 dylib
    void* h = dlopen("/Library/MobileSubstrate/MobileSubstrate.dylib", RTLD_LAZY);
    if (h) {
        dlclose(h);
        _jbCached = true;
        _jbResult = true;
        return true;
    }
    
    _jbCached = true;
    _jbResult = false;
    return false;
}

bool SecCore::isDebugged() {
    // 方法1: 检查 P_TRACED 标志
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    size_t size = sizeof(info);
    
    if (sysctl(mib, 4, &info, &size, NULL, 0) == 0) {
        if (info.kp_proc.p_flag & P_TRACED) {
            return true;
        }
    }
    
    // 方法2: 检查父进程是否为调试器
    pid_t ppid = getppid();
    if (ppid != 1) {
        char pathbuf[4096];
        int mib_path[4] = {CTL_KERN, KERN_PROCARGS, ppid, 0};
        size_t pathSize = sizeof(pathbuf);
        
        if (sysctl(mib_path, 4, pathbuf, &pathSize, NULL, 0) == 0) {
            // 检查是否为常见调试器
            if (strstr(pathbuf, "lldb") || strstr(pathbuf, "debugserver") || 
                strstr(pathbuf, "gdb") || strstr(pathbuf, "frida")) {
                return true;
            }
        }
    }
    
    return false;
}

bool SecCore::isFridaPresent() {
    // 方法1: 检查 Frida 默认端口
    // (在沙盒内可能无法检测，但不会崩溃)
    
    // 方法2: 检查已加载的 dylib
    uint32_t cnt = _dyld_image_count();
    for (uint32_t i = 0; i < cnt; i++) {
        const char* name = _dyld_get_image_name(i);
        if (!name) continue;
        
        // 检查 Frida 相关库
        if (strstr(name, "FridaGadget") || 
            strstr(name, "frida-agent") ||
            strstr(name, "libfrida")) {
            return true;
        }
    }
    
    // 方法3: 检查 Frida 的线程名
    // Frida 会创建名为 "gum-js-loop" 或 "frida" 的线程
    // 但在 iOS 上获取其他线程名比较困难，跳过
    
    return false;
}

void SecCore::denyDebugger() {
    // 仅在越狱环境下有效
    // 非越狱环境调用 ptrace 可能会失败但不会崩溃
    ptrace(PT_DENY_ATTACH, 0, 0, 0);
}

bool SecCore::isEnvironmentSafe() {
    // 综合检测
    if (isDebugged()) return false;
    if (isFridaPresent()) return false;
    
    // 可以添加更多检测...
    
    return true;
}

} // namespace vcore
