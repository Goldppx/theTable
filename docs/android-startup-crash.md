# Android 启动 SIGILL 排查与 0.4.1 兼容构建

收到的日志显示 Android 17 / Evolution X 17、ARM64 在 FlutterJNI.loadLibrary → linker64.call_constructors 中 SIGILL。故障 PC 是 libflutter.so + 0x5d5f80，上一帧为 +0x4d4800。界面、校园认证与 Dart 业务代码尚未启动。

下载 0.4.0 ARM64 APK 并核对原生库 GNU Build ID：a379262188fde30cd427b404020a4621e931233d，与日志完全相同。APK 内原始代码反汇编：

```text
0x4d4800: bl  0x5d5f80
0x5d5f80: str x30, [sp, #-0x20]!
0x5d5f84: stp x20, x19, [sp, #0x10]
```

故障入口在原始包中为基础 ARM64 指令。用户确认启用了注入模块，具体名称尚未取得。运行时补丁、内存代码变化以及系统加载环境是待验证假设，当前证据不足以认定某个模块或 ROM 为唯一根因。若可取得完整 tombstone 的 memory near pc，可进一步比较运行时故障指令与 APK 原始字节。

0.4.1 使用 AGP packaging.jniLibs.useLegacyPackaging=true，安装时将原生库解压成独立文件，隔离从 base.apk 直接 mmap 原生库的加载路径。保留官方 Flutter 3.47.5 引擎与原生库指令；保留原有渲染设置。这是一项兼容性诊断改动，实际设备上的 SIGILL 修复仍需验证。

CI 在静态分析、单元/界面测试和三 ABI release 构建后，增加 Android 17 API 37 x86_64 模拟器三次冷启动存活检查，并保留 logcat 和截图。此检查覆盖普通 Android 启动，ARM64 Evolution X + Root 注入环境需手机实测。

设备验证：

1. 在 LSPosed/相关模块作用域中移除 cn.edu.ncist.it.the_table，并使用所用 Root 管理器提供的应用注入排除设置；按照管理器要求重启。
2. 可先启动 0.4.0，确认排除注入是否改变结果。
3. 安装 0.4.1 兼容包并启动，核对进程存活与首页显示。预览签名可能不同，卸载会清除本机缓存。
4. 仍有崩溃时保留新的完整日志、APK 版本、实际机型/SoC 和具体模块名称；优先获取 tombstone 的 memory near pc。

符号化参考：https://github.com/flutter/flutter/blob/main/engine/src/flutter/docs/Crashes.md
AGP 原生库打包设置：https://developer.android.com/reference/tools/gradle-api/8.13/com/android/build/api/dsl/JniLibsPackaging
