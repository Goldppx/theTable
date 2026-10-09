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

## 0.3.0 原生实现

Flutter 原生表单通过 CampusHttp 请求 CAS，按 prepareLogin → openSliderChallenge → verifySlider → submitLogin 顺序执行。CasCrypto 使用原版字符集生成 16 字符 IV 和 64 字符前缀，AES-128-CBC/PKCS7 后只传 Base64 密文。滑块 sign 同样调用 encryptPassword(JSON.stringify(payload), key)，key 取 smallImage 解码后的最后 16 字节。

SliderCaptcha function 8122 的实际配置为 canvasLength=280、画布 280×155、手柄 40、最大位移 240。smallImage 按 tagWidth/590×280−2 缩放为全高透明拼图条。轨迹是用户触摸产生的 a（水平位移）、b（垂直位移）、c（毫秒耗时），约每 20ms/移动 2px 采样。服务器 errorCode=1 才允许继续提交账号密码；不会求解验证码或合成拖动轨迹。

登录提交参数 username/password/captcha/_eventId=submit/cllt=userNameLogin/dllt=generalLogin/lt/execution，POST 地址保留 service 查询参数，与原版 parseLoginPage 返回的固定 actionUrl 一致。

手动跟随最多 12 次跳转，只允许原版四个 HTTPS origin；原版 HTTP auth.ncist.edu.cn 跳转升级 HTTPS。CAS 成功必须包含 ST- 票据、有效门户身份和业务会话。本科检查 EXESAC.SAAS.SessionId；研究生检查 JSESSIONID 与 SSO_LOGIN。原版 categoryWid/categoryWId=2000002 判为研究生，其余依据 categoryName。

CampusHttp 使用 CookieJar 处理域、路径、过期时间、Secure、HttpOnly。Cookie 在完成认证和业务会话验证后写入 FlutterSecureStorage；密码只在输入框内存中持有。进入教务页时通过 Android CookieManager 桥接原始 Set-Cookie 属性，退出账号会清除保存的会话和 WebView Cookie。

## 验证范围

测试使用独立 Python cryptography 生成 AES 与滑块 sign 向量，并模拟 CAS → 门户 → 教务完整请求流，检查缺少票据、滑块未验证、教务会话缺失、非学校跳转、Cookie 作用域等失败路径。

仍需真实校园账号在手机上验证完整流程，当前环境没有账号密码。登录实现已经替换为原生协议；教务课表读取仍为页面表格适配，研究生页面的课表解析兼容性待验证。

公开服务预检成功：带门户 service 的 CAS 登录 GET 返回 HTTP 200 和 JSESSIONID/route；移动端密码表单为 loginFromId，同 ID 的短信表单通过 cllt=userNameLogin 区分。toSliderCaptcha.htl 与 openSliderCaptcha.htl 均返回 HTTP 200，后者确实提供 smallImage/bigImage/tagWidth/yHeight。预检没有提交密码或验证码。解析同时支持原版 pwdFromId 和实际移动端密码表单。

## 0.3.1 跳转兼容与排障

用户反馈原版与 0.3.0 均出现“缺少 CAS 票据”。该消息由客户端的 ST- 查询参数检查生成，无法据此判断密码是否正确或学校故障。新实现把有效门户身份和业务会话作为成功条件，保持 errcode/data、学生身份、业务 Cookie 检查；兼容 HTTP 跳转、meta refresh 和独立脚本中的字面量 location 赋值/replace/assign。条件脚本不执行。所有跳转继续受学校 HTTPS origin 与次数限制约束。

每次重新准备认证都会重置内存中的临时 Cookie，避免半完成会话干扰重新登录。失败时可复制请求方法、域名、路径和 HTTP 状态；诊断不包含查询参数、请求体、账号、密码或 Cookie。

本次公开访问 CAS、门户与教务服务出现超时；当前环境网络与服务器故障无法区分。尚需手机端真实登录诊断确认现场根因。
