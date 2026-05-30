# JHenTai 性能与网络传输无损优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在不增加任何新功能的前提下，完成 Isolate HTML 异步解析引擎、网络缓存非阻塞化编解码以及 TCP 连接池 Keep-Alive 传输调优这三项纯架构级优化，显著降低 UI 滑动卡顿、提升大图并发并行流传输速度并削减内存开销。

**架构：**
1. **多线程 HTML 卸载**：通过在 `EHRequest._parseResponse` 中接入 `isolateService.run`，使传入的 `HtmlParser` 统一在后台 Isolate 运行，实现 UI 主线程 0 阻塞。
2. **轻量化缓存拦截器**：修改 `EHCacheManager`，将高频的大 JSON Headers 序列化和反序列化以及大 String 文本编解码全部交由 `isolateService` 后台异步解析。
3. **Dio 并发与 TLS 握手优化**：修改 `EHRequest` 初始化 Dio 时的适配器配置，调整 TCP 并发连接限额与空闲连接保活时长。

**技术栈：** Dart Isolate (`integral_isolates`), Dio (`httpClientAdapter`), Drift (SQLite)

---

### 文件修改与职责规划
- `lib/src/network/eh_request.dart`
  - 修改 `_parseResponse`：在 Isolate 中处理所有的 HTML Parser。
  - 修改 `doInitBean`：重构 Dio 构建流程，添加 `httpClientAdapter` 传输管道并发与保活配置。
- `lib/src/network/eh_cache_manager.dart`
  - 修改 `_saveResponse` 和 `toResponse`：在 `onRequest`/`onResponse` 异步拦截阶段，使用 `isolateService.run` 进行异步 Headers json-serialize 与 body byte 编解码转化。

---

### 任务 1：Isolate 异步响应解析管道重构

**文件：**
- 修改：`lib/src/network/eh_request.dart`

- [ ] **步骤 1：分析 `_parseResponse` 的运作机制并设计后台辅助解析器**
  由于闭包（Closure）不能跨 Isolate 传输，而 `HtmlParser` 传入的均为静态类方法（如 `EHSpiderParser.galleryPage2GalleryPageInfo`），我们需要设计一个标准的 top-level 或 static 的封装辅助解析函数，用于在 Isolate 中执行。
  
  在 `lib/src/network/eh_request.dart` 尾部定义 top-level 辅助解析方法：
  ```dart
  /// 用于在后台 Isolate 中被反调的非闭包解析器
  T _isolateHtmlParserExecutor<T>(List<dynamic> params) {
    final HtmlParser<T> parser = params[0] as HtmlParser<T>;
    final Headers headers = params[1] as Headers;
    final dynamic data = params[2];
    return parser(headers, data);
  }
  ```

- [ ] **步骤 2：重写 `_parseResponse` 函数**
  将原有的同步执行改为通过 `isolateService.run` 异步唤起。
  对 `lib/src/network/eh_request.dart` 中的 `_parseResponse` 行 945-950 进行精准替换：
  ```dart
  Future<T> _parseResponse<T>(Response response, HtmlParser<T>? parser) async {
    if (parser == null) {
      return response as T;
    }
    return isolateService.run(
      _isolateHtmlParserExecutor,
      [parser, response.headers, response.data],
      debugLabel: 'isolateHtmlParser',
    );
  }
  ```

- [ ] **步骤 3：进行静态类型与编译测试**
  运行 `flutter analyze` 确保类型参数 `T` 与 `HtmlParser` 在多线程传递时完美符合强类型校验。

- [ ] **步骤 4：创建 Git 本地提交记录**
  ```bash
  git add lib/src/network/eh_request.dart
  git commit -m "perf(network): offload HTML spider parsers to background Isolate thread"
  ```

---

### 任务 2：网络缓存读写非阻塞化 (I/O 与编解码架构优化)

**文件：**
- 修改：`lib/src/network/eh_cache_manager.dart`

- [ ] **步骤 1：异步优化 `CacheResponse.fromResponse` 多线程构建**
  原有的 `CacheResponse.fromResponse` 为同步方法，我们在其同级新增一个 `fromResponseAsync` 异步构建方法。
  
  在 `lib/src/network/eh_cache_manager.dart` 中的 `CacheResponse` 类内修改并新增如下静态辅助转换函数以及 `fromResponseAsync`：
  ```dart
  // 设计后台数据序列化执行器
  static List<Uint8List> _serializeInBackground(List<dynamic> args) {
    final ResponseType type = args[0] as ResponseType;
    final dynamic contentData = args[1];
    final Map<String, List<String>> headersMap = args[2] as Map<String, List<String>>;

    final Uint8List serializedContent = CacheResponse._serializeContent(type, contentData);
    final Uint8List serializedHeaders = utf8.encode(jsonEncode(headersMap));
    return [serializedContent, serializedHeaders];
  }

  static Future<CacheResponse> fromResponseAsync(Response response, CacheOptions options) async {
    // 将 Headers 序列化和 Content 序列化全部下推至 Isolate
    final List<Uint8List> results = await isolateService.run(
      _serializeInBackground,
      [response.requestOptions.responseType, response.data, response.headers.map],
      debugLabel: 'cacheSerialize',
    );

    return CacheResponse(
      content: results[0],
      expireDate: DateTime.now().add(options.expire),
      headers: results[1],
      cacheKey: CacheOptions.defaultCacheKeyBuilder(response.requestOptions),
      url: response.requestOptions.extra[EHCacheManager.realUriExtraKey] ?? response.requestOptions.uri.toString(),
    );
  }
  ```

