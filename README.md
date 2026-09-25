# 一笔 · OneEntry

Flutter Android 工程，应用包名为 `com.junxu.yibi`。

当前 Flutter 界面正在按 HTML 原型逐页等效移植。首页整体结构、账户、成员、预算、统计、设置和记一笔页面已经建立；HTML 原型是最终 UI 与交互标准，不再将 Material 默认骨架视为设计稿。

SQLite 数据库与版本迁移已经接入：账户、成员、分类、账目、账目成员、预算、周期规则、导入批次和设置使用独立关系表；金额以整数分保存，转账、余额和多人分摊在事务中写入。

Android 本地通知、系统文件选择器、JSON / ZIP / XLSX 导入导出、同旅迁移 ZIP，以及预算、成员 / 账户归档和周期账目管理页面均已接入。当前 APK 仍应视为持续开发版本，需要继续以真机反馈校正 UI 细节。

## 本地运行

Flutter SDK 必须位于当前用户可写的位置，或允许它写入 `bin/cache`。之后执行：

```text
flutter pub get
flutter run
```

## 在私有 GitHub 仓库构建 APK

工程包含 `.github/workflows/android-debug.yml`。推送到 `main` 后会自动构建，也可以在仓库的 `Actions → Build Android APK → Run workflow` 手动触发。

成功后可在 workflow run 的 `Artifacts` 下载 `OneEntry-debug-apk`，也可以在私有仓库 Releases 中下载对应的预发布 APK。

工作流只使用 GitHub 官方 Actions，以及从 Flutter 官方仓库固定下载的 Flutter `3.41.4`。仓库必须先设置为 `Private`，再上传源代码。

## 下一阶段

- 根据真机截图继续做 HTML 原型的像素级对齐
- 增加通用 CSV / XLSX 第三方账单字段映射预览
- 完善编辑账目、删除账目和账户 / 成员详情交互
- 增加自动化集成测试与正式签名构建
