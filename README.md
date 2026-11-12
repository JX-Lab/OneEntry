<div align="center">
  <img src="assets/branding/oneentry_icon.png" alt="一笔" width="112">

# 一笔 OneEntry

### 记下一笔，也看清共同生活

一款无需注册、数据留在手机里的 Android 账本。
适合个人、伴侣、家庭和旅行同行者一起记录收支。

[![Build Android APK](https://github.com/JX-Lab/OneEntry/actions/workflows/android-debug.yml/badge.svg)](https://github.com/JX-Lab/OneEntry/actions/workflows/android-debug.yml)

[下载最新版本](https://github.com/JX-Lab/OneEntry/releases) · [查看构建状态](https://github.com/JX-Lab/OneEntry/actions)

</div>

---

## 为什么是一笔

**打开就能记。**
金额框直接弹出数字键盘，支持算式、最近分类和「再记一笔」。语音记账可随时关闭，不打扰手动记账流程。

**一本账，多个人一起用。**
每笔账可关联一个或多个成员，既能按 AA 均摊，也能把整笔金额计入每位成员的统计。

**不登录，不强制上云。**
账本默认只保存在设备内。你可以随时导出完整备份，也可以使用本地快照恢复误操作前的账本。

## 你可以用它做什么

### 快速记账

- 记录支出、收入、转账和余额调整。
- 金额框可直接输入 `+ - × ÷` 和括号，保存时自动计算。
- 最近使用的账户与分类会优先选中。
- 从账目详情一键「再记一笔」。
- 可选语音记账：说出「昨天打车二十块」，确认草稿后再保存。

### 看懂自己的钱去了哪里

- 按日、月、年或全部时间查看账目。
- 全局搜索分类、账户、成员、金额、日期和备注。
- 月度总预算与分类预算。
- 收支趋势、分类构成、成员构成和明细下钻。
- 账户余额和资产、负债视图。

### 让记账更容易坚持

- 每日记账提醒，可自定义时间。
- 按天、周、月或年管理周期账目。
- 点击周期提醒，直接进入已填好的记账草稿。
- 设置页显示下次提醒和上次成功发送时间。

### 长期保护账本

- 导出 JSON、ZIP 或 XLSX 完整备份。
- 从一笔备份、同旅、时光序和通用表格导入数据。
- 每周自动生成本地快照。
- 导入、恢复和清空数据前，自动保留保护快照。
- 可在设置中手动创建、恢复或删除快照。

> 本地快照会随应用卸载一起删除，不能代替导出到其他位置的完整备份。

### 显示与无障碍

- 日间、夜间和跟随系统主题。
- 多种主题色与文字大小。
- 增强颜色对比。
- 红色觉、绿色觉、蓝黄色觉异常与全色盲模式。
- 收入与支出同时使用颜色、正负号、文字和不同图表线型表达。

## 安装

一笔支持 Android 6.0 及以上系统。

1. 打开 [Releases](https://github.com/JX-Lab/OneEntry/releases)。
2. 下载适合设备的 APK。
3. 允许浏览器或文件管理器安装来自该来源的应用，然后完成安装。

| APK | 适用设备 |
| --- | --- |
| `arm64-v8a` | 绝大多数现代 Android 手机和平板 |
| `armeabi-v7a` | 较旧的 32 位 ARM 设备 |
| `x86_64` | Android 模拟器或 x86 设备 |

如果不确定，通常选择 `arm64-v8a`。

## 数据与隐私

- 无需注册账号。
- 账本默认保存在应用内部的 SQLite 数据库中。
- 应用本身不会将账本上传到一笔的服务器。
- 语音转写由 Android 系统中已安装的识别服务处理，可能根据该服务的能力使用网络。
- 转写后的金额、分类、日期、账户和成员解析在本地完成。

### 可选权限

| 权限 | 用途 |
| --- | --- |
| 麦克风 | 语音记账；可在设置中完全关闭语音入口 |
| 通知 | 每日提醒和周期账目提醒 |
| 闹钟和提醒 | Android 12 及以上系统中准时发送每日提醒 |

## 常见问题

<details>
<summary><strong>账本会自动同步到云端吗？</strong></summary>

不会。一笔目前是本地优先账本，不要求登录，也不会自动上传账本。

</details>

<details>
<summary><strong>换手机或卸载前需要做什么？</strong></summary>

请先从设置导出 ZIP 或 JSON 完整备份，并将文件保存到其他设备或云盘。应用内的快照无法在卸载后保留。

</details>

<details>
<summary><strong>账目数量有上限吗？</strong></summary>

应用没有人为设置账目条数上限。日常个人长期使用通常不会触及存储容量问题；一次导入极大量历史账目时，启动、搜索和统计可能变慢。

</details>

<details>
<summary><strong>语音记账为什么可能联网？</strong></summary>

语音转写依赖手机安装的 Android 语音服务。应用不强制离线模型，以便在可用时获得更好的普通话识别效果。

</details>

## 反馈

如果遇到问题或有功能建议，欢迎在 [GitHub Issues](https://github.com/JX-Lab/OneEntry/issues) 中说明设备型号、Android 版本和复现步骤。

<details>
<summary><strong>开发者信息</strong></summary>

### 技术栈

- Flutter `3.41.4`
- Dart `3.11`
- SQLite
- Android Kotlin

### 本地运行

需要 Flutter、Android SDK 和 JDK 17。

```bash
flutter pub get
flutter run
```

### 质量检查

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

### 构建

推送到 `main` 后，GitHub Actions 会运行格式检查、静态分析并按 CPU 架构生成 APK。如果仓库已配置签名 Secrets，生成 release APK；否则生成 debug APK。

- Android 应用 ID：`com.junxu.yibi`
- 数据库：`oneentry.db`
- CI 工作流：`.github/workflows/android-debug.yml`

</details>
