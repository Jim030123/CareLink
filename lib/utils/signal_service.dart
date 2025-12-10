import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignalingService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StringBuffer _buffer = StringBuffer();
  final List<Map<String, dynamic>> _pendingSends = [];
  final Completer<void> _ready = Completer<void>();

  void Function(Map<String, dynamic>)? onMessage;

  SignalingService({this.onMessage});

  void connect(String url, String clientId, String role) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
    } catch (e, st) {
      print('SignalingService: connect error: $e\n$st');
      return;
    }

    _subscription = _channel!.stream.listen((event) {
      // Diagnostic: runtime type + length
      print('SignalingService: raw event type=${event.runtimeType}');

      String text;
      if (event is String) {
        text = event;
      } else if (event is List<int> || event is Uint8List) {
        try {
          text = utf8.decode(event as List<int>);
        } catch (e) {
          print('SignalingService: failed decoding bytes: $e');
          return;
        }
      } else {
        print('SignalingService: unexpected message type ${event.runtimeType}');
        return;
      }

      print('SignalingService: raw text (${text.length}) -> ${text.length > 200 ? text.substring(0,200) + "..." : text}');

      // Heuristics: NDJSON (one JSON per line) or partial JSON chunks
      // Try quick path: split by newline and parse lines
      if (text.contains('\n')) {
        final lines = text.split('\n');
        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;
          _tryParseAndDispatch(line);
        }
        return;
      }

      // Try parse directly; on FormatException, attempt to buffer (partial JSON)
      if (!_tryParseAndDispatch(text)) {
        // Buffer and attempt to find complete JSON objects
        _buffer.write(text);
        final buffered = _buffer.toString().trim();
        // Quick attempt: if it contains a closing brace, try to parse up to last '}'.
        final lastClose = buffered.lastIndexOf('}');
        if (lastClose != -1) {
          final candidate = buffered.substring(0, lastClose + 1);
          final remainder = buffered.substring(lastClose + 1);
          if (_tryParseAndDispatch(candidate)) {
            _buffer.clear();
            if (remainder.isNotEmpty) _buffer.write(remainder);
          }
        } else {
          // still incomplete; wait for more frames
          print('SignalingService: incoming JSON seems incomplete, buffering ${buffered.length} bytes');
        }
      }
    }, onError: (err) {
      print('SignalingService: WebSocket stream error: $err');
    }, onDone: () {
      print('SignalingService: WebSocket stream closed');
      _subscription = null;
      _channel = null;
    });

    // mark ready and flush any queued messages once subscription is active
    Future.microtask(() {
      if (!_ready.isCompleted) _ready.complete();
      _flushPending();
    });

    // Use send() so join will be queued if channel isn't available yet
    send({"type": "join", "clientId": clientId, "role": role});
  }

  // returns true when parse+dispatch succeeded
  bool _tryParseAndDispatch(String text) {
    try {
      final decoded = jsonDecode(text);
      // Log the message type (if present) to aid debugging
      try {
        final t = decoded is Map && decoded.containsKey('type') ? decoded['type'] : null;
        if (t != null) print('SignalingService: parsed JSON type=$t');
      } catch (_) {}

      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded.cast<String, dynamic>());
        final cb = onMessage;
        cb?.call(data);
        return true;
      } else {
        print('SignalingService: decoded JSON not an object (type=${decoded.runtimeType})');
        return false;
      }
    } on FormatException catch (e) {
      // common when message is truncated
      print('SignalingService: json decode FormatException: ${e.message}');
      return false;
    } catch (e, st) {
      print('SignalingService: json parse unexpected error: $e\n$st');
      return false;
    }
  }

  bool send(Map<String, dynamic> data) {
    // If channel isn't ready, queue and return true to indicate caller's intent
    if (_channel == null) {
      try {
        _pendingSends.add(Map<String, dynamic>.from(data));
      } catch (e) {
        _pendingSends.add(data);
      }
      print('SignalingService: not connected, queued message -> ${data['type'] ?? data}');
      return true;
    }

    try {
      final json = jsonEncode(data);
      print('SignalingService: send -> $json');
      _channel!.sink.add(json);
      return true;
    } catch (e, st) {
      print('SignalingService: send error: $e\n$st');
      return false;
    }
  }

  void _flushPending() {
    if (_channel == null) return;
    if (_pendingSends.isEmpty) return;
    while (_pendingSends.isNotEmpty) {
      final msg = _pendingSends.removeAt(0);
      try {
        final json = jsonEncode(msg);
        print('SignalingService: flushing queued -> $json');
        _channel!.sink.add(json);
      } catch (e, st) {
        print('SignalingService: error flushing queued message: $e\n$st');
        _pendingSends.insert(0, msg);
        break;
      }
    }
  }

  /// Await this future to ensure the client is connected (or at least attempted).
  Future<void> get ready async {
    try {
      await _ready.future.timeout(const Duration(seconds: 5));
    } catch (e) {
      // ignore timeout
    }
  }

  Future<void> close() async {
    try {
      await _subscription?.cancel();
    } catch (e) {
      print('SignalingService: cancel error: $e');
    }
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (e) {
      print('SignalingService: sink close error: $e');
    }
    _channel = null;
    onMessage = null;
  }

  void unregister() => onMessage = null;
}