# JHenTai 标签翻译库大 JSON 异步多线程序列化与优化设计方案

本设计方案旨在将 `TagTranslationService` 中从 GitHub 更新标签数据库时产生的大 JSON 文本解析、正则表达式分析以及大量的实体对象映射开销，彻底卸载至后台 `Isolate`，从而消除 UI 主线程在该阶段的明显掉帧与卡顿（Jank），保证用户流畅的操作体验。

---

## 1. 痛点分析与改进方向

### 1.1 痛点分析
在原有逻辑 `lib/src/service/tag_translation_service.dart:107-141` 中：
1. **大 JSON 解析挂起**：标签数据库 JSON 文件非常庞大。`jsonDecode(json)` 是一个 CPU 密集型操作，大文件在 UI 线程同步解析将瞬间阻塞主进程达数十毫秒，甚至可能导致低端机型出现短暂无响应（ANR）。
2. **海量正则提取耗时**：为了从标签的全名称富文本（如 `&lt;a href="..."&gt;中文标签&lt;/a&gt;`）中清洗出无标签的纯文本属性，在遍历几万个条目时，主线程上同步调用 `RegExp.firstMatch` 生成的高频字符串提取开销会导致非常严重的 CPU 占用与频繁 GC 内存抖动。

### 1.2 优化方向
* **多线程大文件解耦 (Isolate Pipe)**：在 `TagTranslationService.fetchDataFromGithub` 流程中，将下载到本地的文件的“读取”、“解析（Decode）”、“正则解析清洗”、“`TagData` 实体生成构建”这 4 大重计算瓶颈打包转移到外部的 Isolate 空闲线程中。
* **按需合并 Isolate**：通过原有的后台多线程管理服务 `IsolateService` 来统一调度与分派，确保与应用已有的编解码加速和 HTML 解析器保持最优的资源使用一致。
* **低内存抖动保障**：Isolate 解析完成后回收大 JSON 关联的所有复杂 Map 引用，返回给主线程的只有纯净轻量的 `List<TagData>`，极大地压降了 UI 线程的 GC 频次。

---

## 2. 架构设计与数据流分析

```
[UI 主线程]                                                  [后台 Isolate]
  |                                                              |
  |--- 1. 下载 JSON 并落盘成功 ----------------------------------->|
  |                                                              |
  |                                                       [多线程序列化器]
  |                                                         - 读取临时大 JSON 文件
  |                                                         - jsonDecode 文本转换为 Map
  |                                                         - 高性能实例化单个非重复 RegExp
  |                                                         - 遍历循环解析
  |                                                         - 重建实体 List<TagData>
  |<-- 2. 返回轻量 List<TagData> ---------------------------------|
  |                                                              |
  |--- 3. 极速将数据写入本地 appDb.transaction 事务 ----------------->|
  |                                                              |
  +--- 4. 清除临时磁盘文件，刷新 Timestamp ------------------------+
```

---

## 3. 具体修改设计

### 3.1 后台管道序列化方法
在 `lib/src/service/tag_translation_service.dart` 文件的模块底层，增加顶层辅助运行函数 `_parseTagTranslationInBackground`：

```dart
/// 后台 Isolate 中运行的大文件提取及实体映射逻辑
List<TagData> _parseTagTranslationInBackground(String savePath) {
  final io.File file = io.File(savePath);
  if (!file.existsSync()) {
    return [];
  }

  // 1. 读取大文本并高并发反序列化
  final String jsonStr = file.readAsStringSync();
  final Map dataMap = jsonDecode(jsonStr);
  final List dataList = dataMap['data'] as List;

  final List<TagData> tagList = [];

  // 2. 提取正则匹配器，避免在循环体内重复实例化 RegExp 降低开销
  final RegExp nameReg = RegExp(r'.*>(.+)<.*');

  for (final data in dataList) {
    if (data is! Map) continue;
    final String namespace = data['namespace'] as String;
    final Map tags = data['data'] as Map;

    tags.forEach((key, value) {
      if (value is! Map) return;
      final String _key = key as String;

      // 正则匹配提取纯中文名
      final String fullTagName = value['name'] as String;
      final Match? match = nameReg.firstMatch(fullTagName);
      final String tagName = match != null ? match.group(1)! : fullTagName;

      final String intro = value['intro'] as String? ?? '';
      final String links = value['links'] as String? ?? '';

      // EHNamespace 查找其中文命名空间描述并设置
      final EHNamespace? ehNs = EHNamespace.findNameSpaceFromDescOrAbbr(namespace);
      final String? translatedNamespace = ehNs?.chineseDesc;

      tagList.add(TagData(
        namespace: namespace,
        key: _key,
        translatedNamespace: translatedNamespace,
        tagName: tagName,
        fullTagName: fullTagName,
        intro: intro,
        links: links,
      ));
    });
  }

  return tagList;
}
```

### 3.2 替换 `fetchDataFromGithub` 主流程
将 `TagTranslationService.fetchDataFromGithub` 中的本地文件读写与转换重构为异步调用：

**原逻辑**：
```dart
    log.info('Tag translation data downloaded');

    /// format
    String json = io.File(savePath).readAsStringSync();
    Map dataMap = jsonDecode(json);
    Map head = dataMap['head'] as Map;
    Map committer = head['committer'] as Map;
    String newTimeStamp = committer['when'] as String;
    List dataList = dataMap['data'] as List;

    if (newTimeStamp == timeStamp.value) {
      log.info('Tag translation data is up to date, timestamp: $timeStamp');
      loadingState.value = LoadingState.success;
      io.File(savePath).delete();
      return;
    }

    List<TagData> tagList = [];
    for (final data in dataList) { ... }
```

**更新后的优化逻辑**：
```dart
    log.info('Tag translation data downloaded');

    /// 提取时间戳逻辑以支持缓存校对 (无需做高负载的整个标签转换)
    String json = io.File(savePath).readAsStringSync();
    Map dataMap = jsonDecode(json);
    Map head = dataMap['head'] as Map;
    Map committer = head['committer'] as Map;
    String newTimeStamp = committer['when'] as String;

    if (newTimeStamp == timeStamp.value) {
      log.info('Tag translation data is up to date, timestamp: $timeStamp');
      loadingState.value = LoadingState.success;
      io.File(savePath).delete();
      return;
    }

    // 将耗费性能的文件读取与数万个 TagData 的提取任务彻底移回 Isolate
    final List<TagData> tagList = await isolateService.run(
      _parseTagTranslationInBackground,
      savePath,
      debugLabel: 'parseTagTranslation',
    );
```

---

## 4. 健壮性与无损测试自检清单

1. **类型匹配**：`TagData` 为 drift schema 生成的标准静态对象类型，由于 Isolate 间不支持流或动态闭包，我们的 map 解析器只涉及基本的数据抓取及返回，不保存任何包含不可转移的复杂 Context 对象。
2. **内存瞬时抖动**：Isolate 处理完毕后其专设的堆内存会自动释放，主线程仅仅将得到的标准 `List<TagData>` 通过 `Sqlite` 批量写入数据库。
3. **兼容性**：此项改动不涉及上层任何 UI 画廊列表、翻译调用的 API 签名更改，极其无损和安全。
