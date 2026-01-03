import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';

class SignalingService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StringBuffer _buffer = StringBuffer();
  final List<Map<String, dynamic>> _pendingSends = [];
  Completer<void>? _joinedCompleter;

  void Function(Map<String, dynamic>)? onMessage;

  SignalingService({this.onMessage});

  void connect(String url, String clientId, String role) {
    // Prepare joined completer BEFORE subscribing to avoid race where server replies immediately.
    _joinedCompleter = Completer<void>();

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

      print('SignalingService: raw text (${text.length}) -> ${text.length > 200 ? "${text.substring(0,200)}..." : text}');

      // NDJSON: line separated
      if (text.contains('\n')) {
        final lines = text.split('\n');
        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;
          _tryParseAndDispatch(line);
        }
        return;
      }

      if (!_tryParseAndDispatch(text)) {
        // Buffer and try to extract a full JSON object using brace counting (safer than lastIndexOf)
        _buffer.write(text);
        final buffered = _buffer.toString();
        final extracted = _extractFirstJson(buffered);
        if (extracted != null) {
          final candidate = extracted.item1;
          final remainder = extracted.item2;
          if (_tryParseAndDispatch(candidate)) {
            _buffer.clear();
            if (remainder.isNotEmpty) _buffer.write(remainder);
          }
        } else {
          print('SignalingService: incoming JSON seems incomplete, buffering ${buffered.length} bytes');
        }
      }
    }, onError: (err) {
      print('SignalingService: WebSocket stream error: $err');
    }, onDone: () {
      print('SignalingService: WebSocket stream closed');
      _subscription = null;
      _channel = null;
      // If joined never completed, complete with error to avoid hanging callers
      if (_joinedCompleter != null && !_joinedCompleter!.isCompleted) {
        _joinedCompleter!.completeError(StateError('Connection closed before joined'));
      }
    });

    // Send join (will be queued if send() detects not-yet-joined)
    send({"type": "join", "clientId": clientId, "role": role});

    // Some signaling servers don't send a 'joined' acknowledgement back to the
    // client. To avoid leaving queued messages forever (which causes e.g.
    // `start_call` to never be delivered), complete the joined completer after
    // a short timeout if the server didn't explicitly ack. This makes the
    // client more tolerant of different server implementations while still
    // preferring an explicit 'joined' ACK when present.
    Future.delayed(const Duration(seconds: 1), () {
      try {
        if (_joinedCompleter != null && !_joinedCompleter!.isCompleted) {
          _joinedCompleter!.complete();
          _flushPending();
          print('SignalingService: joined timeout - auto-completing joined state');
        }
      } catch (e) {
        // ignore
      }
    });
  }

  // Helper: extract the first JSON object from a string using brace counting.
  // Returns Tuple (jsonString, remainder) or null if not enough data yet.
  // Simple implementation: expects JSON object starting at index 0.
  Tuple2<String, String>? _extractFirstJson(String s) {
    int i = 0;
    while (i < s.length && s[i].trim().isEmpty) {
      i++;
    }
    if (i >= s.length) return null;
    if (s[i] != '{') {
      // not an object starting at 0; give up (could be array or other)
      return null;
    }
    int depth = 0;
    for (int j = i; j < s.length; j++) {
      final ch = s[j];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') depth--;
      if (depth == 0) {
        final jsonStr = s.substring(i, j + 1);
        final remainder = s.substring(j + 1);
        return Tuple2(jsonStr, remainder);
      }
    }
    return null; // incomplete
  }

  // returns true when parse+dispatch succeeded
  bool _tryParseAndDispatch(String text) {
    try {
      final decoded = jsonDecode(text);
      // Log the message type (if present) to aid debugging
      try {
        final t = decoded is Map && decoded.containsKey('type') ? decoded['type'] : null;
        if (t != null) print('SignalingService: parsed JSON type=$t');
        // If server acknowledges our join, flush queued messages and mark ready.
        if (t == 'joined') {
          if (_joinedCompleter != null && !_joinedCompleter!.isCompleted) {
            _joinedCompleter!.complete();
          }
          _flushPending();
        }
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
    // If channel isn't available OR we haven't received 'joined' ack yet,
    // queue the message (except allow sending the join itself immediately).
    final isJoin = data['type'] == 'join';
    final notJoinedYet = (_joinedCompleter != null && !_joinedCompleter!.isCompleted);
    if (_channel == null || (notJoinedYet && !isJoin)) {
      try {
        _pendingSends.add(Map<String, dynamic>.from(data));
      } catch (e) {
        _pendingSends.add(data);
      }
      print('SignalingService: queued message -> ${data['type'] ?? data}');
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
        print('SignalingService: flushing queued -> ${msg['type'] ?? json}');
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
      await (_joinedCompleter?.future ?? Future.value()).timeout(const Duration(seconds: 5));
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

    // Fail join completer / pending sends
    if (_joinedCompleter != null && !_joinedCompleter!.isCompleted) {
      _joinedCompleter!.completeError(StateError('Connection closed'));
    }
    _joinedCompleter = null;

    if (_pendingSends.isNotEmpty) {
      print('SignalingService: clearing ${_pendingSends.length} queued messages due to close');
      _pendingSends.clear();
    }

    onMessage = null;
  }

  void unregister() => onMessage = null;
}

// Tiny Tuple2 replacement to avoid adding a package
class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;
  Tuple2(this.item1, this.item2);
}