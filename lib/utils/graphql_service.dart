import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

String _defaultBaseUrl() {
  return 'http://10.209.91.100:25001/graphql';
}

/// 根据 HTTP URL 推导 WS URL：
/// - http  -> ws
/// - https -> wss
/// - path 保持不变（例如 /graphql）
/// 如果传了 websocketUrl，就直接用传进来的。
String _deriveWsUri(String uriStr, String? websocketUrl) {
  if (websocketUrl != null && websocketUrl.isNotEmpty) return websocketUrl;

  try {
    final uri = Uri.parse(uriStr);

    final scheme = (uri.scheme == 'https')
        ? 'wss'
        : (uri.scheme == 'http')
            ? 'ws'
            : uri.scheme;

    final wsUri = Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path, // ✅ 这里保持 /graphql
      query: uri.query,
    ).toString();

    return wsUri;
  } catch (_) {
    return uriStr.replaceFirst(RegExp(r'^http'), 'ws');
  }
}

GraphQLClient createClient({
  String? idToken,
  Future<String?> Function()? idTokenProvider,
  String? baseUrl,
  String? websocketUrl,
  bool enableSubscriptions = true,
}) {
  final uriStr = baseUrl ?? _defaultBaseUrl();
  debugPrint('GraphQL: creating client with baseUrl=$uriStr');

  final httpLink = HttpLink(uriStr);

  Link authConcatLink = httpLink;

  if ((idToken != null && idToken.isNotEmpty) || idTokenProvider != null) {
    final authLink = AuthLink(
      getToken: () async {
        if (idToken != null && idToken.isNotEmpty) {
          return 'Bearer $idToken';
        }

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

  Link link = authConcatLink;

  if (enableSubscriptions) {
    try {
      final wsUri = _deriveWsUri(uriStr, websocketUrl);
      debugPrint('GraphQL: WebSocket URL = $wsUri');

      final socketClientConfig = SocketClientConfig(
        initialPayload: () async {
          debugPrint(
              'WebSocket: initialPayload called — attempting connect to $wsUri');

          String? token;

          if (idToken != null && idToken.isNotEmpty) {
            token = idToken;
          } else if (idTokenProvider != null) {
            token = await idTokenProvider();
          }

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
        // 可以按需打开：
        // autoReconnect: true,
        // inactivityTimeout: const Duration(minutes: 5),
      );

      final websocketLink = WebSocketLink(
        wsUri,
        config: socketClientConfig,
      );

      debugPrint(
          'GraphQL: WebSocketLink created for $wsUri (subscriptions enabled=$enableSubscriptions)');

      link = Link.split(
        (request) => request.isSubscription,
        websocketLink,
        authConcatLink,
      );
    } catch (e) {
      debugPrint('GraphQL: failed to create WebSocket link: $e');
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
