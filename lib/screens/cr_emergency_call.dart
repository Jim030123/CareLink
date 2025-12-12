import 'dart:async';
import 'dart:convert';

import 'package:carelink_mobile/screens/cg_emergency_call.dart';
import 'package:carelink_mobile/utils/signal_service.dart';
import 'package:carelink_mobile/utils/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

class CREmergencyCall extends StatefulWidget {
  final String caregiverId;
  final String signalingUrl;
  final bool autoStart;

  const CREmergencyCall({
    super.key,
    required this.caregiverId,
    required this.signalingUrl,
    this.autoStart = false,
  });

  @override
  State<CREmergencyCall> createState() => _CREmergencyCallState();
}

class _CREmergencyCallState extends State<CREmergencyCall> {
  late SignalingService signaling;
  RTCPeerConnection? pc;
  MediaStream? localStream;
  final _remoteRenderer = RTCVideoRenderer();
  final _localRenderer = RTCVideoRenderer();
  // Prefer using authenticated Firebase UID as clientId when available; fallback to generated ID
  String myClientId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String myDisplayName = '';
  String remoteDisplayName = '';
  bool _hasCurrentUser = false;

  String? currentCallId;
  // Completer to wait for server ack when starting a call
  Completer<String?>? _startCallAckCompleter;
  bool isCalling = false;
  bool inCall = false;
  bool isMuted = false;
  bool _autoStartAttempted = false;

  @override
  void initState() {
    super.initState();

    // ✅ 正确做法：在 constructor 传入回调
    signaling = SignalingService(onMessage: handleSignalMessage);

    // ✅ connect 也要传 role（"cr"）
    if (myClientId.isEmpty) {
      myClientId = 'CR-${const Uuid().v4()}';
    }
    print('TestPage: using clientId=$myClientId to join signaling');
    signaling.connect(widget.signalingUrl, myClientId, "cr");
    // 初始化 renderers for video
    _initRenderers();
    // load local user profile (displayName)
    _loadLocalUser();

    // Always attempt to auto-start the call when this page is opened.
    // Wait for the signaling client to be ready before starting so we don't
    // attempt to send offers before join/flush completes.
    Future.microtask(() async {
      try {
        await signaling.ready;
      } catch (e) {
        print('CR: signaling.ready awaited with error/timeout: $e');
      }
      if (!mounted) return;
      if (_autoStartAttempted) return;
      _autoStartAttempted = true;
      try {
        print('CR: auto-starting call on page entry');
        await _startCall();
      } catch (e) {
        print('CR: auto-start call failed: $e');
      }
    });

  }

  Future<void> _loadLocalUser() async {
    try {
      final u = await fetchCurrentUser();
      if (!mounted) return;

      if (u != null) {
        final display = (u['displayName'] as String?)?.trim();
        setState(() {
          myDisplayName = (display != null && display.isNotEmpty)
              ? display
              : (u['uid'] as String? ?? myClientId);
          _hasCurrentUser = true;
        });
      } else {
        // fallback to FirebaseAuth displayName or uid
        final fa = FirebaseAuth.instance.currentUser;
        setState(() {
          myDisplayName = (fa?.displayName != null && fa!.displayName!.isNotEmpty)
              ? fa.displayName!
              : (fa?.uid ?? myClientId);
          _hasCurrentUser = false;
        });
      }

      // try to fetch remote caregiver displayName (if caregiverId is a uid)
      try {
        final remote = await fetchUserByUid(widget.caregiverId);
        if (!mounted) return;
        if (remote != null) {
          setState(() {
            remoteDisplayName = (remote['displayName'] as String?)?.trim() ??
                (remote['uid'] as String? ?? widget.caregiverId);
          });
        }
      } catch (e) {
        // ignore remote lookup errors
      }
    } catch (e) {
      print('CR: loadLocalUser error: $e');
    }
  }

  Future<void> _initRenderers() async {
    try {
      await _remoteRenderer.initialize();
      await _localRenderer.initialize();
    } catch (e) {
      print('CR: renderer init error: $e');
    }
  }

