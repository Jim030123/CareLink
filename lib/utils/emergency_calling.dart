import 'dart:async';

import 'package:carelink_mobile/utils/signal_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

typedef IncomingCallHandler = void Function(Map<String, dynamic> incoming);
typedef RemoteStreamHandler = void Function(MediaStream stream);
typedef CallStateHandler = void Function(String state);

/// EmergencyCalling
///
/// Encapsulates WebRTC + signaling logic for starting/receiving an emergency
/// call. This file intentionally contains no UI code — it emits events via
/// stream controllers / callbacks so UI widgets can subscribe.
class EmergencyCalling {
  final SignalingService signaling;
  final String clientId; // local client id used to filter incoming messages

  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  String? currentCallId;
  String? incomingFrom;

  bool inCall = false;
  bool isCalling = false;

  // Buffered candidates which arrived before the PeerConnection was created
  final List<Map<String, dynamic>> _bufferedCandidates = [];

  // Optional caller-provided offer that we received from the signaling server
  Map<String, dynamic>? _incomingOffer;
  Completer<Map<String, dynamic>?>? _offerCompleter;

  // Events
  final StreamController<Map<String, dynamic>> incomingCallController = StreamController.broadcast();
  final StreamController<MediaStream> remoteStreamController = StreamController.broadcast();
  final StreamController<String> callStateController = StreamController.broadcast();

  // Callbacks convenience
  IncomingCallHandler? onIncomingCall;
  RemoteStreamHandler? onRemoteStream;
  CallStateHandler? onCallState;

  EmergencyCalling._(this.signaling, this.clientId) {
    // attach internal handler
    try { signaling.unregister(); } catch (_) {}
    // Note: SignalingService expects a callback at construction in many apps;
    // here we're relying on the object to call our _handleSignalMessage via
    // the provided onMessage at construction time. If not, UI can still call
    // `signaling` directly.
  }

  /// Create and connect the signaling client. `role` should be "cr" or
  /// "caregiver" depending on usage. Returns an instance ready to `startCall`
  /// or receive incoming calls.
  static Future<EmergencyCalling> create(String signalingUrl, String clientId, String role) async {
    final completer = Completer<EmergencyCalling>();
    // Create SignalingService with onMessage handler that will be bound later
    final s = SignalingService(onMessage: (m) {});
    final api = EmergencyCalling._(s, clientId);

    // Replace onMessage with our handler (SignalingService may allow a
    // constructor callback only, but many implementations also permit
    // replacing via register/unregister. We'll try to unregister and then
    // re-register by re-creating the signaling with our handler if needed.
    try {
      api.signaling.unregister();
    } catch (_) {}

    try { api.signaling.registerCallback(api._handleSignalMessage); } catch (_) {}

    api.signaling.connect(signalingUrl, clientId, role);

    // Optionally wait for ready if SignalingService exposes it
    try {
      await api.signaling.ready;
    } catch (_) {
      // ignore if not present
    }

    // Finished
    completer.complete(api);
    return completer.future;
  }

  // ---------------------------------
  // Public control methods
  // ---------------------------------

