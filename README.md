# JHenTai

![platform](https://img.shields.io/badge/Platform-Android-brightgreen)
![last-commit](https://img.shields.io/github/last-commit/jiangtian616/JHenTai)
[![downloads](https://img.shields.io/github/downloads/jiangtian616/JHenTai/total)](https://github.com/jiangtian616/JHenTai/releases)
[![downloads](https://img.shields.io/github/downloads/jiangtian616/JHenTai/latest/total)](https://github.com/jiangtian616/JHenTai/releases)
![star](https://img.shields.io/github/stars/jiangtian616/JHenTai)

English | [简体中文](https://github.com/jiangtian616/JHenTai/blob/master/README_cn.md) | [한국어](https://github.com/jiangtian616/JHenTai/blob/master/README_kr.md)

An Android app for E-Hentai and EXHentai.

## Download

[<img src="https://raw.githubusercontent.com/jiangtian616/JHenTai/master/badges/download_from_github.png" alt="Download from GitHub" height="60">](https://github.com/jiangtian616/JHenTai/releases)
[<img src="https://raw.githubusercontent.com/jiangtian616/JHenTai/master/badges/get_it_on_obtainium.png" alt="Get it on Obtainium" height="60">](https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22top.jtmonster.jhentai%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fjiangtian616%2FJHenTai%22%2C%22author%22%3A%22jiangtian616%22%2C%22name%22%3A%22JHenTai%22%2C%22preferredApkIndex%22%3A0%2C%22additionalSettings%22%3A%22%7B%5C%22includePrereleases%5C%22%3Afalse%2C%5C%22fallbackToOlderReleases%5C%22%3Atrue%2C%5C%22filterReleaseTitlesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22filterReleaseNotesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22verifyLatestTag%5C%22%3Afalse%2C%5C%22sortMethodChoice%5C%22%3A%5C%22date%5C%22%2C%5C%22useLatestAssetDateAsReleaseDate%5C%22%3Afalse%2C%5C%22releaseTitleAsVersion%5C%22%3Afalse%2C%5C%22trackOnly%5C%22%3Afalse%2C%5C%22versionExtractionRegEx%5C%22%3A%5C%22v(.*)%5C%22%2C%5C%22matchGroupToUse%5C%22%3A%5C%22%241%5C%22%2C%5C%22versionDetection%5C%22%3Atrue%2C%5C%22releaseDateAsVersion%5C%22%3Afalse%2C%5C%22useVersionCodeAsOSVersion%5C%22%3Afalse%2C%5C%22apkFilterRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22invertAPKFilter%5C%22%3Afalse%2C%5C%22autoApkFilterByArch%5C%22%3Atrue%2C%5C%22appName%5C%22%3A%5C%22JHenTai%5C%22%2C%5C%22appAuthor%5C%22%3A%5C%22JTMonster%5C%22%2C%5C%22shizukuPretendToBeGooglePlay%5C%22%3Afalse%2C%5C%22allowInsecure%5C%22%3Afalse%2C%5C%22exemptFromBackgroundUpdates%5C%22%3Afalse%2C%5C%22skipUpdateNotifications%5C%22%3Afalse%2C%5C%22about%5C%22%3A%5C%22https%3A%2F%2Fgithub.com%2Fjiangtian616%2FJHenTai%2Fblob%2Fmaster%2FREADME.md%5C%22%2C%5C%22refreshBeforeDownload%5C%22%3Afalse%7D%22%2C%22overrideSource%22%3Anull%7D)

Install the APK that matches your device ABI:

- `arm64-v8a`: most modern Android phones
- `armeabi-v7a`: older ARM devices
- `x86_64`: uncommon, mainly emulators or special devices

To update, install the new APK over the existing app.

## Features

- Online reading and gallery download
- Archive download, extraction, and reading
- Mobile search, tag suggestions, jump-to-page, and image search
- Favorites, rating, torrents, statistics, comments, and sharing
- Cookie login, password login, and Android WebView login
- Tag translation, tag voting, watched tags, and blocking rules
- Local gallery reading and Android share intent support

## Screenshots

<img width="250" src="screenshot/mobile_v2.jpg"/>
<img width="250" src="screenshot/search.jpg"/>
<img width="250" src="screenshot/detail.png"/>
<img width="250" src="screenshot/read.jpg"/>
<img width="250" src="screenshot/setting_en.jpg"/>
<img width="250" src="screenshot/download.jpg"/>

## Development

```bash
flutter pub get
flutter build apk -t lib/src/main.dart --debug
```
