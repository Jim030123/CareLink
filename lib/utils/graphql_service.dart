import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// idTokenProvider: optional async function returning a Bearer token string
/// or null. If provided, it's used both for AuthLink (HTTP requests)
/// and as the connection payload for the WebSocket link (subscriptions).

/// Choose an appropriate host depending on environment.
/// - Web and iOS simulator: localhost works.
/// - Android emulator (default): use 10.0.2.2 to reach host machine.
/// - Genymotion emulator: use 10.0.3.2.
/// - Physical device: use the host machine LAN IP (e.g. 10.63.226.21)
String _defaultBaseUrl() {
  // Fallback to a LAN IP — change this to your dev machine IP when testing on a physical device
    // Default to the GraphQL endpoint path
    return 'http://10.209.91.100:25001/graphql';
}

GraphQLClient createClient({
  String? idToken,
  /// Optional async provider function to fetch the latest idToken when needed
  Future<String?> Function()? idTokenProvider,
  String? baseUrl,
  /// enable subscriptions (will try to create a WebSocket link). Defaults to true.
  bool enableSubscriptions = true,
}) {
  final uriStr = baseUrl ?? _defaultBaseUrl();
  debugPrint('GraphQL: creating client with baseUrl=$uriStr');

  final httpLink = HttpLink(uriStr);

  // Determine auth link: prefer explicit idToken, else use provider if available
  Link authConcatLink = httpLink;
  if ((idToken != null && idToken.isNotEmpty) || idTokenProvider != null) {
    final authLink = AuthLink(getToken: () async {
      if (idToken != null && idToken.isNotEmpty) return 'Bearer $idToken';
      if (idTokenProvider != null) {
        final t = await idTokenProvider();
        if (t != null && t.isNotEmpty) return 'Bearer $t';
      }
      return null;
    });
    authConcatLink = authLink.concat(httpLink);
  }

  Link link = authConcatLink;

  // Setup WebSocketLink for subscriptions if enabled and platform supports it
  if (enableSubscriptions) {
    try {
      // convert http(s) -> ws(s)
      String wsUri = uriStr.replaceFirst(RegExp(r'^http'), 'ws');

      final socketClientConfig = SocketClientConfig(
        initialPayload: () async {
          // supply authorization header for websocket connection
          if (idToken != null && idToken.isNotEmpty) return {'Authorization': 'Bearer $idToken'};
          if (idTokenProvider != null) {
            final t = await idTokenProvider();
            if (t != null && t.isNotEmpty) return {'Authorization': 'Bearer $t'};
          }
          return <String, String>{};
        },
        // Optional: increase inactivityTimeout or other tuning here
      );

      final websocketLink = WebSocketLink(wsUri, config: socketClientConfig);

      // Split link: use websocket for subscriptions, http for queries/mutations
      link = Link.split((request) => request.isSubscription, websocketLink, authConcatLink);
    } catch (e) {
      debugPrint('GraphQL: failed to create WebSocket link: $e');
      // fall back to HTTP-only link
      link = authConcatLink;
    }
  }

  return GraphQLClient(
    link: link,
    cache: GraphQLCache(store: InMemoryStore()),
  );
}

/// Convenience for GraphQLProvider
ValueNotifier<GraphQLClient> createClientNotifier({
  String? idToken,
  Future<String?> Function()? idTokenProvider,
  String? baseUrl,
  bool enableSubscriptions = true,
}) =>
    ValueNotifier<GraphQLClient>(createClient(
        idToken: idToken, idTokenProvider: idTokenProvider, baseUrl: baseUrl, enableSubscriptions: enableSubscriptions));