- [ ] **步骤 2：优化 `toResponse` 异步反序列化反写**
  类似的，设计可以在异步阶段预先解码的无阻塞 `toResponseAsync` 方法。
  
  在 `CacheResponse` 内加入后台反序列化执行器配合 `toResponseAsync`：
  ```dart
  static List<dynamic> _deserializeInBackground(List<dynamic> args) {
    final ResponseType type = args[0] as ResponseType;
    final Uint8List contentBytes = args[1] as Uint8List;
    final Uint8List headersBytes = args[2] as Uint8List;

    final dynamic deserializedContent = CacheResponse._deserializeContent(type, contentBytes);
    final Map<String, dynamic> headersMap = jsonDecode(utf8.decode(headersBytes)) as Map<String, dynamic>;
    return [deserializedContent, headersMap];
  }

  Future<Response> toResponseAsync(RequestOptions options) async {
    final List<dynamic> results = await isolateService.run(
      _deserializeInBackground,
      [options.responseType, content, headers],
      debugLabel: 'cacheDeserialize',
    );

    final dynamic data = results[0];
    final Map<String, dynamic> headersMap = results[1] as Map<String, dynamic>;

    Headers h = Headers();
    headersMap.forEach((key, value) => h.set(key, value));

    return Response(
      data: data,
      extra: {extraKey: cacheKey},
      headers: h,
      statusCode: 304,
      requestOptions: options,
    );
  }
  ```

- [ ] **步骤 3：在拦截器调用处更新为异步调用 API**
  修改 `EHCacheManager` 中的拦截器 `onRequest` 与 `_saveResponse` 方法：
  
  对于 `onRequest` (第 58 行)：
  ```dart
  log.trace('cache hit: ${options.uri.toString()}');
  cacheResponse = await _updateCacheResponse(cacheResponse, cacheOptions);
  
  // 改为调用新设计的异步反序列化方法
  final Response resolvedResponse = await cacheResponse.toResponseAsync(options);
  return handler.resolve(resolvedResponse, true);
  ```

  对于 `_saveResponse` (第 152 行)：
  ```dart
  Future<void> _saveResponse(Response response, CacheOptions cacheOptions) async {
    // 改为调用新设计的异步序列化方法
    CacheResponse cacheResponse = await CacheResponse.fromResponseAsync(response, cacheOptions);

    await _getCacheStore(cacheOptions).upsertCache(cacheResponse);

    response.extra[CacheResponse.extraKey] = cacheResponse.cacheKey;
  }
  ```

- [ ] **步骤 4：进行静态类型分析**
  执行 `flutter analyze`，验证新逻辑无任何类型丢失或冲突。

- [ ] **步骤 5：创建 Git 本地提交记录**
  ```bash
  git add lib/src/network/eh_cache_manager.dart
  git commit -m "perf(cache): decode/encode HTTP cache asynchronously in background Isolate"
  ```

---

### 任务 3：传输层网络连接池扩容与 Keep-Alive 保活策略

**文件：**
- 修改：`lib/src/network/eh_request.dart`

- [ ] **步骤 1：重构 `doInitBean` 中的 Dio 网络连接池设置**
  针对 Native 平台（使用 `IOClientAdapter`），调优 `maxConnectionsPerHost` 控制高频大图并发排队瓶颈，并优化 Keep-Alive 超时时长保护。
  
  在 `lib/src/network/eh_request.dart` 头部引入：
  ```dart
  import 'package:dio/io.dart';
  ```
  
  修改 `doInitBean` 方法（行 55 附近），配置 `_dio.httpClientAdapter`：
  ```dart
  @override
  Future<void> doInitBean() async {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: networkSetting.connectTimeout.value),
      receiveTimeout: Duration(milliseconds: networkSetting.receiveTimeout.value),
    ));

    // 传输层优化：扩容 TCP 最大并发连接池，减少 TLS 重复握手导致的网络耗时
    if (_dio.httpClientAdapter is IOHttpClientAdapter) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        // 允许单个 host 保持更多活跃 Keep-Alive 连接通路（常规大并发大图加载需求）
        client.maxConnectionsPerHost = 64;
        client.idleTimeout = const Duration(seconds: 15);
        client.badCertificateCallback = (_, String host, __) {
          return networkSetting.allIPs.contains(host);
        };
        return client;
      };
    }

    systemProxyAddress = await getSystemProxyAddress();
    await _initProxy();
    // ... 原有其他初始化逻辑保持完全一致 ...
  ```

- [ ] **步骤 2：对 iOS/Android/Desktop 整体适配逻辑进行验证**
  检查在所有平台上的 `IOHttpClientAdapter` 是否能够安全通过类型校验与降级保护。

- [ ] **步骤 3：进行完整的编译分析**
  执行 `flutter analyze`。

- [ ] **步骤 4：创建 Git 本地提交记录**
  ```bash
  git add lib/src/network/eh_request.dart
  git commit -m "perf(network): scale connection pool and optimize TCP Keep-Alive policies"
  ```

---

## 规格覆盖自检清单 (Specs Coverage Check)
1. ✅ **Isolate 异步响应解析**：已覆盖 `EHRequest._parseResponse`，完成 DOM 解析卸载。
2. ✅ **网络缓存读写非阻塞化**：已覆盖 `EHCacheManager` 中的 headers 序列化与反序列化，通过 Isolate 彻底无阻塞化。
3. ✅ **Dio 传输层 Keep-Alive 并发优化**：对 `httpClientAdapter` 进行了最大连接数扩容与 idle 保活时限调优。
4. ✅ **安全与无损**：完全不增加新功能或 UI 内容，只在底盘静默升级。
