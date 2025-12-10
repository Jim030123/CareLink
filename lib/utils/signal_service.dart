// signal_service.dart
// Simple, robust WebSocket-based signaling client for use with EmergencyCalling.
//
// Features:
// - connect(url, clientId, role)
// - send(map) -> bool (true if sent or queued)
// - ready Future that completes when socket open and registration sent
// - onMessage setter for single-handler compatibility
// - addListener/removeListener for additive listeners (recommended)
// - registerCallback/unregisterCallback for compatibility with older code (overwrites)
// - automatic message queueing while connecting
//
// Note: This implementation uses dart:io WebSocket which works on mobile. For web you need to
// adapt to `html.WebSocket` (or use `web_socket_channel`) if building for web.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SignalingService {
  // Public fields / API hooks
  void Function(Map<String, dynamic>)? onMessage;

  // Internal
  WebSocket? _ws;
  final List<Map<String, dynamic>> _queue = [];
  final List<void Function(Map<String, dynamic>)> _listeners = [];
  // single callback (overwrite-style) for registerCallback/unregisterCallback
  void Function(Map<String, dynamic>)? _registeredCallback;

  // Ready completer
  Completer<void>? _readyCompleter;

  // connection metadata
  String? _url;
  String? _clientId;
  String? _role;
  bool _useQueryParams = false;

  bool get isConnected => _ws != null && _ws!.readyState == WebSocket.open;

  SignalingService({void Function(Map<String, dynamic>)? onMessage}) {
    this.onMessage = onMessage;
  }

  /// Connect to the signaling server. This is non-blocking; await [ready] to wait for open.
  /// Connect to the signaling server.
  ///
  /// If [useQueryParams] is true the clientId and role will be appended to
  /// the websocket URL as query parameters and no explicit 'register'
  /// message will be sent. This accommodates signaling servers that expect
  /// identification during the websocket handshake instead of a separate
  /// registration message.
  void connect(String url, String clientId, String role, {bool useQueryParams = false}) {
    _url = url;
    _clientId = clientId;
    _role = role;
    _useQueryParams = useQueryParams;
    _readyCompleter ??= Completer<void>();
    _openWebSocket();
  }

  /// Future that completes when connected and registration (if any) has been sent.
  Future<void> get ready async {
    if (_readyCompleter == null) _readyCompleter = Completer<void>();
    return _readyCompleter!.future;
  }

  Future<void> _openWebSocket() async {
    if (_ws != null) return;
    if (_url == null) return;

    try {
      // On mobile, WebSocket.connect uses dart:io
      // If requested, append clientId & role as query params to the connect URL
      var connectUrl = _url!;
      if (_useQueryParams && _clientId != null) {
        final sep = connectUrl.contains('?') ? '&' : '?';
        connectUrl = '$connectUrl${sep}clientId=${Uri.encodeComponent(_clientId!)}&role=${Uri.encodeComponent(_role ?? '')}';
      }
      _ws = await WebSocket.connect(connectUrl);
      _ws!.pingInterval = const Duration(seconds: 30);
      _ws!.listen(_onRawMessage, onDone: _onDone, onError: _onError, cancelOnError: true);
      // send a registration/hello message if server expects it (skip when using query params)
      if (!_useQueryParams) {
        _sendRegisterMessage();
      }

      // flush queue
      _flushQueue();

      // mark ready
      try {
        if (!(_readyCompleter?.isCompleted ?? true)) _readyCompleter?.complete();
      } catch (_) {}
      print('SignalingService: connected to $_url as $_clientId');
    } catch (e) {
      print('SignalingService: connect error: $e');
      // not fatal — leave ready completer pending; callers can timeout waiting for ready
      try {
        // schedule reconnect attempt after delay
        Future.delayed(const Duration(seconds: 2), () {
          _reconnect();
        });
      } catch (_) {}
    }
  }

  void _reconnect() {
    if (_ws != null) {
      try { _ws!.close(); } catch (_) {}
      _ws = null;
    }
    // reset ready completer so callers can await next ready
    _readyCompleter = Completer<void>();
    // try open again
    Future.microtask(() => _openWebSocket());
  }

  void _sendRegisterMessage() {
    if (_clientId == null) return;
    final reg = {
      'type': 'register',
      'clientId': _clientId,
      'role': _role,
    };
    send(reg);
  }

  /// Send a map as JSON. Returns true if message was sent or queued.
  /// If not connected, the message will be queued and sent on connect.
  bool send(Map<String, dynamic> msg) {
    try {
      final jsonStr = json.encode(msg);
      if (isConnected) {
        _ws!.add(jsonStr);
        // also echo to local listeners for debug parity
        _dispatchLocal(msg);
        return true;
      } else {
        // queue the message
        _queue.add(msg);
        print('SignalingService: queued message -> ${msg['type']}');
        return true;
      }
    } catch (e) {
      print('SignalingService.send error: $e');
      return false;
    }
  }

  // flush queued messages (called on connect)
  void _flushQueue() {
    if (!isConnected) return;
    if (_queue.isEmpty) return;
    for (final m in List<Map<String, dynamic>>.from(_queue)) {
      try {
        _ws!.add(json.encode(m));
      } catch (e) {
        print('SignalingService: failed to flush queued message: $e');
      }
    }
    _queue.clear();
  }

  // raw incoming websocket message
  void _onRawMessage(dynamic raw) {
    try {
      if (raw is String) {
        final Map<String, dynamic> msg = json.decode(raw) as Map<String, dynamic>;
        _handleIncoming(msg);
      } else if (raw is List<int>) {
        final s = String.fromCharCodes(raw);
        final Map<String, dynamic> msg = json.decode(s) as Map<String, dynamic>;
        _handleIncoming(msg);
      } else {
        // ignore
      }
    } catch (e) {
      print('SignalingService: failed to parse incoming message: $e raw=$raw');
    }
  }

  void _handleIncoming(Map<String, dynamic> msg) {
    // dispatch in this order:
    // 1) onMessage field (if set) - overwrite style
    // 2) registeredCallback (if set) - overwrite style
    // 3) listeners (addListener) - additive
    try {
      try { print('SignalingService: rx -> $msg'); } catch (_) {}
    } catch (_) {}

    var handled = false;
    try {
      if (onMessage != null) {
        try { onMessage!(msg); handled = true; } catch (e) { print('onMessage handler error: $e'); }
      }
    } catch (_) {}

    try {
      if (!handled && _registeredCallback != null) {
        try { _registeredCallback!(msg); handled = true; } catch (e) { print('registeredCallback error: $e'); }
      }
    } catch (_) {}

    // always notify additive listeners
    try {
      for (final l in List<void Function(Map<String, dynamic>)>.from(_listeners)) {
        try { l(msg); } catch (e) { print('listener error: $e'); }
      }
    } catch (_) {}
  }

  void _dispatchLocal(Map<String, dynamic> msg) {
    // used to mirror sends into local listeners (helps with logs)
    try {
      for (final l in List<void Function(Map<String, dynamic>)>.from(_listeners)) {
        try { l(msg); } catch (_) {}
      }
      if (_registeredCallback != null) {
        try { _registeredCallback!(msg); } catch (_) {}
      }
      if (onMessage != null) {
        try { onMessage!(msg); } catch (_) {}
      }
    } catch (_) {}
  }

  void _onDone() {
    print('SignalingService: websocket closed');
    _ws = null;
    // mark not ready by resetting completer so subsequent connect can await
    _readyCompleter = Completer<void>();
    // try reconnect
    Future.delayed(const Duration(seconds: 2), () => _reconnect());
  }

  void _onError(Object err) {
    try { print('SignalingService: websocket error: $err'); } catch (_) {}
    // trigger reconnect
    _reconnect();
  }

  /// Additive listener (will not overwrite other handlers)
  void addListener(void Function(Map<String, dynamic>) cb) {
    if (cb == null) return;
    _listeners.add(cb);
  }

  /// Remove a previously added listener
  void removeListener(void Function(Map<String, dynamic>) cb) {
    if (cb == null) return;
    _listeners.remove(cb);
  }

  /// Register a single callback (overwrite-style). This is compatible with older code.
  void registerCallback(void Function(Map<String, dynamic>) cb) {
    _registeredCallback = cb;
  }

  /// Unregister the single callback
  void unregisterCallback(void Function(Map<String, dynamic>) cb) {
    // if the same callback was passed, clear it; otherwise clear anyway
    if (_registeredCallback == cb) {
      _registeredCallback = null;
    } else {
      _registeredCallback = null;
    }
  }

  /// Close the signaling connection and cleanup
  Future<void> close() async {
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
    _queue.clear();
    _listeners.clear();
    _registeredCallback = null;
    onMessage = null;
    _readyCompleter = null;
    print('SignalingService: closed');
  }
}
