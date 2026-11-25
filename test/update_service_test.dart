import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService', () {
    test('从发布标签读取构建号', () {
      final GitHubReleaseInfo
      release = UpdateService.parseRelease(<String, Object?>{
        'tag_name': 'release-build-53',
        'html_url':
            'https://github.com/TheAnonymous-sys/OneEntry/releases/tag/release-build-53',
        'body': 'A stable release.',
      });

      expect(release.build, 53);
      expect(release.label, 'Build 53');
    });

    test('优先显示发布正文中的版本名和构建号', () {
      final GitHubReleaseInfo
      release = UpdateService.parseRelease(<String, Object?>{
        'tag_name': 'oneentry-release',
        'html_url':
            'https://github.com/TheAnonymous-sys/OneEntry/releases/tag/oneentry-release',
        'body': 'Version: 0.3.0\nBuild: 61\n\n改进更新检查。',
      });

      expect(release.build, 61);
      expect(release.versionName, '0.3.0');
      expect(release.label, '0.3.0 · Build 61');
    });

    test('不可信的发布链接回退到仓库发布页', () {
      final GitHubReleaseInfo release =
          UpdateService.parseRelease(<String, Object?>{
            'tag_name': 'release-build-54',
            'html_url': 'https://example.com/app.apk',
            'body': '',
          });

      expect(release.releaseUrl, UpdateService.releasesUrl);
    });

    test('从 GitHub 最新发布跳转地址读取构建号', () {
      final GitHubReleaseInfo release = UpdateService.parseReleaseUrl(
        'https://github.com/TheAnonymous-sys/OneEntry/releases/tag/release-build-53',
      );

      expect(release.build, 53);
      expect(release.tag, 'release-build-53');
    });

    test('拒绝其他仓库伪造的发布跳转地址', () {
      expect(
        () => UpdateService.parseReleaseUrl(
          'https://github.com/other/OneEntry/releases/tag/release-build-99',
        ),
        throwsFormatException,
      );
    });

    test('只有更高构建号才算新版本', () {
      const AppVersionInfo current = AppVersionInfo(name: '0.2.0', build: 53);
      const GitHubReleaseInfo newer = GitHubReleaseInfo(
        build: 54,
        releaseUrl: UpdateService.releasesUrl,
        tag: 'release-build-54',
      );
      const GitHubReleaseInfo same = GitHubReleaseInfo(
        build: 53,
        releaseUrl: UpdateService.releasesUrl,
        tag: 'release-build-53',
      );

      expect(UpdateService.isNewer(latest: newer, current: current), isTrue);
      expect(UpdateService.isNewer(latest: same, current: current), isFalse);
    });

    test('缺少构建号时拒绝无法比较的发布信息', () {
      expect(
        () => UpdateService.parseRelease(<String, Object?>{
          'tag_name': 'v0.2.0',
          'html_url': UpdateService.releasesUrl,
          'body': '没有构建号',
        }),
        throwsFormatException,
      );
    });
  });

  group('AppInfoService', () {
    const MethodChannel channel = MethodChannel('com.junxu.yibi/app_info');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('读取 Android 提供的版本信息', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'getVersion');
            return <String, Object?>{'name': '0.2.0', 'build': 2053};
          });

      final AppVersionInfo? version = await AppInfoService.currentVersion();

      expect(version?.label, '0.2.0 · Build 53');
    });

    test('还原 Flutter 分架构 APK 的构建号偏移', () {
      expect(AppInfoService.normalizeBuildNumber(1053), 53);
      expect(AppInfoService.normalizeBuildNumber(2053), 53);
      expect(AppInfoService.normalizeBuildNumber(4053), 53);
      expect(AppInfoService.normalizeBuildNumber(54), 54);
    });

    test('只通过平台通道打开发布链接', () async {
      String? openedUrl;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, 'openReleaseUrl');
            openedUrl =
                (call.arguments as Map<Object?, Object?>)['url'] as String?;
            return true;
          });

      final bool opened = await AppInfoService.openReleaseUrl(
        UpdateService.releasesUrl,
      );

      expect(opened, isTrue);
      expect(openedUrl, UpdateService.releasesUrl);
    });
  });
}
