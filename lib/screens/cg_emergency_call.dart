// caregiver_call_page.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:carelink_mobile/utils/signal_service.dart';
import 'package:carelink_mobile/utils/user_service.dart';

class CGEmergencyCall extends StatefulWidget {
  final String careRecipientID; // 本机的 clientId (eg. "cg-999")
  final String signalingUrl; // ws://...:25101 or wss://...
  const CGEmergencyCall({
    super.key,
    required this.careRecipientID,
    required this.signalingUrl,
  });

  @override
  State<CGEmergencyCall> createState() => _CGEmergencyCallState();
}

class _CGEmergencyCallState extends State<CGEmergencyCall> {
  late SignalingService signaling;
  RTCPeerConnection? pc;
  MediaStream? localStream;
  final _remoteRenderer = RTCVideoRenderer(); // 用来 attach 远端媒体（audio-only 也 OK）
  final _localRenderer = RTCVideoRenderer();
  Map<String, dynamic>? incomingOffer;
  Completer<Map<String, dynamic>?>? _offerCompleter;
  final List<Map<String, dynamic>> _bufferedCandidates = [];
  String localDisplayName = '';
  String remoteDisplayName = '';
  bool _hasCurrentUser = false;

  // 当前正在响铃或通话的 call 信息
  String? incomingFrom;
  String? currentCallId;
  Map<String, dynamic>? incomingMeta;
  bool isRinging = false;
  bool inCall = false;
  bool isMuted = false;

