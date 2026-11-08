# Android 发布签名

Release 构建使用项目维护者保管的长期密钥；没有有效配置就停止，不回退到 debug 签名。普通 Debug CI 无需任何签名 Secret。

## 只有 Android 与 Termux

在 Termux 中生成一次密钥即可，后续构建不用重新生成：

```bash
pkg update
pkg install openjdk-21
umask 077
keytool -genkeypair -v \
  -keystore ~/tixun-release.jks -storetype JKS \
  -alias tixun -keyalg RSA -keysize 2048 -validity 10000
```

按提示设置密码并填写证书信息。密钥密码可直接回车使用密钥库密码。不需要付费证书或企业账号。请在手机之外保留密钥和密码的安全备份；以后覆盖安装更新仍需要这把密钥。Base64 只是编码，不能代替加密。

将以下内容存入仓库 Settings → Secrets and variables → Actions → Repository secrets，不要发到聊天、Issue 或提交到 Git：

| Secret | 值 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 完整 `.jks` 文件的 Base64，可包含换行 |
| `ANDROID_KEYSTORE_PASSWORD` | 密钥库密码 |
| `ANDROID_KEY_PASSWORD` | 密钥密码，通常与密钥库密码相同 |
| `ANDROID_KEY_ALIAS` | **可选**，省略或留空时为 `tixun`；只有生成时使用了其他别名才需要填写 |

也可在 Termux 上传，密码通过交互提示输入：

```bash
pkg install gh
gh auth login --web
base64 -w 0 ~/tixun-release.jks |
  gh secret set ANDROID_KEYSTORE_BASE64 --repo mumu-lhl/tixun
gh secret set ANDROID_KEYSTORE_PASSWORD --repo mumu-lhl/tixun
gh secret set ANDROID_KEY_PASSWORD --repo mumu-lhl/tixun
```

## 自动构建与验证

推送版本标签时，发布工作流显式将签名 Secrets 传给复用 CI。也可手动运行 **Build and verify**，勾选 `android_release`，构建签名 APK 而不创建 Release。

签名脚本只在 Runner 临时目录还原密钥（目录权限 0700、文件权限 0600）。`keytool` 校验密钥库密码与别名并获取证书指纹；Gradle 从环境变量读取配置并检查私钥密码。构建后用 `apksigner verify` 验证签名，并核对 APK 证书与配置密钥一致；另行检查产物确为 Release 模式。失败时不会上传 APK 或发布版本。临时密钥在失败/取消后的清理步骤移除，不放入缓存、源码目录或 Artifact。

不要把密码写进命令参数或开启 shell 调试输出。脚本不输出工具原始错误，避免泄露凭据。证书本身及其 SHA-256 指纹是公开信息，不是私钥。

本地签名构建需要设置 `ANDROID_KEYSTORE_PATH`（绝对路径）、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_PASSWORD`，可选 `ANDROID_KEY_ALIAS`，再运行 `flutter build apk --release`。可通过 shell 的 `read -rs` 读入密码，避免写入命令历史。

## 从旧版本迁移

v0.5.2 及之前的开发签名 APK 不能直接升级到新签名。先在题训中导出完整学习数据备份，再卸载旧版、安装新签名版本并恢复备份。此后保持同一密钥及递增版本号，即可覆盖更新。既有公开 Release 附件不会被这次配置修改。
