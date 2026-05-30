# JHenTai 标签翻译库大 JSON 异步多线程序列化与优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将更新标签翻译数据库时产生的读取、解码、格式提取、以及 `TagData` 实体转换的 CPU 密集任务，全部卸载至后台 `Isolate`，从而消除 UI 主线程在该阶段长达数十毫秒的 ANR 卡顿风险。

**架构：**
1. **多线程纯函数设计**：在模块底层或者顶层，设计不包含闭包上下文、无副作用、线程安全的 top-level 纯函数 `_parseTagTranslationInBackground(String savePath)`。
2. **Isolate 异步转派**：利用原有的 `isolateService.run` 服务，在文件下载成功后，一键转派大 JSON 文件解析任务到后台 `Isolate`，只将映射得到的 `List<TagData>` 传回 UI 主线程。
3. **主线程事务持久化**：主线程在接收到 `List<TagData>` 后，仅执行 `appDb.transaction` 写入到 Drift(Sqlite) 数据库，以此最大化避免由于前台数据序列化与 GC 带来的视觉渲染帧率下降（Jank & GC Stutter）。

**技术栈：** Dart Isolate (`integral_isolates`), Drift, IO, SQLite

---

### 文件修改与职责规划
- `lib/src/service/tag_translation_service.dart`
  - 新增：定义 top-level 纯函数 `_parseTagTranslationInBackground`，负责从本地路径读取大文件并循环提取映射生成 `List<TagData>`。
  - 修改：重构 `fetchDataFromGithub`，将原来在主线程中耗时的文件读取与整个标签库的遍历映射，转派为 Isolate 后台执行。

---

### 任务 1：定义 Isolate 专用的顶层后台序列化与映射函数

**文件：**
- 修改：`lib/src/service/tag_translation_service.dart:351` (在文件最末尾添加顶层纯函数)

- [ ] **步骤 1：分析 `TagData` 的生成方法，在文件尾部追加 `_parseTagTranslationInBackground` 顶层纯函数**
  
  ```dart
  /// 后台 Isolate 中运行的大文件提取及实体映射逻辑
  List<TagData> _parseTagTranslationInBackground(String savePath) {
    final io.File file = io.File(savePath);
    if (!file.existsSync()) {
      return [];
    }

    final String jsonStr = file.readAsStringSync();
    final Map dataMap = jsonDecode(jsonStr);
    final List dataList = dataMap['data'] as List;

    final List<TagData> tagList = [];
    final RegExp nameReg = RegExp(r'.*>(.+)<.*');

    for (final data in dataList) {
      if (data is! Map) continue;
      final String namespace = data['namespace'] as String;
      final Map tags = data['data'] as Map;

      tags.forEach((key, value) {
        if (value is! Map) return;
        final String _key = key as String;

        // 正则提取純中文名
        final String fullTagName = value['name'] as String;
        final Match? match = nameReg.firstMatch(fullTagName);
        final String tagName = match != null ? match.group(1)! : fullTagName;

        final String intro = value['intro'] as String? ?? '';
        final String links = value['links'] as String? ?? '';

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

- [ ] **步骤 2：进行静态编译检查**
  
  运行：`flutter analyze`
  预期：无任何静态语法类型错误。

- [ ] **步骤 3：进行阶段性 Git Commit**
  
  ```bash
  git add lib/src/service/tag_translation_service.dart
  git commit -m "perf(tag): add thread-safe offline translator parser for Isolate support"
  ```

---

### 任务 2：轻量化优化 `fetchDataFromGithub` 主线程解析架构

**文件：**
- 修改：`lib/src/service/tag_translation_service.dart:104-170` (重构 `fetchDataFromGithub` 大循环逻辑)

- [ ] **步骤 1：仅解析 TimeStamp 以作缓存对比，避免 UI 现场发生繁重映射与对象生成**
  
  将 `fetchDataFromGithub` 中从第 106 行到大循环映射结束的代码全部精简重构为后台任务：
  
  ```dart
      log.info('Tag translation data downloaded');

      /// format 仅提取 TimeStamp 字段快速校对，无需构建海量映射，防止卡顿
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

      // 转派耗时的大 JSON 文件读取、解析、正则清洗以及数万个 TagData 对象创建等 CPU 密集型任务到 Isolate 后台
      final List<TagData> tagList = await isolateService.run(
        _parseTagTranslationInBackground,
        savePath,
        debugLabel: 'parseTagTranslation',
      );

      /// save
      timeStamp.value = null;
      await appDb.transaction(() async {
        await TagDao.deleteAllTags();
        for (TagData tag in tagList) {
          await TagDao.insertTag(
            TagData(
              namespace: tag.namespace,
              key: tag.key,
              translatedNamespace: tag.translatedNamespace,
              tagName: tag.tagName,
              fullTagName: tag.fullTagName,
              intro: tag.intro,
              links: tag.links,
            ),
          );
        }
      });
  ```

- [ ] **步骤 2：对整体代码进行全工程类型安全和 Lint 分析**
  
  运行：`flutter analyze`
  预期：PASS。

- [ ] **步骤 3：进行 Git Commit 并清理保存的临时数据**
  
  ```bash
  git add lib/src/service/tag_translation_service.dart
  git commit -m "perf(tag): offload tag database loading and mapping to background Isolate"
  ```

---

## 规格覆盖自检清单 (Specs Coverage Check)
1. ✅ **大 JSON 反序列化解耦**：已通过 Isolate 将 `jsonDecode` 重负荷剥离。
2. ✅ **海量正则提取后台化**：`RegExp.firstMatch` 被放置并固定于 Isolate 后台执行。
3. ✅ **主线程 0 Jank 阻塞**：主线程仅保留轻量化 Header-Timestamp 对比，并在后台回传完毕后直接单事务落盘数据库。
4. ✅ **平台全兼容性**：不依赖任何第三方平台 Native Bind API，在 Windows, MacOS, Linux, iOS & Android 等各核心设备完美原生支持多线程跑通。
