# 登录协议核对（2026-10-05）

参考原项目 NCIST-IT/UEM-Connect-board 的 v1.1.0 发布 APK：
https://github.com/NCIST-IT/UEM-Connect-board/releases/tag/v1.1.0

APK SHA256: db164ff9634bf5b637ced3916c70a5604166b3b411d3b983a63490a164badcb8

提取 assets/index.android.bundle，file 检测为 Hermes bytecode v98；使用 P1sec/hermes-dec 解汇编，并交叉检查伪代码。伪代码有不支持指令的警告，因此只采用能够核对的 URL、字段和请求流程，不把它当作完整原始源码。

## 实际观察

- auth 模块 1318：统一认证 service 是信息门户 /login，portalService 指向 /xs/index.html#/。
- prepareLogin：读取 execution、lt、pwdEncryptSalt，调用 checkNeedCaptcha.htl，根据 captchaSwitch=2 展示滑块。
- submitLogin：密码为 AES CBC 加密后的 Base64，提交 username/password/captcha/_eventId/cllt/dllt/lt/execution；然后跟随 CAS 重定向并读取门户身份。
- adaptPortalIdentity（function 7811）：验证 errcode=0 和 data 对象；学号取 studentNumber/studentNo/xh/userNo/loginName/username，缺失时使用输入账号。姓名取 name/realName/userName/xm。userName 不是学号。
- 专业缺失时取 deptName/departmentName 的末级，培养层次取 categoryName，组织取部门字段。
- 本科教务 establishJwxtSession：jw.cidp.edu.cn/LoginHandler.ashx，Referer 是门户根地址，检查 EXESAC.SAAS.SessionId。研究生使用 gms.ncist.edu.cn。
- 直接获取学校公开登录页成功，页面包含 execution、16 字符 pwdEncryptSalt 和 captchaSwitch=2。未发送密码或测试虚构登录。

## 本次实现边界

Flutter 继续使用学校 WebView 页面执行密码加密、滑块验证和 CAS 跳转；没有实现原版的 native authFetch、AES 或独立滑块。修复的是门户身份字段映射、会话建立后的重复检测、错误响应验证、账号兜底和本科教务入口。账号仅暂存内存，不读取或保存密码。门户身份保存在安全存储中，WebView 使用其自身 Cookie 存储。

身份成功读取不等于教务 Session 已验证；没有真实校园账号，无法验证完整登录和教务课表流程。发布包需要用户在设备上验证。研究生课表同步尚未实现。
