# 一笔 Android 固定签名

Android 只有在包名和签名证书都与已安装版本一致、且新版 `versionCode` 不低于旧版时，才能直接覆盖安装并保留应用内部 SQLite 数据。

本项目包名固定为 `com.junxu.yibi`，GitHub Actions 也会用运行编号自动提高 `versionCode`。还需要一次性配置固定签名：

1. 在可信电脑上生成并长期保存 `oneentry-release.jks`，不要提交到 Git。
2. 将密钥库文件转换为 Base64 文本。
3. 在 GitHub 仓库的 `Settings → Secrets and variables → Actions` 中添加：
   - `ONEENTRY_KEYSTORE_BASE64`
   - `ONEENTRY_KEY_ALIAS`
   - `ONEENTRY_KEY_PASSWORD`
   - `ONEENTRY_STORE_PASSWORD`
4. 四项 Secret 都存在时，工作流自动生成稳定签名的 release APK；缺少任何一项时仍会生成仅供测试的 debug APK。

必须永久备份密钥库及密码。丢失后无法再对同一已安装应用发布覆盖更新。

从目前的临时 debug 签名切换到固定 release 签名时，需要最后一次卸载旧应用。切换前先导出 ZIP 完整备份，安装 release 版后再导入；从此以后 release 版可以直接覆盖更新并保留数据。
