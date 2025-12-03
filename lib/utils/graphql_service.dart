// lib/graphql_client.dart
//
// 集中管理 GraphQL Client：
// - 支持 HTTP（Query / Mutation）
// - 支持 WebSocket（Subscription）
// - 支持同步/异步获取 idToken（Authorization: Bearer xxx）

import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// 默认的后端 GraphQL HTTP URL
/// 注意：这里用的是 http://IP:PORT/graphql
String _defaultBaseUrl() {
  // 你可以改成自己的 IP / 域名
  return 'http://10.209.91.100:25001/graphql';
}

/// 根据 HTTP 的 URL 推导出 WebSocket 的 URL：
/// - http  → ws
/// - https → wss
/// - path 保持一样（例如 /graphql）
///
/// 如果你传了 websocketUrl 参数，就直接用你传的，
/// 不会走这个自动推导。
String _deriveWsUri(String uriStr, String? websocketUrl) {
  if (websocketUrl != null && websocketUrl.isNotEmpty) return websocketUrl;

  try {
    final uri = Uri.parse(uriStr);

    // 把 http/https 换成 ws/wss
    final scheme = (uri.scheme == 'https')
        ? 'wss'
        : (uri.scheme == 'http')
            ? 'ws'
            : uri.scheme;

    // 不再自动把 /graphql 换成 /subscriptions
    // 如果服务器提供 legacy subscriptions endpoint（常见），
    // 把 HTTP 的 `/graphql` 路径转换为 WS 的 `/subscriptions`。
    // 这让大多数 subscriptions-transport-ws 客户端可以直接工作。
    final wsPath = (uri.path == '/graphql' || uri.path.endsWith('/graphql')) ? '/subscriptions' : uri.path;
    final wsUri = Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: wsPath,
      query: uri.query,
    ).toString();

    return wsUri;
  } catch (_) {
    // 解析失败就简单粗暴替换开头
    return uriStr.replaceFirst(RegExp(r'^http'), 'ws');
  }
}

/// 创建一个 GraphQLClient 实例
///
/// [idToken]：如果你已经有 token，可以直接传进来
/// [idTokenProvider]：如果 token 需要异步获取（例如从 storage）
/// [baseUrl]：HTTP GraphQL endpoint（默认用 _defaultBaseUrl）
/// [websocketUrl]：WebSocket endpoint（不传就自动从 baseUrl 推导）
/// [enableSubscriptions]：是否启用 WS（默认 true）
GraphQLClient createClient({
  String? idToken,
  Future<String?> Function()? idTokenProvider,
  String? baseUrl,
  String? websocketUrl,
  bool enableSubscriptions = true,
}) {
  final uriStr = baseUrl ?? _defaultBaseUrl();
  debugPrint('GraphQL: creating client with baseUrl=$uriStr');

  // 1. HTTP Link：负责 Query / Mutation
  final httpLink = HttpLink(uriStr);

  // 2. AuthLink：负责在 Header 带上 Authorization
  Link authConcatLink = httpLink;

  if ((idToken != null && idToken.isNotEmpty) || idTokenProvider != null) {
    final authLink = AuthLink(
      // getToken 会在每次请求的时候被调用
      getToken: () async {
        // 优先用传进来的 idToken
        if (idToken != null && idToken.isNotEmpty) {
          return 'Bearer $idToken';
        }

        // 其次用异步 provider
        if (idTokenProvider != null) {
          final t = await idTokenProvider();
          if (t != null && t.isNotEmpty) {
            return 'Bearer $t';
          }
        }

        return null;
      },
    );

    authConcatLink = authLink.concat(httpLink);
  }

  // 默认只用 HTTP
  Link link = authConcatLink;

  // 3. 如果启用 subscription，就创建 WebSocketLink
  if (enableSubscriptions) {
    try {
      final wsUri = _deriveWsUri(uriStr, websocketUrl);
      debugPrint('GraphQL: WebSocket URL = $wsUri');

      final socketClientConfig = SocketClientConfig(
        // initialPayload 会在 WS 建立连接时发送给服务器
        // 用来做 auth 之类的事情
        initialPayload: () async {
          debugPrint(
              'WebSocket: initialPayload called — attempting connect to $wsUri');

          String? token;

          // 先用同步传进来的 idToken
          if (idToken != null && idToken.isNotEmpty) {
            token = idToken;
          } else if (idTokenProvider != null) {
            // 再用异步 provider
            token = await idTokenProvider();
          }

          // 把 token 组织成常见的几种字段，方便不同服务器实现读取：
          // - Authorization / authorization: Bearer xxx
          // - token / authToken: xxx
          final Map<String, dynamic> payload = <String, dynamic>{};

          if (token != null && token.isNotEmpty) {
            final bearer =
                token.startsWith('Bearer') ? token : 'Bearer $token';
            final bare = token.startsWith('Bearer')
                ? token.substring(7).trim()
                : token;

            payload['Authorization'] = bearer;
            payload['authorization'] = bearer;
            payload['token'] = bare;
            payload['authToken'] = bare;

            debugPrint('WebSocket: initialPayload prepared (token masked)');
          } else {
            debugPrint('WebSocket: initialPayload returning empty (no token)');
          }

          return payload;
        },

        // 可以根据需要加上 autoReconnect / inactivityTimeout 等配置
        // autoReconnect: true,
        // inactivityTimeout: const Duration(minutes: 5),
      );

      // 创建 WebSocketLink（使用旧协议 subscriptions-transport-ws）
      final websocketLink = WebSocketLink(
        wsUri,
        config: socketClientConfig,
      );

      debugPrint(
          'GraphQL: WebSocketLink created for $wsUri (subscriptions enabled=$enableSubscriptions)');

      // 用 split：如果是 subscription 请求，用 WS；否则用 HTTP
      link = Link.split(
        (request) => request.isSubscription,
        websocketLink,
        authConcatLink,
      );
    } catch (e) {
      debugPrint('GraphQL: failed to create WebSocket link: $e');
      // 出错时降级成 HTTP-only
      link = authConcatLink;
    }
  }

  return GraphQLClient(
    link: link,
    cache: GraphQLCache(
      store: InMemoryStore(),
    ),
  );
}

/// 给 GraphQLProvider 用的便捷封装：
ValueNotifier<GraphQLClient> createClientNotifier({
  String? idToken,
  Future<String?> Function()? idTokenProvider,
  String? baseUrl,
  String? websocketUrl,
  bool enableSubscriptions = true,
}) {
  return ValueNotifier<GraphQLClient>(
    createClient(
      idToken: idToken,
      idTokenProvider: idTokenProvider,
      baseUrl: baseUrl,
      websocketUrl: websocketUrl,
      enableSubscriptions: enableSubscriptions,
    ),
  );
}
