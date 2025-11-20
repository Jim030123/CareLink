import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

/// Choose an appropriate host depending on environment.
/// - Web and iOS simulator: localhost works.
/// - Android emulator (default): use 10.0.2.2 to reach host machine.
/// - Genymotion emulator: use 10.0.3.2.
/// - Physical device: use the host machine LAN IP (e.g. 10.63.226.21)
String _defaultBaseUrl() {
  // Fallback to a LAN IP — change this to your dev machine IP when testing on a physical device
  return 'http://10.104.223.100:25001/';
}

GraphQLClient createClient({String? idToken, String? baseUrl}) {
  final uri = baseUrl ?? _defaultBaseUrl();
  debugPrint('GraphQL: creating client with baseUrl=$uri');

  final httpLink = HttpLink(uri);
  Link link = httpLink;

  if (idToken != null && idToken.isNotEmpty) {
    final authLink = AuthLink(getToken: () async => 'Bearer $idToken');
    link = authLink.concat(httpLink);
  }

  return GraphQLClient(
    link: link,
    cache: GraphQLCache(store: InMemoryStore()),
  );
}

/// Convenience for GraphQLProvider
ValueNotifier<GraphQLClient> createClientNotifier({String? idToken, String? baseUrl}) =>
    ValueNotifier<GraphQLClient>(createClient(idToken: idToken, baseUrl: baseUrl));
