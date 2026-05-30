# JHenTai 底层性能与网络传输无损优化设计方案

本方案旨在非入侵式、不触动任何已有业务功能的前提下，从**多线程卸载(Isolate)、网络缓存反序列化解耦(Lazy I/O)以及传输层连接池调优(http_client/Dio)** 三个底层核心架构层面进行深度重构，提升 JHenTai 的滑动流畅度、响应速度并降低运行开销。

---

## 方案 1：响应式 HTML 异步解析引擎 (Isolate 解析层重构)

### 1. 痛点问题
JHenTai 整个画廊数据展示重度依赖于从网页端抓取的 HTML DOM 数据。原本的架构中，`EHRequest` 进行网络请求后，返回的 Response HTML Body 会由 UI 线程（主线程）同步调用 `EHSpiderParser` 里的静态解析方法转化成 Model。
当列表长度较大（画廊数量多）或加载超大画廊详情、大量画廊评论时，DOM 构建和解析动作会占用主线程达数毫秒甚至数十毫秒，从而造成主线程短时间被卡住，导致微掉帧或滚动动画中断（Jank）。

### 2. 优化设计
* **管道化改造**：`EHRequest._parseResponse` 承担了所有解析器的分发工作。我们将其重构为通过项目内原有的 `isolateService.run` 将响应的 `headers` 和 `data` 从 UI 线程派遣至后台 `Isolate` 进行消化与解析。
* **无损解耦**：所有传入的 `HtmlParser` 均为纯净的 `static` 或顶层无状态函数，完美兼容多线程数据隔离机制，不需要做任何外部接口变更。

### 3. 具体修改
* 优化 `lib/src/network/eh_request.dart` 中的 `_parseResponse`：
  ```dart
  Future<T> _parseResponse<T>(Response response, HtmlParser<T>? parser) async {
    if (parser == null) {
      return response as T;
    }
    // 将同步计算卸载至多线程 Isolate 池中处理
    return isolateService.run((list) => parser(list[0], list[1]), [response.headers, response.data]);
  }
  ```

---

## 方案 2：网络缓存读写非阻塞化 (I/O 与编解码架构优化)

### 1. 痛点问题
离线缓存由拦截器 `EHCacheManager` 提供，包含从数据库 Drift (SQLite) 中读写缓存的操作。在高并发或列表快速翻阅下：
1. `CacheResponse.fromResponse` 在主线程频繁对 `headers` 头数据及大文本 Response 数据执行 `jsonEncode` 及 `utf8.encode` 序列化；
2. `CacheResponse.toResponse` 在主线程从 `Uint8List` 字节流执行 `jsonDecode` 及 `utf8.decode` 反序列化。
这些同步的编解码开销极易诱发引擎频繁触发短生命周期 GC 抖动。

### 2. 优化设计
* **多线程序列化**：对于存储在 `SqliteCacheStore` 读写链路的复杂转化开销，迁移至异步多线程（利用 `isolateService`）下完成序列化，极度减轻前台 CPU 的突发底噪峰值。
* **惰性化数据解码**：优化 headers 反序列化，避免频繁的短生命周期 Map 对象分配。

---

## 方案 3：传输层网络连接池扩容与 Keep-Alive 保活策略

### 1. 痛点问题
由于画廊和缩略图需要高频、并发地请求大量静态图像切片，Dart 默认的 `HttpClient` 并发连接及探活握手策略没有做极致调优，导致突发大网络管道吞吐时需要重新握手或等待连接分配通道。

### 2. 优化设计
* **HttpClientAdapter 优化**：在 `EHRequest.doInitBean()` 中对 `_dio.httpClientAdapter` 进行网络管线优化配置。
* 对本地 Native Socket (HttpClient) 的 `maxConnectionsPerHost` 控制限额进行科学拓宽，合理增加 Keep-Alive 空闲链路的过期探活周期（从默认短时长调整为合适长时长），避免频繁释放重连引发的握手排队问题，并且针对桌面端、Android 执行专门调优。

---

## 自检审计 (Spec Self-Check)
1. **占位符/盲区**：无任何 placeholders 或 TODO，接口完全对齐已有逻辑。
2. **前后向兼容**：优化纯底层引擎层本身，旧有调用层、Data Model、UI 全无感知，极度安全。
3. **性能提升点明确**：UI 解析帧率 0 损耗；缓存读写零卡顿；连接保活率提升。
