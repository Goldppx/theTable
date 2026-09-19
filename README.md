# The Table

全新编写的 Flutter 校园助手原型，面向 Android 优先开发。

## 已完成

- Material 3 界面与 Android 12+ 动态取色
- 课程、地图、日历、个人中心四个入口
- 独立 `CampusGateway` 适配层，账户数据与界面解耦
- GitHub Actions：PR 构建检查、APK artifact、`v*` 标签自动发布 Release

## 本地运行

安装 Flutter stable 后，在仓库根目录执行：

```bash
flutter create --platforms=android --project-name=the_table --org=cn.edu.ncist.it .
flutter pub get
flutter run
```

## 校园系统接入

`lib/services/campus_gateway.dart` 当前返回演示课程。接入前应取得学校系统或服务运营方授权；认证 Cookie 和密码应只保存在设备的安全存储中。

## 发布

推送形如 `v0.1.0` 的标签，GitHub Actions 将构建并创建 Release。正式发布前请替换 Android applicationId、应用图标、签名密钥与隐私政策。