  // ───────────────────────────────────────────
  // Step 1: CR 按按钮 → 创建 Offer & 发起呼叫
  // ───────────────────────────────────────────
  Future<void> _startCall() async {
    print('CR: startCall invoked');
    // Ensure signaling attempted connection / join before sending
    await signaling.ready;
    // 创建 PeerConnection
    pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    });

    // Attach remote track handler early so remote video is shown as soon as available
    pc!.onTrack = (RTCTrackEvent event) {
      try {
        if (event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
        }
      } catch (e) {
        print('CR: onTrack error: $e');
      }
    };
    // Compatibility with older API
    pc!.onAddStream = (MediaStream stream) {
      try {
        _remoteRenderer.srcObject = stream;
      } catch (e) {
        print('CR: onAddStream error: $e');
      }
    };

    // 捕获麦克风
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        // enable video for video call
        'video': {
          'facingMode': 'user',
        },
      });
      print('CR: acquired localStream id=${localStream?.id}');
      // Debug: log local audio tracks
      try {
        final audioTracks = localStream!.getAudioTracks();
        print('CR: got localStream id=${localStream!.id}, audioTracks=${audioTracks.length}');
        for (var t in audioTracks) {
          print('CR: local audio track id=${t.id}, kind=${t.kind}, enabled=${t.enabled}');
        }
      } catch (e) {
        print('CR: error enumerating local tracks: $e');
      }
      // 旧 API: addStream, 新版建议 addTrack；这里用 addTrack 更稳
      for (var t in localStream!.getTracks()) {
        pc!.addTrack(t, localStream!);
        print('CR: added local track id=${t.id}, kind=${t.kind}');
      }
      // attach local stream to renderer for preview
      try {
        _localRenderer.srcObject = localStream;
      } catch (e) {
        print('CR: failed to attach local renderer: $e');
      }
    } catch (e) {
      print('getUserMedia error: $e');
      return;
    }

    // 监听 ICE candidate
    pc!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate != null && currentCallId != null) {
        signaling.send({
          "type": "candidate",
          "callId": currentCallId,
          // Include explicit recipient to help signaling server routing
          "to": widget.caregiverId,
          "candidate": {
            "candidate": candidate.candidate,
            "sdpMid": candidate.sdpMid,
            "sdpMLineIndex": candidate.sdpMLineIndex,
          }
        });
      }
    };

    // Debug: connection/signaling state
    try {
      pc!.onConnectionState = (RTCPeerConnectionState state) {
        print('CR: pc connection state -> $state');
      };
      pc!.onSignalingState = (RTCSignalingState state) {
        print('CR: pc signaling state -> $state');
      };
    } catch (e) {
      // ignore if older flutter_webrtc version doesn't support these callbacks
    }

    // 创建 offer
    final offer = await pc!.createOffer();
    await pc!.setLocalDescription(offer);

    // 建立 callId
    final callId = const Uuid().v4();

    // prepare a completer and send start_call; we'll wait for start_call_ack
    _startCallAckCompleter = Completer<String?>();

    final startPayload = {
      "type": "start_call",
      "to": widget.caregiverId,
      "callId": callId,
      "offer": {
        "sdp": offer.sdp,
        "type": offer.type,
      }
    };

    // Log the exact payload so we can verify `to` is present (e.g. 'CG-003')
    try {
      print('📞 CR → sending start_call payload: ${jsonEncode(startPayload)}');
    } catch (e) {
      // Fallback to printing the map if JSON encoding fails
      print('📞 CR → sending start_call payload (map): $startPayload');
    }

    if (widget.caregiverId.trim().isEmpty) {
      print('CR: WARNING — caregiverId is empty. start_call will not be routable (missing `to`).');
    }

    signaling.send(startPayload);

    print("📞 CR → 发起呼叫 (sent), awaiting ack, callId(local) = $callId");

    // update UI to show calling state
    if (mounted) setState(() { isCalling = true; });

    // wait up to 5s for server ack that it forwarded the incoming_call
    try {
      final ackCallId = await _startCallAckCompleter!.future.timeout(const Duration(seconds: 5));
      if (ackCallId != null) {
        currentCallId = ackCallId;
        print('start_call acknowledged by server, callId=$currentCallId');
      } else {
        print('start_call ack received but no callId');
      }
    } catch (e) {
      print('No start_call_ack received within timeout: $e');
      // leave currentCallId as null to prevent candidate sends
      currentCallId = null;
      if (mounted) {
        setState(() { isCalling = false; });
      }
    } finally {
      _startCallAckCompleter = null;
    }
  }

  // ───────────────────────────────────────────
  // Step 2: 处理从服务器收到的信令消息
  // ───────────────────────────────────────────
  void handleSignalMessage(Map<String, dynamic> msg) async {
    final type = msg['type'];

    // Caregiver 已接听 → 收到 answer
    if (type == "answer") {
      print("📲 收到 caregiver answer");

      final answer = RTCSessionDescription(
        msg['answer']['sdp'] as String,
        msg['answer']['type'] as String,
      );
      try {
        await pc?.setRemoteDescription(answer);
        print("🔗 通话建立完成");
        if (!mounted) return;
        setState(() {
          inCall = true;
          isCalling = false;
        });
        // if remote renderer not set yet, try to attach ontrack handler
        pc?.onTrack = (RTCTrackEvent event) {
          if (event.streams.isNotEmpty) {
            _remoteRenderer.srcObject = event.streams[0];
          }
        };
      } catch (e) {
        print('setRemoteDescription error: $e');
      }
      return;
    }

    // 收到 candidate
    if (type == "candidate") {
      print("📡 收到 candidate");

      final c = msg['candidate'];
      if (c != null) {
        final candidate = RTCIceCandidate(
          c['candidate'] as String?,
          c['sdpMid'] as String?,
          c['sdpMLineIndex'] as int?,
        );
        try {
          await pc?.addCandidate(candidate);
        } catch (e) {
          // some flutter_webrtc versions use addCandidate, others use addIceCandidate;
          // if addCandidate is not available, try addIceCandidate (but do not define an extension)
          print('addCandidate error: $e');
        }
      }
      return;
    }

    // server-side error notifications
    if (type == 'error') {
      final err = msg['message'];
      print('Signaling error from server: $err');
      // If we were awaiting start_call_ack, notify the waiter
      if (_startCallAckCompleter != null) {
        try {
          _startCallAckCompleter?.complete(null);
        } catch (e) {}
      }
      // Optionally show UI message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signaling error: $err')));
      }
      return;
    }

    if (type == "reject_call") {
      print("❌ Caregiver 拒接");
      // 可以提示 UI
      await endCall();
      if (mounted) setState(() { isCalling = false; inCall = false; currentCallId = null; });
      return;
    }

    if (type == "end_call") {
      print("🛑 通话结束");
      await endCall();
      if (mounted) setState(() { isCalling = false; inCall = false; currentCallId = null; });
      return;
    }

    // 处理其他类型如 incoming_call (如果 CR 也能收到自己的 start_call 回 ack)
    if (type == 'start_call_ack') {
      // server ack with callId
      print('start_call ack: ${msg['callId']}');
      try {
        _startCallAckCompleter?.complete(msg['callId'] as String?);
      } catch (e) {}
    }
  }

  // ───────────────────────────────────────────
  // Step 3: 挂断
  // ───────────────────────────────────────────
  Future<void> endCall({bool skipSetState = false}) async {
    if (currentCallId != null) {
      final ok = signaling.send({
        "type": "end_call",
        "callId": currentCallId,
      });
      print('CR: sent end_call (callId=$currentCallId) sendReturned=$ok');
      // Small delay to allow signaling message to be delivered before tearing down
      await Future.delayed(const Duration(milliseconds: 250));
    }

    try {
      print('CR: closing pc');
      await pc?.close();
    } catch (_) {}
    pc = null;

    // ensure local media (camera + mic) are stopped together
    await _stopLocalMedia();

    currentCallId = null;
    // Only update UI if still mounted and caller didn't request skip
    if (!skipSetState && mounted) {
      setState(() { isCalling = false; inCall = false; });
    }
  }

  Future<void> _stopLocalMedia() async {
    try {
      if (localStream != null) {
        print('CR: stopping localStream id=${localStream!.id}');
        for (var t in localStream!.getTracks()) {
          print('CR: stopping track id=${t.id} kind=${t.kind}');
          try { t.stop(); } catch (_) {}
        }
        try { await localStream?.dispose(); } catch (_) {}
      }
    } catch (e) {
      print('CR: error stopping local media: $e');
    }
    localStream = null;
    try { _localRenderer.srcObject = null; } catch (_) {}
    try { _remoteRenderer.srcObject = null; } catch (_) {}

    // Only update UI state if widget is still mounted
    if (mounted) {
      setState(() { isMuted = false; });
    }
  }

  // Synchronous forced cleanup used inside dispose (must NOT call setState)
  void _forceCleanupSync() {
    // prevent signaling callback from firing into this State after dispose
    try {
      // try to null the callback if SignalingService exposes it
      // If your SignalingService doesn't expose a public field, add a method to clear callbacks.
      // ignore: avoid_dynamic_calls
      (signaling as dynamic).onMessage = null;
    } catch (_) {}

    try { signaling.unregister(); } catch (_) {}
    try { signaling.close(); } catch (_) {}

    try {
      pc?.close();
    } catch (_) {}
    pc = null;

    // stop tracks synchronously (best-effort)
    if (localStream != null) {
      for (var t in localStream!.getTracks()) {
        try { t.stop(); } catch (_) {}
      }
      try { localStream?.dispose(); } catch (_) {}
    }
    localStream = null;

    try { _localRenderer.srcObject = null; } catch (_) {}
    try { _remoteRenderer.srcObject = null; } catch (_) {}
    try { _remoteRenderer.dispose(); } catch (_) {}
    try { _localRenderer.dispose(); } catch (_) {}
  }

  @override
  void dispose() {
    // synchronous cleanup only (no setState)
    _forceCleanupSync();

    // notify server / graceful teardown without touching UI (fire-and-forget)
    endCall(skipSetState: true);

    super.dispose();
  }

  void _toggleMute() {
    if (localStream == null) {
      // nothing to mute; reflect UI state
      if (!mounted) return;
      setState(() {
        isMuted = true;
      });
      return;
    }
    try {
      for (var t in localStream!.getAudioTracks()) {
        t.enabled = !t.enabled;
      }
      if (mounted) {
        setState(() {
          isMuted = localStream!.getAudioTracks().every((t) => !t.enabled);
        });
      }
    } catch (e) {
      print('CR: toggle mute error: $e');
    }
  }

  // ───────────────────────────────────────────
  // UI
  // ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CR Emergency Call")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // split view: left = local (self), right = remote (other)
            _hasCurrentUser
                ? Stack(
                    children: [
                      Container(
                        height: 300,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                color: Colors.black,
                                child: RTCVideoView(_localRenderer, mirror: true),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Container(
                                color: Colors.black,
                                child: RTCVideoView(_remoteRenderer),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // local name box (left)
                      Positioned(
                        left: 8,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('You: ${myDisplayName.isNotEmpty ? myDisplayName : myClientId}', style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                      // remote name box (right)
                      Positioned(
                        right: 8,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Other: ${remoteDisplayName.isNotEmpty ? remoteDisplayName : (widget.caregiverId.isNotEmpty ? widget.caregiverId : "-")}', style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 300,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.black12,
                    child: const Center(child: Text('Waiting', style: TextStyle(fontSize: 18))),
                  ),
            if (inCall) ...[
              const Icon(Icons.call, size: 80, color: Colors.green),
              const SizedBox(height: 12),
              Text('In call with ${widget.caregiverId}'),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.call_end),
                    label: const Text('Hang up'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: endCall,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
                    label: Text(isMuted ? 'Unmute' : 'Mute'),
                    onPressed: _toggleMute,
                  ),
                ],
              ),
            ] else if (isCalling) ...[
              const Icon(Icons.call_made, size: 80, color: Colors.orange),
              const SizedBox(height: 12),
              Text('Calling ${widget.caregiverId}...'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  // cancel the outgoing call
                  endCall();
                },
                child: const Text('Cancel'),
              ),
            ] else ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                ),
                child: const Text('📞 Emergency Call', style: TextStyle(fontSize: 22)),
                onPressed: _startCall,
              ),

            ],


          ],
        ),
      ),
    );
  }
}
