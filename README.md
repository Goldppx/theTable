# 应大通原版 APK · 动态取色验证版

基于 NCIST-IT/UEM-Connect-board v1.1.1 发布 APK。沿用原版 React Native / Hermes 界面、认证、教务、地图和本地存储。

Android 12+ 每次冷启动读取系统壁纸色板，替换原版浅色/深色主题中的 18 项颜色常量：主色、主色容器、背景、容器、选中背景、正文、辅助文字和边框。原版浅色/深色切换继续生效。运行中更换壁纸后，关闭应用并重新打开以刷新色板。Android 11 及以下保留原色。

原版错误色、成功色、课程分类色和浅色主题的白色表面/按钮文字保持原值。当前为验证版；学校账号登录和真实课表需要手机实测。

## 修改边界

- 原始 assets/index.android.bundle 保留，所有原始 assets 与 .so 在重打包后逐字节验证一致。
- 新增 DynamicBundle 原生类和 JSBundleLoader.createAssetLoader 入口。原始 Hermes 98 字符串表已审计，偏移记录在 palette.json。只修改 7 字节主题颜色常量及 SHA-1 尾部校验，不改变函数表、指令或字符串长度。
- 冷启动在应用私有目录生成主题 bundle，以只读文件加载。原 APK/bundle SHA256、常量偏移与系统资源均验证；失败记录 UEMDynamicColor 日志并回退原始 bundle。
- 安装包包名保留 cn.edu.ncist.it.uemconnect，版本 1.1.1-dynamic.1，versionCode 14，使用独立开发签名。
- 这是针对指定上游包的补丁工程，包含新增代码和复现脚本。上游业务源码仍由原作者维护。

## 构建

需要 Java 17、Python 3、Android SDK build-tools 35.0.0/platforms android-35。GitHub Actions 自动下载校验上游包，解码、生成原生代码、编译、打包、签名、检查 ZIP 和原文件一致性，然后运行 Android 启动及壁纸色板检查。

```sh
bash scripts/build.sh
```

APK 与 SHA256SUMS 位于 dist/。首次构建生成独立开发签名，CI 不保存私钥。每次 CI 构建的签名可能不同。

## 验证

脚本校验原 APK/bundle 的 SHA256 和 Hermes SHA-1，以及所有主题偏移。启动测试使用 Android 模拟器；原 APK仅提供 ARM64 原生库，模拟器需要 ARM64 native bridge。学校认证和课表仍需要真实手机账号验证。

安装后检查首页、浅色/深色主题、登录和课程读取。更换系统壁纸色彩后彻底关闭应用，再打开确认颜色变化。日志标签 UEMDynamicColor 仅输出主题校验状态与主色。

原版：https://github.com/NCIST-IT/UEM-Connect-board/releases/tag/v1.1.1
