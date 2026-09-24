# 一笔 · OneEntry

Flutter Android 工程，应用包名为 `com.junxu.yibi`。

当前阶段已建立品牌主题、首页、统计、设置和记一笔交互骨架。HTML 原型继续保存在上级目录，作为完整交互与数据迁移规则的参考。

当前 Flutter 骨架中的演示账目暂存在内存，重启会恢复示例数据。正式 SQLite 数据库尚未接入，避免在无法执行完整 Android 构建测试时引入未经验证的存储依赖。

## 本地运行

Flutter SDK 必须位于当前用户可写的位置，或允许它写入 `bin/cache`。之后执行：

```text
flutter pub get
flutter run
```

## 在私有 GitHub 仓库构建 APK

工程包含 `.github/workflows/android-debug.yml`。推送到 `main` 后会自动构建，也可以在仓库的 `Actions → Build Android APK → Run workflow` 手动触发。

成功后进入对应的 workflow run，在页面底部 `Artifacts` 下载 `OneEntry-debug-apk`。当前产物是可直接安装测试的 debug APK，保留 7 天。

工作流只使用 GitHub 官方 Actions，以及从 Flutter 官方仓库固定下载的 Flutter `3.41.4`。仓库必须先设置为 `Private`，再上传源代码。

## 下一阶段

- SQLite 数据库与版本迁移
- Android 本地通知
- 系统文件选择器与 JSON / ZIP / XLSX 导入导出
- 同旅迁移 ZIP 适配器
- 预算、成员 / 账户归档和周期账目完整页面
