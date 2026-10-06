# 将 ChatGPT 工作项目接续到本地

## 同步源码

安装 Git、Flutter 3.47.5（或与 CI 一致的可用版本）、Android Studio/Android SDK 和 Java 17，然后运行：

```sh
git clone --branch feat/flutter-md3-rewrite https://github.com/Goldppx/theTable.git
cd theTable
flutter doctor
flutter create --platforms=android --project-name=the_table --org=cn.edu.ncist.it .
# 删除 flutter create 自动生成的模板 test/widget_test.dart（保留项目自己的测试）
python scripts/configure_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

APK 位于 build/app/outputs/flutter-apk/。一般 Android 手机选择 arm64-v8a。CI 已提供相同生成、测试和构建流程，适合暂时不安装本地 Android 工具链时使用。

生成脚本针对新建 Android 宿主执行一次；已经执行过后不需要每次重复。要重新生成宿主请先备份自己的 Android 签名/构建修改，再重新生成干净模板。

## 在 ChatGPT 桌面端继续

登录同一账号，打开 Projects/项目。给项目添加本地 theTable 文件夹：项目菜单 → Edit project/编辑项目 → Add folder/添加文件夹；需要时将该文件夹设为 Make primary/主要文件夹。确认新工作对话能够访问这个目录。

在新的本地工作对话发送：

> 继续开发应大通项目。先读取 docs/HANDOFF.md、docs/notifications.md、README.md 和构建工作流，然后检查当前分支和 git 状态。保留 CAS 登录实现与通知配置，按后续需求修改，运行分析、测试并构建 APK。

源码通过 Git 同步；聊天同步与文件夹访问是两件独立的事。不要假设云端临时工作目录或附件已经完整存在本地。参考图和其他附件如后续仍需要，请另存到本地项目并作为新对话附件。工作对话历史与 Codex 历史分开，HANDOFF.md 用于跨工具衔接上下文。

官方文档：https://learn.chatgpt.com/docs/projects?surface=app
