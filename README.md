# 应大通 / theTable · 0.2.0

Flutter / Material 3 校园客户端，按参考截图调整首页、地图、周课表与个人中心。

- 深色卡片、四栏底部导航；浅色 / 深色 / 跟随系统及 Android 12+ 动态取色。
- 7 天 × 10 节的周课表，周次筛选、课程详情、冲突课程并排显示、字体放大与窄屏滚动。
- 本地课程 JSON 导入、按学号缓存。空课表显示导入引导；生产界面不会填入演示课程。
- 平面地图（OpenStreetMap）与卫星图（Esri）、实际定位、长按添加标签、本机标签管理。
- 校园门户登录网页处理密码与验证码；本机仅保存身份资料。当前提供一个活动网页登录会话，移除账号同时清除 Cookie 与该账号课表。

## APK 下载

PR 分支推送后，GitHub Actions 执行分析、测试和分 ABI 构建，并发布带完整提交 SHA 的 Preview Release。现代 Android 手机使用 `theTable-0.2.0-arm64-v8a.apk`；32 位设备选 armeabi-v7a；模拟器选 x86_64。Release 附 SHA256SUMS。

预览包使用 Flutter 生成工程的开发签名配置。正式发布应配置固定发布密钥。旧安装包签名不同的设备需卸载旧版后安装；卸载会移除本机缓存。

## 学校课表

日历页刷新按钮进入 `my1.ncist.edu.cn` 校园门户，从门户打开个人课表后选择“读取课表”。适配器读取同源 HTML 周课表的可见单元格，在确认弹窗核对名称、节次和周次后保存。学校真实页面兼容性仍需账号验证；跨域 iframe、非表格页面、未知布局会保留旧缓存并提示使用 JSON 导入。

不将门户登录成功等同于课表同步成功。当前没有验证学校 API、全校空教室接口、多账号独立网页登录会话；“教室”仅统计个人课表已知占用。

“我的 → 设置”可选择学期第一周开始日期，自动按周一对齐。JSON 也可指定 semesterStart（周一）及 totalWeeks。

## 导入 JSON

日历页右上角菜单 → 导入课表 JSON。完整文档校验成功后覆盖当前账号的课程缓存。

```json
{
  "semesterStart": "2026-09-07",
  "totalWeeks": 20,
  "courses": [
    {
      "name": "数据结构",
      "teacher": "张老师",
      "room": "明德楼 30504",
      "weekday": 1,
      "startPeriod": 3,
      "endPeriod": 4,
      "weeks": [1, 3, 5, 7, 9, 11, 13, 15],
      "colorIndex": 0
    }
  ]
}
```

也可直接导入 courses 数组。weekday 为 1（周一）至 7（周日），节次为 1–10，weeks 为明确的 1–30 周次列表（空列表表示每周）。同一课程多个不同上课时间应分别列出。colorIndex 选择固定课程色板。

地图标注使用 WGS84 坐标；初始中心为华北科技学院，详细校内地点由长按新增，避免填入未经核实的建筑位置。地图依赖设备网络，定位仅在点击定位按钮后申请权限。

## 本地构建

Flutter 3.47.5 / Java 17 / Android SDK。

```sh
flutter create --platforms=android --project-name=the_table --org=cn.edu.ncist.it .
rm -f test/widget_test.dart
python3 scripts/configure_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

测试覆盖课程字段、单/双周解析、导入失败保留缓存、首页进入课表、课程详情、外观切换和 320px / 双倍字号布局；构建同时生成 UI 预览图片。