  // internal flag to avoid touching UI after dispose
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // Initialize renderers (fire-and-forget)
    initRenderers();
    signaling = SignalingService(onMessage: handleSignalMessage);
    // 连接 signaling server 并以 caregiver 身份 join
    signaling.connect(widget.signalingUrl, widget.careRecipientID, 'caregiver');
    // init local renderer
    _initLocalRenderer();
    _loadLocalUser();
  }

  Future<void> initRenderers() async {
    try {
      await _remoteRenderer.initialize();
    } catch (e) {
      print('Caregiver: remote renderer init error: $e');
    }
  }

  Future<void> _initLocalRenderer() async {
    try {
      await _localRenderer.initialize();
    } catch (e) {
      print('Caregiver: local renderer init error: $e');
    }
  }

  Future<void> _loadLocalUser() async {
    try {
      final u = await fetchCurrentUser();
      if (!mounted || _disposed) return;

      if (u != null) {
        final display = (u['displayName'] as String?)?.trim();
        if (!mounted || _disposed) return;
        setState(() {
          localDisplayName = display ?? (u['uid'] as String? ?? widget.careRecipientID);
          _hasCurrentUser = true;
        });
      } else {
        // fallback to provided careRecipientID
        if (!mounted || _disposed) return;
        setState(() {
          localDisplayName = widget.careRecipientID;
          _hasCurrentUser = false;
        });
      }
    } catch (e) {
      print('Caregiver: loadLocalUser error: $e');
      if (!mounted || _disposed) return;
      setState(() {
        _hasCurrentUser = false;
      });
    }
  }

  // 处理 signaling server 发来的消息
  Future<void> handleSignalMessage(Map<String, dynamic> msg) async {
    // If the widget has been disposed, ignore incoming messages.
    if (!mounted || _disposed) return;
    // guard against bad payloads
    if (msg == null) return;
    print('TestPage3: handleSignalMessage called - mounted=$mounted, msg=$msg');

    final type = msg['type'];
    // incoming_call: { type: 'incoming_call', from, callId, offer, meta }
    if (type == 'incoming_call') {
      // 新来电
      incomingFrom = msg['from'] as String?;
      currentCallId = msg['callId'] as String?;
      incomingMeta = msg['meta'] as Map<String, dynamic>?;
      // store offer if provided by server in the incoming_call
      if (msg['offer'] != null) {
        incomingOffer = msg['offer'] as Map<String, dynamic>?;
        // complete any waiter awaiting an offer
        try {
          _offerCompleter?.complete(incomingOffer);
        } catch (e) {}
      }
      print('Incoming call from $incomingFrom callId=$currentCallId');

      if (!mounted || _disposed) return;
      setState(() {
        isRinging = true;
      });

      // try to resolve incomingFrom to a displayName (async)
      if (incomingFrom != null && incomingFrom!.isNotEmpty) {
        fetchUserByUid(incomingFrom!).then((u) {
          if (!mounted || _disposed) return;
          if (u != null) {
            try {
              if (!mounted || _disposed) return;
              setState(() {
                remoteDisplayName = (u['displayName'] as String?) ?? (u['uid'] as String? ?? incomingFrom!);
              });
            } catch (e) {}
          }
        }).catchError((e) {
          print('Caregiver: fetch remote user error: $e');
        });
      }
      // 弹 UI 由 build 显示
      return;
    }

    // caller / other side sending candidate to caregiver
    if (type == 'candidate') {
      final c = msg['candidate'];
      if (c != null) {
        if (pc != null) {
          try {
            final candidate = RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']);
            await pc!.addCandidate(candidate);
          } catch (e) {
            print('addCandidate error $e');
          }
        } else {
          // buffer candidates until PC is ready
          try {
            _bufferedCandidates.add(Map<String, dynamic>.from(c as Map));
          } catch (_) {}
        }
      }
      return;
    }

    // 如果 caller 发送 end_call 或 caller offline
    if (type == 'end_call') {
      final callId = msg['callId'];
      if (callId == currentCallId) {
        // 结束通话 / 来电
        if (!mounted || _disposed) {
          _cleanupCall();
        } else {
          _hangupFromRemote();
        }
      }
      return;
    }

    // 如果是 answer（很少出现在 caregiver 端），忽略或处理
    if (type == 'answer') {
      // caregiver 通常不会收到 answer（caller 会），但如果你的流程不同可处理
      return;
    }

    // If server sends an 'offer' message (in response to get_offer), store/complete
    if (type == 'offer') {
      incomingOffer = msg['offer'] as Map<String, dynamic>?;
      try {
        _offerCompleter?.complete(incomingOffer);
      } catch (e) {}
    }
  }


  Future<void> acceptCall() async {
    if (currentCallId == null) return;
    // 创建 RTCPeerConnection
    pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        // 生产添加 TURN：{ urls: 'turn:turn.example.com:3478', username:'u', credential:'p' }
      ]
    });

    // 远端流处理（onTrack 或 onAddStream）
    pc!.onTrack = (RTCTrackEvent event) {
      try {
        if (!mounted || _disposed) return;
        if (event.streams.isNotEmpty) {
          final s = event.streams[0];
          try {
            final audioTracks = s.getAudioTracks();
            print('Caregiver: remote stream id=${s.id}, audioTracks=${audioTracks.length}');
            for (var t in audioTracks) {
              print('Caregiver: remote audio track id=${t.id}, kind=${t.kind}, enabled=${t.enabled}');
            }
          } catch (e) {
            print('Caregiver: error enumerating remote tracks: $e');
          }
          _remoteRenderer.srcObject = s;
        }
      } catch (e) {
        print('onTrack handler error: $e');
      }
    };
    // 兼容旧 API
    pc!.onAddStream = (MediaStream stream) {
      try {
        if (!mounted || _disposed) return;
        print('Caregiver: onAddStream: ${stream.id}');
        final audioTracks = stream.getAudioTracks();
        for (var t in audioTracks) {
          print('Caregiver: onAddStream track id=${t.id}, enabled=${t.enabled}');
        }
        _remoteRenderer.srcObject = stream;
      } catch (e) {
        print('onAddStream handler error: $e');
      }
    };

    // ICE 候选：发送给 caller（以 callId 为路由）
    pc!.onIceCandidate = (RTCIceCandidate candidate) {
      try {
        if (candidate.candidate != null && currentCallId != null) {
          signaling.send({
            'type': 'candidate',
            'callId': currentCallId,
            // Include explicit recipient (caller) to help server route this candidate
            'to': incomingFrom,
            'candidate': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            }
          });
        }
      } catch (e) {
        print('onIceCandidate error: $e');
      }
    };

    // Debug: connection/signaling state
    try {
      pc!.onConnectionState = (RTCPeerConnectionState state) {
        print('Caregiver: pc connection state -> $state');
      };
      pc!.onSignalingState = (RTCSignalingState state) {
        print('Caregiver: pc signaling state -> $state');
      };
    } catch (e) {
      // ignore if older flutter_webrtc version doesn't support these callbacks
    }

    // Request runtime microphone permission before attempting to access it.
    final ok = await _requestMicPermission();
    if (!ok) {
      print('Microphone permission denied');
      if (mounted && !_disposed) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required')));
      }
      return;
    }

    // 采集本地麦克风并加入 pc
    try {
      localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': {'facingMode': 'user'}});
      print('Caregiver: acquired localStream id=${localStream?.id}');
      // 新版 API: addTrack
      for (var t in localStream!.getTracks()) {
        pc!.addTrack(t, localStream!);
        print('Caregiver: added local track id=${t.id}, kind=${t.kind}');
      }
      try {
        if (mounted && !_disposed) _localRenderer.srcObject = localStream;
      } catch (e) {
        print('Caregiver: failed to attach local renderer: $e');
      }
    } catch (e) {
      print('getUserMedia error: $e');
      // 如果无法获取麦克风，仍可创建 answer（但通话无声音）或拒接
    }

    // 设置远端 offer
    String? offerSdp;
    String? offerType;
    // Prefer an offer stored earlier (incoming_call may include it)
    if (incomingOffer != null) {
      offerSdp = incomingOffer!['sdp'];
      offerType = incomingOffer!['type'];
    } else if (incomingMeta != null && incomingMeta!['offer'] != null) {
      offerSdp = incomingMeta!['offer']['sdp'];
      offerType = incomingMeta!['offer']['type'];
    }

    if (offerSdp == null) {
      // ask server for the offer and wait a short time
      _offerCompleter = Completer<Map<String, dynamic>?>();
      signaling.send({'type': 'get_offer', 'callId': currentCallId});
      try {
        final offerMap = await _offerCompleter!.future.timeout(const Duration(seconds: 5));
        if (offerMap != null) {
          offerSdp = offerMap['sdp'];
          offerType = offerMap['type'];
        }
      } catch (e) {
        print('Timed out waiting for offer: $e');
      } finally {
        _offerCompleter = null;
      }
    }

    if (offerSdp == null) {
      print('No offer available; cannot set remote description');
    } else {
      var offer = RTCSessionDescription(offerSdp, offerType ?? 'offer');
      try {
        await pc!.setRemoteDescription(offer);
      } catch (e) {
        print('setRemoteDescription error: $e');
      }
    }

    // create answer
    try {
      final answer = await pc!.createAnswer();
      await pc!.setLocalDescription(answer);

      // send answer back to caller (use callId routing)
      signaling.send({
        'type': 'answer',
        'callId': currentCallId,
        'answer': { 'sdp': answer.sdp, 'type': answer.type }
      });

      // Add any buffered ICE candidates that arrived before PC creation
      for (var bc in _bufferedCandidates) {
        try {
          final candidate = RTCIceCandidate(bc['candidate'], bc['sdpMid'], bc['sdpMLineIndex']);
          await pc!.addCandidate(candidate);
        } catch (e) {
          print('addCandidate (buffered) error $e');
        }
      }
      _bufferedCandidates.clear();

      if (mounted && !_disposed) {
        setState(() {
          inCall = true;
          isRinging = false;
        });
        // attach onTrack to populate remote renderer
        pc?.onTrack = (RTCTrackEvent event) {
          if (!mounted || _disposed) return;
          if (event.streams.isNotEmpty) {
            _remoteRenderer.srcObject = event.streams[0];
          }
        };
      }
    } catch (e) {
      print('createAnswer error: $e');
    }
  }

  Future<bool> _requestMicPermission() async {
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) return true;
      final result = await Permission.microphone.request();
      return result.isGranted;
    } catch (e) {
      print('permission request error: $e');
      return false;
    }
  }

  // 拒接
  void rejectCall() {
    if (currentCallId != null) {
      signaling.send({
        'type': 'reject_call',
        'callId': currentCallId,
      });
    }
    if (mounted && !_disposed) {
      setState(() {
        isRinging = false;
        currentCallId = null;
        incomingFrom = null;
        incomingMeta = null;
      });
    } else {
      currentCallId = null;
      incomingFrom = null;
      incomingMeta = null;
      isRinging = false;
    }
  }

  // 远端/对端挂断或 caller 取消
  void _hangupFromRemote() {
    _cleanupCall();
    // Only show SnackBar if still mounted and the context is valid
    if (mounted && !_disposed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call ended')));
    }
  }

  // 人为挂断（Caregiver 点击挂断）
  Future<void> hangup() async {
    if (currentCallId != null) {
      final ok = signaling.send({'type': 'end_call', 'callId': currentCallId});
      print('Caregiver: sent end_call (callId=$currentCallId) sendReturned=$ok');
      // give the signaling a short moment to deliver
      await Future.delayed(const Duration(milliseconds: 250));
    }
    _cleanupCall();
  }

  void _cleanupCall() {
    try {
      print('Caregiver: closing pc');
      pc?.close();
    } catch (e) {}
    pc = null;

    try {
      if (localStream != null) {
        print('Caregiver: stopping localStream id=${localStream!.id}');
        for (var t in localStream!.getTracks()) {
          print('Caregiver: stopping track id=${t.id}');
          try { t.stop(); } catch (_) {}
        }
        try { localStream?.dispose(); } catch (_) {}
      }
    } catch (e) {}
    localStream = null;

    try { _remoteRenderer.srcObject = null; } catch (_) {}
    try { _localRenderer.srcObject = null; } catch (_) {}
    // Protect against calling setState after dispose (defunct element)
    if (mounted && !_disposed) {
      setState(() {
        currentCallId = null;
        incomingFrom = null;
        incomingMeta = null;
        isRinging = false;
        inCall = false;
      });
    } else {
      // Widget already disposed — update fields without setState
      currentCallId = null;
      incomingFrom = null;
      incomingMeta = null;
      isRinging = false;
      inCall = false;
    }
  }

  @override
  void dispose() {
    // set disposed flag first
    _disposed = true;

    // Replace signaling callback with harmless no-op to prevent races
    try {
      // If SignalingService exposes a public setter, use that; otherwise try dynamic
      try {
        signaling.onMessage = (Map<String, dynamic> _) {};
      } catch (_) {
        // fallback dynamic assignment
        // ignore: avoid_dynamic_calls
        (signaling as dynamic).onMessage = (Map<String, dynamic> _) {};
      }
    } catch (_) {}

    try {
      signaling.unregister();
    } catch (e) {}
    try {
      signaling.close();
    } catch (e) {}

    // Cleanup call-related native resources synchronously (no setState here)
    _cleanupCall();

    try { _remoteRenderer.dispose(); } catch (e) {}
    try { _localRenderer.dispose(); } catch (e) {}

    super.dispose();
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caregiver - Incoming Calls')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: inCall
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call, size: 80, color: Colors.green),
                        const SizedBox(height: 12),
                        Text('In call with ${incomingFrom ?? 'CR'}'),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.call_end),
                              label: const Text('Hang up'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: hangup,
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
                              label: Text(isMuted ? 'Unmute' : 'Mute'),
                              onPressed: _toggleMute,
                            ),
                          ],
                        ),
                      ],
                    )
                  : isRinging
                      ? _incomingCallWidget()
                      : const Text('Waiting for calls...', style: TextStyle(fontSize: 18)),
            ),
          ),
          // Debug-only button to simulate an incoming_call message locally
          if (kDebugMode && !inCall)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bug_report),
                label: const Text('Simulate incoming call (debug)'),
                onPressed: () => _simulateIncomingCall(),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
              // split view: left = local (self), right = remote (other) with name overlays
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
                        Positioned(
                          left: 8,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('You: ${localDisplayName.isNotEmpty ? localDisplayName : widget.careRecipientID}', style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Other: ${remoteDisplayName.isNotEmpty ? remoteDisplayName : (incomingFrom ?? "-")}', style: const TextStyle(color: Colors.white)),
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
        ],
      ),
    );
  }

  Widget _incomingCallWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.notifications_active, size: 80, color: Colors.orange),
        const SizedBox(height: 12),
        Text('Incoming call from ${incomingFrom ?? 'CR'}', style: const TextStyle(fontSize: 18)),
        if (incomingMeta != null && incomingMeta!['priority'] != null)
          Text('Priority: ${incomingMeta!['priority']}'),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('Accept'),
              onPressed: acceptCall,
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              onPressed: rejectCall,
            ),
          ],
        ),
      ],
    );
  }

  void _toggleMute() {
    if (localStream == null) {
      // nothing to mute
      if (!mounted || _disposed) return;
      setState(() {
        isMuted = true;
      });
      return;
    }
    try {
      for (var t in localStream!.getAudioTracks()) {
        t.enabled = !t.enabled;
      }
      if (!mounted || _disposed) return;
      setState(() {
        isMuted = localStream!.getAudioTracks().every((t) => !t.enabled);
      });
    } catch (e) {
      print('Caregiver: toggle mute error: $e');
    }
  }

  // Debug helper: simulate an incoming_call message as if received from server
  void _simulateIncomingCall() {
    final fakeMsg = {
      'type': 'incoming_call',
      'from': 'CR-SIM',
      'callId': const Uuid().v4(),
      'meta': {'priority': 'simulated'},
      // 'offer' can be omitted for simulation of UI ringing only
    };
    // Call the handler directly to exercise the normal code path
    handleSignalMessage(fakeMsg);
  }
}