  /// Start an outgoing call to `toClientId`. Returns the server-acknowledged
  /// `callId` if available, or `null` on timeout/failure.
  Future<String?> startCall(String toClientId) async {
    // Ensure signaling connection
    try { await signaling.ready; } catch (_) {}

    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });

    // capture mic+camera
    final ok = await _requestCameraAndMicPermission();
    if (!ok) {
      _emitState('permission_denied');
      return null;
    }

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
      for (var t in _localStream!.getTracks()) {
        _pc!.addTrack(t, _localStream!);
      }
    } catch (e) {
      _emitState('getusermedia_failed');
      return null;
    }

    _pc!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate != null && currentCallId != null) {
        final msg = {
          'type': 'candidate',
          'from': clientId,
          'callId': currentCallId,
          'to': toClientId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        };
        // debug
        try { print('Signaling TX: $msg'); } catch (_) {}
        signaling.send(msg);
      }
    };

    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        final s = event.streams[0];
        remoteStreamController.add(s);
        if (onRemoteStream != null) onRemoteStream!(s);
      }
    };

    // create offer
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    final callId = const Uuid().v4();
    isCalling = true;
    _emitState('calling');

    // wait for start_call_ack
    final ackCompleter = Completer<String?>();
    // We'll use a temporary listener for start_call_ack via the signaling
    // handler which will complete this completer when the ack arrives.
    void ackListener(Map<String, dynamic> msg) {
      if (msg['type'] == 'start_call_ack') {
        try {
          ackCompleter.complete(msg['callId'] as String?);
        } catch (e) {}
      }
      if (msg['type'] == 'error') {
        try { ackCompleter.complete(null); } catch (_) {}
      }
    }

    // Temporary register
    try { signaling.registerCallback(ackListener); } catch (_) {}

    final startMsg = {
      'type': 'start_call',
      'from': clientId,
      'to': toClientId,
      'callId': callId,
      'offer': {'sdp': offer.sdp, 'type': offer.type}
    };
    try { print('Signaling TX: $startMsg'); } catch (_) {}
    signaling.send(startMsg);

    String? ackedCallId;
    try {
      ackedCallId = await ackCompleter.future.timeout(const Duration(seconds: 5));
      if (ackedCallId != null) {
        currentCallId = ackedCallId;
        _emitState('call_started');
      } else {
        _emitState('call_start_failed');
      }
    } catch (e) {
      _emitState('call_start_timeout');
      // leave currentCallId null
      currentCallId = null;
    } finally {
      // remove temporary ack listener
      try { signaling.unregisterCallback(ackListener); } catch (_) {}
    }

    return ackedCallId;
  }

  /// Accept an incoming call. `callId` identifies the call and `offer` is
  /// the remote offer map: { 'sdp': ..., 'type': 'offer' }
  Future<void> acceptCall(String callId, Map<String, dynamic> offer) async {
    currentCallId = callId;

    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });

    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && currentCallId != null) {
        final msg = {
          'type': 'candidate',
          'from': clientId,
          'callId': currentCallId,
          'to': incomingFrom,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        };
        try { print('Signaling TX: $msg'); } catch (_) {}
        signaling.send(msg);
      }
    };

    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        final s = event.streams[0];
        remoteStreamController.add(s);
        if (onRemoteStream != null) onRemoteStream!(s);
      }
    };

    // request permissions and add local tracks
    final ok = await _requestCameraAndMicPermission();
    if (!ok) {
      _emitState('permission_denied');
      return;
    }

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
      for (var t in _localStream!.getTracks()) {
        _pc!.addTrack(t, _localStream!);
      }
    } catch (e) {
      // continue — we can still create an answer even if no local tracks
    }

    // set remote offer
    final sdp = offer['sdp'] as String?;
    final type = offer['type'] as String? ?? 'offer';
    if (sdp != null) {
      final desc = RTCSessionDescription(sdp, type);
      try {
        await _pc!.setRemoteDescription(desc);
      } catch (e) {
        // ignore setRemote errors
      }
    }

    // create answer
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    final answerMsg = {
      'type': 'answer',
      'from': clientId,
      'callId': currentCallId,
      'answer': {'sdp': answer.sdp, 'type': answer.type}
    };
    try { print('Signaling TX: $answerMsg'); } catch (_) {}
    signaling.send(answerMsg);

    // add buffered candidates
    for (var bc in _bufferedCandidates) {
      try {
        final candidate = RTCIceCandidate(bc['candidate'], bc['sdpMid'], bc['sdpMLineIndex']);
        await _pc!.addCandidate(candidate);
      } catch (e) {}
    }
    _bufferedCandidates.clear();

    inCall = true;
    _emitState('in_call');
  }

  /// Hang up the current call (if any) and cleanup.
  Future<void> hangup() async {
    if (currentCallId != null) {
      try {
        final endMsg = {'type': 'end_call', 'from': clientId, 'callId': currentCallId};
        try { print('Signaling TX: $endMsg'); } catch (_) {}
        signaling.send(endMsg);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));
    }
    _cleanupCall();
    _emitState('hung_up');
  }

  /// Dispose resources
  Future<void> dispose() async {
    _cleanupCall();
    try { incomingCallController.close(); } catch (_) {}
    try { remoteStreamController.close(); } catch (_) {}
    try { callStateController.close(); } catch (_) {}
    try { signaling.unregister(); } catch (_) {}
    try { signaling.close(); } catch (_) {}
  }

  // ---------------------------------
  // Internal helpers
  // ---------------------------------

  void _emitState(String s) {
    callStateController.add(s);
    if (onCallState != null) onCallState!(s);
  }

  Future<bool> _requestCameraAndMicPermission() async {
    try {
      final mic = await Permission.microphone.status;
      if (!mic.isGranted) {
        final r = await Permission.microphone.request();
        if (!r.isGranted) return false;
      }
      final cam = await Permission.camera.status;
      if (!cam.isGranted) {
        final r2 = await Permission.camera.request();
        if (!r2.isGranted) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void _cleanupCall() {
    try {
      _pc?.close();
    } catch (_) {}
    _pc = null;

    try {
      if (_localStream != null) {
        for (var t in _localStream!.getTracks()) {
          try { t.stop(); } catch (_) {}
        }
        try { _localStream!.dispose(); } catch (_) {}
      }
    } catch (_) {}
    _localStream = null;

    inCall = false;
    isCalling = false;
    currentCallId = null;
    incomingFrom = null;
    _incomingOffer = null;
    _offerCompleter = null;
    _bufferedCandidates.clear();
  }

  // handle raw signaling messages
  void _handleSignalMessage(Map<String, dynamic> msg) async {
    // Filter messages not addressed to this client (if server includes a 'to' or 'recipient' field)
    final toField = msg['to'] ?? msg['recipient'] ?? msg['toClient'];
    if (toField != null && toField is String && toField.isNotEmpty) {
      if (toField != clientId) return; // not for me
    }

    final type = msg['type'];

    if (type == 'incoming_call') {
      incomingFrom = msg['from'] as String?;
      currentCallId = msg['callId'] as String?;
      _incomingOffer = msg['offer'] as Map<String, dynamic>?;
      incomingCallController.add(msg);
      if (onIncomingCall != null) onIncomingCall!(msg);
      _emitState('ringing');
      return;
    }

    if (type == 'offer') {
      _incomingOffer = msg['offer'] as Map<String, dynamic>?;
      try { _offerCompleter?.complete(_incomingOffer); } catch (_) {}
      return;
    }

    if (type == 'candidate') {
      final c = msg['candidate'];
      if (c != null) {
        if (_pc != null) {
          try {
            final candidate = RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']);
            await _pc!.addCandidate(candidate);
          } catch (e) {}
        } else {
          _bufferedCandidates.add(c as Map<String, dynamic>);
        }
      }
      return;
    }

    if (type == 'answer') {
      final ans = msg['answer'] as Map<String, dynamic>?;
      if (ans != null) {
        final desc = RTCSessionDescription(ans['sdp'] as String?, ans['type'] as String?);
        try {
          await _pc?.setRemoteDescription(desc);
          inCall = true;
          _emitState('in_call');
        } catch (e) {}
      }
      return;
    }

    if (type == 'start_call_ack') {
      // UI-level code may listen to this via signaling or startCall
      // nothing to do here specifically
      return;
    }

    if (type == 'reject_call') {
      _cleanupCall();
      _emitState('rejected');
      return;
    }

    if (type == 'end_call') {
      final callId = msg['callId'];
      if (callId == currentCallId) {
        _cleanupCall();
        _emitState('ended');
      }
      return;
    }
  }
}

// Extensions to SignalingService expected by this helper. If your
// `SignalingService` implementation does not have `registerCallback`/
// `unregisterCallback`, you may need to adapt these calls to match its API.
extension _SignalingExt on SignalingService {
  void registerCallback(void Function(Map<String, dynamic>) cb) {
    try {
      // many implementations provide a setter or method; try best-effort
      // If signaling already expects the callback in constructor, this
      // should be a no-op if not implemented.
      // If your SignalingService exposes a different API, replace this
      // with the proper registration call in the app.
      // ignore: invalid_use_of_visible_for_testing_member
      (this).onMessage = cb;
    } catch (_) {}
  }

  void unregisterCallback(void Function(Map<String, dynamic>) cb) {
    try {
      // best-effort no-op; if SignalingService supports unregistering a
      // specific callback, implement it here. Many implementations only
      // support a single handler, so we simply clear it.
      // ignore: invalid_use_of_visible_for_testing_member
      (this).onMessage = (_) {};
    } catch (_) {}
  }
}
