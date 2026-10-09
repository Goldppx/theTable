# 本地接续说明

项目：应大通 / theTable，仓库 Goldppx/theTable，PR #1，分支 feat/flutter-md3-rewrite。
当前版本 0.4.3+9，Flutter Material 3 Android 应用。

已实现：参考图深色布局、蓝色默认配色和动态取色开关、周课表与本地账号缓存、原生 CAS AES 登录与滑块认证、门户身份与本科/研究生会话检查、课前/早报/API 通知、包名与小程序 URL 快捷方式、高德 URI 地图和原生地图软件跳转。

登录细节见 docs/login-reverse-engineering.md。保留 Cookie HttpOnly/Secure/Path 的原生桥接；不要删除 scripts/configure_android.py 里的校园会话通道。校园服务的实时状态与真实账号登录仍需在设备上验证，不因编译和单元测试通过而宣称解决所有学校服务故障。

通知 API 与限制见 docs/notifications.md。前台 SSE、后台 JSON 周期检查，尚无厂商持续推送服务。雨课堂默认官网入口，实际微信小程序 URL Link 由用户配置。

本地构建见 docs/LOCAL_SETUP.md。Android 宿主文件由 flutter create + configure_android.py 生成；android_support/CampusTools.kt 是通知和快捷入口原生代码源。修改原生功能后运行生成脚本再构建。预览 APK 使用开发签名，正式发行需要自有长期签名配置；不要将密码、API 令牌和 keystore 放入 git。

继续开发前读取本文件、README.md、pubspec.yaml 与 .github/workflows/android.yml。遵循现有任务：功能完成并验证后提供可安装 APK，不只给计划。用户偏好中文、少确认、真实说明设备/账号尚未验证的部分。后续先解决编译/测试失败，再构建，不跳过检查。

## 0.4.3 界面整理

首页优先展示真实今日课程；合并个人页账号卡片；统一阅读宽度、输入框、按钮和间距；宽屏使用 Material NavigationRail。课表在窄屏、大字体和低高度下自动使用列表，也可手动切换；冲突课程使用稳定分栏。外观、设置和课程详情支持滚动。导入弹窗由自己的 State 管理控制器生命周期。地图定位中禁用重复请求。

新增冲突分栏与横屏大字体测试；预览加载 Material 图标字体。验证结果以本提交 Actions 为准；真实学校登录、地图和通知仍需手机验证。
