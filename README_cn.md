# JHenTai

![platform](https://img.shields.io/badge/Platform-Android-brightgreen)
![last-commit](https://img.shields.io/github/last-commit/jiangtian616/JHenTai)
[![downloads](https://img.shields.io/github/downloads/jiangtian616/JHenTai/total)](https://github.com/jiangtian616/JHenTai/releases)
[![downloads](https://img.shields.io/github/downloads/jiangtian616/JHenTai/latest/total)](https://github.com/jiangtian616/JHenTai/releases)
![star](https://img.shields.io/github/stars/jiangtian616/JHenTai)

[English](https://github.com/jiangtian616/JHenTai/blob/master/README.md) | 简体中文 | [한국어](https://github.com/jiangtian616/JHenTai/blob/master/README_kr.md)

面向 E-Hentai / EXHentai 的安卓应用。

## 下载

[<img src="https://raw.githubusercontent.com/jiangtian616/JHenTai/master/badges/download_from_github.png" alt="Download from GitHub" height="60">](https://github.com/jiangtian616/JHenTai/releases)
[<img src="https://raw.githubusercontent.com/jiangtian616/JHenTai/master/badges/get_it_on_obtainium.png" alt="Get it on Obtainium" height="60">](https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22top.jtmonster.jhentai%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fjiangtian616%2FJHenTai%22%2C%22author%22%3A%22jiangtian616%22%2C%22name%22%3A%22JHenTai%22%2C%22preferredApkIndex%22%3A0%2C%22additionalSettings%22%3A%22%7B%5C%22includePrereleases%5C%22%3Afalse%2C%5C%22fallbackToOlderReleases%5C%22%3Atrue%2C%5C%22filterReleaseTitlesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22filterReleaseNotesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22verifyLatestTag%5C%22%3Afalse%2C%5C%22sortMethodChoice%5C%22%3A%5C%22date%5C%22%2C%5C%22useLatestAssetDateAsReleaseDate%5C%22%3Afalse%2C%5C%22releaseTitleAsVersion%5C%22%3Afalse%2C%5C%22trackOnly%5C%22%3Afalse%2C%5C%22versionExtractionRegEx%5C%22%3A%5C%22v(.*)%5C%22%2C%5C%22matchGroupToUse%5C%22%3A%5C%22%241%5C%22%2C%5C%22versionDetection%5C%22%3Atrue%2C%5C%22releaseDateAsVersion%5C%22%3Afalse%2C%5C%22useVersionCodeAsOSVersion%5C%22%3Afalse%2C%5C%22apkFilterRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22invertAPKFilter%5C%22%3Afalse%2C%5C%22autoApkFilterByArch%5C%22%3Atrue%2C%5C%22appName%5C%22%3A%5C%22JHenTai%5C%22%2C%5C%22appAuthor%5C%22%3A%5C%22JTMonster%5C%22%2C%5C%22shizukuPretendToBeGooglePlay%5C%22%3Afalse%2C%5C%22allowInsecure%5C%22%3Afalse%2C%5C%22exemptFromBackgroundUpdates%5C%22%3Afalse%2C%5C%22skipUpdateNotifications%5C%22%3Afalse%2C%5C%22about%5C%22%3A%5C%22https%3A%2F%2Fgithub.com%2Fjiangtian616%2FJHenTai%2Fblob%2Fmaster%2FREADME.md%5C%22%2C%5C%22refreshBeforeDownload%5C%22%3Afalse%7D%22%2C%22overrideSource%22%3Anull%7D)

按设备架构选择对应 APK 安装：

- `arm64-v8a`：大多数新安卓设备
- `armeabi-v7a`：较老设备
- `x86_64`：较少见，常见于模拟器

更新时直接覆盖安装新版 APK 即可。

## 主要功能

- 在线阅读与下载画廊
- 下载归档、自动解压并阅读
- 移动端搜索、Tag 提示、跳页、以图搜图
- 收藏、评分、磁力、统计、评论、分享
- 密码登录、Cookie 登录、安卓 WebView 登录
- Tag 翻译、Tag 投票、关注 Tag、屏蔽规则
- 本地画廊阅读与安卓分享入口支持

## 截图

<img width="250" src="screenshot/mobile_v2.jpg"/>
<img width="250" src="screenshot/search.jpg"/>
<img width="250" src="screenshot/detail.png"/>
<img width="250" src="screenshot/read.jpg"/>
<img width="250" src="screenshot/setting_zh.jpg"/>
<img width="250" src="screenshot/download.jpg"/>

## 开发

```bash
flutter pub get
flutter build apk -t lib/src/main.dart --debug
```
