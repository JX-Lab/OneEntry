import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class AppVersionInfo {
  const AppVersionInfo({required this.name, required this.build});

  final String name;
  final int build;

  String get label => '$name · Build $build';
}

class GitHubReleaseInfo {
  const GitHubReleaseInfo({
    required this.build,
    required this.releaseUrl,
    required this.tag,
    this.versionName,
    this.notes,
  });

  final int build;
  final String releaseUrl;
  final String tag;
  final String? versionName;
  final String? notes;

  String get label =>
      versionName == null ? 'Build $build' : '$versionName · Build $build';
}

abstract final class AppInfoService {
  static const MethodChannel _channel = MethodChannel(
    'com.junxu.yibi/app_info',
  );

  static Future<AppVersionInfo?> currentVersion() async {
    try {
      final Map<Object?, Object?>? value = await _channel
          .invokeMapMethod<Object?, Object?>('getVersion');
      final String? name = value?['name'] as String?;
      final int? rawBuild = (value?['build'] as num?)?.toInt();
      if (name == null || rawBuild == null) return null;
      return AppVersionInfo(name: name, build: normalizeBuildNumber(rawBuild));
    } on Object {
      return null;
    }
  }

  static Future<bool> openReleaseUrl(String url) async {
    try {
      return await _channel.invokeMethod<bool>(
            'openReleaseUrl',
            <String, Object?>{'url': url},
          ) ??
          false;
    } on Object {
      return false;
    }
  }

  /// Flutter gives split APKs an ABI prefix: 1000 for 32-bit ARM,
  /// 2000 for arm64 and 4000 for x86_64. Releases use the original build.
  static int normalizeBuildNumber(int rawBuild) {
    for (final int offset in <int>[4000, 2000, 1000]) {
      if (rawBuild > offset && rawBuild < offset + 1000) {
        return rawBuild - offset;
      }
    }
    return rawBuild;
  }
}

abstract final class UpdateService {
  static const String releasesUrl =
      'https://github.com/TheAnonymous-sys/OneEntry/releases/latest';
  static const String _apiUrl =
      'https://api.github.com/repos/TheAnonymous-sys/OneEntry/releases/latest';
  static const Set<String> _repositoryOwners = <String>{
    'TheAnonymous-sys',
    'JX-Lab',
  };

  static Future<GitHubReleaseInfo> fetchLatest() async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      try {
        return await _fetchFromApi(client);
      } on Object {
        return await _fetchFromLatestRedirect(client);
      }
    } finally {
      client.close(force: true);
    }
  }

  static Future<GitHubReleaseInfo> _fetchFromApi(HttpClient client) async {
    final HttpClientRequest request = await client
        .getUrl(Uri.parse(_apiUrl))
        .timeout(const Duration(seconds: 8));
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'OneEntry-Android')
      ..set('X-GitHub-Api-Version', '2022-11-28');
    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 8),
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('GitHub 返回 ${response.statusCode}');
    }
    final String body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    return parseRelease(Map<String, Object?>.from(jsonDecode(body) as Map));
  }

  static Future<GitHubReleaseInfo> _fetchFromLatestRedirect(
    HttpClient client,
  ) async {
    final Uri latestUri = Uri.parse(releasesUrl);
    final HttpClientRequest request = await client
        .getUrl(latestUri)
        .timeout(const Duration(seconds: 8));
    request.followRedirects = false;
    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 8),
    );
    final String? location = response.headers.value(HttpHeaders.locationHeader);
    await response.drain<void>().timeout(const Duration(seconds: 8));
    if (response.statusCode < 300 ||
        response.statusCode >= 400 ||
        location == null) {
      throw HttpException('GitHub Releases 返回 ${response.statusCode}');
    }
    return parseReleaseUrl(latestUri.resolve(location).toString());
  }

  static GitHubReleaseInfo parseRelease(Map<String, Object?> json) {
    final String tag = json['tag_name'] as String? ?? '';
    final String body = json['body'] as String? ?? '';
    final int? build = parseBuildNumber(tag) ?? parseBuildNumber(body);
    if (build == null) {
      throw const FormatException('发布信息中没有构建号');
    }
    final String rawUrl = json['html_url'] as String? ?? '';
    final Uri? uri = Uri.tryParse(rawUrl);
    final List<String> segments = uri?.pathSegments ?? const <String>[];
    final bool safeUrl =
        uri?.scheme == 'https' &&
        uri?.host == 'github.com' &&
        segments.length >= 2 &&
        _repositoryOwners.contains(segments[0]) &&
        segments[1] == 'OneEntry';
    final RegExpMatch? versionMatch = RegExp(
      r'^\s*version\s*[:：]\s*v?([^\s]+)\s*$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(body);
    return GitHubReleaseInfo(
      build: build,
      releaseUrl: safeUrl ? rawUrl : releasesUrl,
      tag: tag,
      versionName: versionMatch?.group(1),
      notes: body.trim().isEmpty ? null : body.trim(),
    );
  }

  static GitHubReleaseInfo parseReleaseUrl(String value) {
    final Uri? uri = Uri.tryParse(value);
    final List<String> segments = uri?.pathSegments ?? const <String>[];
    final bool safeUrl =
        uri?.scheme == 'https' &&
        uri?.host == 'github.com' &&
        segments.length == 5 &&
        _repositoryOwners.contains(segments[0]) &&
        segments[1] == 'OneEntry' &&
        segments[2] == 'releases' &&
        segments[3] == 'tag';
    if (!safeUrl) throw const FormatException('无效的 GitHub 发布地址');
    final String tag = Uri.decodeComponent(segments[4]);
    final int? build = parseBuildNumber(tag);
    if (build == null) throw const FormatException('发布标签中没有构建号');
    return GitHubReleaseInfo(
      build: build,
      releaseUrl: uri.toString(),
      tag: tag,
    );
  }

  static int? parseBuildNumber(String value) {
    final RegExpMatch? tagMatch = RegExp(
      r'(?:release|debug)-build-(\d+)',
      caseSensitive: false,
    ).firstMatch(value);
    if (tagMatch != null) return int.parse(tagMatch.group(1)!);
    final RegExpMatch? bodyMatch = RegExp(
      r'^\s*build\s*[:：#]?\s*(\d+)\s*$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(value);
    return bodyMatch == null ? null : int.parse(bodyMatch.group(1)!);
  }

  static bool isNewer({
    required GitHubReleaseInfo latest,
    required AppVersionInfo current,
  }) => latest.build > current.build;
}
