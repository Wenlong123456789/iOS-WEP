# VansonLoader (精简版)

**仅保留内存扫描 / 修改功能的 VansonLoader dylib。**

- 悬浮按钮召唤面板
- 内存搜索（精确 / 模糊等）
- 结果列表、数值修改、锁定
- 点击空白处正确隐藏面板（已修复半透明问题）

已移除：工具箱（指针/RVA/特征码/脚本/监控）、辅助工具、关于页、相关引擎与模型源文件。

## Build

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## License

GPL-3.0
