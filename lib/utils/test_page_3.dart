// caregiver_call_page.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:carelink_mobile/utils/signal_service.dart';

class TestPage3 extends StatefulWidget {
  final String caregiverId; // 本机的 clientId (eg. "cg-999")
  final String signalingUrl; // ws://...:25101 or wss://...
  const TestPage3({
    super.key,
    required this.caregiverId,
    required this.signalingUrl,
  });

  @override
  State<TestPage3> createState() => _TestPage3State();
}

class _TestPage3State extends State<TestPage3> {
  late SignalingService signaling;
  RTCPeerConnection? pc;
  MediaStream? localStream;
  final _remoteRenderer = RTCVideoRenderer(); // 用来 attach 远端媒体（audio-only 也 OK）
  Map<String, dynamic>? incomingOffer;
  Completer<Map<String, dynamic>?>? _offerCompleter;
  final List<Map<String, dynamic>> _bufferedCandidates = [];

  // 当前正在响铃或通话的 call 信息
  String? incomingFrom;
  String? currentCallId;
  Map<String, dynamic>? incomingMeta;
  bool isRinging = false;
  bool inCall = false;
  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    initRenderers();
    signaling = SignalingService(onMessage: handleSignalMessage);
    // 连接 signaling server 并以 caregiver 身份 join
    signaling.connect(widget.signalingUrl, widget.caregiverId, 'caregiver');
  }

  Future<void> initRenderers() async {
    await _remoteRenderer.initialize();
  }

  // 处理 signaling server 发来的消息
  void handleSignalMessage(Map<String, dynamic> msg) async {
    // If the widget has been disposed, ignore incoming messages.
    if (!mounted) return;
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
      if (mounted) {
        setState(() {
          isRinging = true;
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
          _bufferedCandidates.add(c as Map<String, dynamic>);
        }
      }
      return;
    }

    // 如果 caller 发送 end_call 或 caller offline
    if (type == 'end_call') {
      final callId = msg['callId'];
      if (callId == currentCallId) {
        // 结束通话 / 来电
        // _hangupFromRemote shows a SnackBar; ensure widget still mounted
        if (mounted) {
          _hangupFromRemote();
        } else {
          _cleanupCall();
        }
      }
      return;
    }

    // 如果是 answer（很少出现在 caregiver 端），忽略或处理
    if (type == 'answer') {
      // caregiver 通常不会收到 answer（caller 会），但如果你的流程不同可处理
    }

    // If server sends an 'offer' message (in response to get_offer), store/complete
    if (type == 'offer') {
      incomingOffer = msg['offer'] as Map<String, dynamic>?;
      try {
        _offerCompleter?.complete(incomingOffer);
      } catch (e) {}
    }
  }

  // 接听：设置远端 offer -> 采集本地麦克风 -> createAnswer -> setLocalDescription -> send answer
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
      print('Caregiver: onTrack fired: streams=${event.streams.length}, track=${event.track.id}');
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
    };
    // 兼容旧 API
    pc!.onAddStream = (MediaStream stream) {
      print('Caregiver: onAddStream: ${stream.id}');
      try {
        final audioTracks = stream.getAudioTracks();
        print('Caregiver: onAddStream remote audioTracks=${audioTracks.length}');
        for (var t in audioTracks) {
          print('Caregiver: onAddStream track id=${t.id}, enabled=${t.enabled}');
        }
      } catch (e) {
        print('Caregiver: onAddStream error enumerating tracks: $e');
      }
      _remoteRenderer.srcObject = stream;
    };

    // ICE 候选：发送给 caller（以 callId 为路由）
    pc!.onIceCandidate = (RTCIceCandidate candidate) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required')));
      }
      return;
    }

    // 采集本地麦克风并加入 pc
    try {
      localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      print('Caregiver: acquired localStream id=${localStream?.id}');
      // 新版 API: addTrack
      for (var t in localStream!.getTracks()) {
        pc!.addTrack(t, localStream!);
        print('Caregiver: added local track id=${t.id}, kind=${t.kind}');
      }
    } catch (e) {
      print('getUserMedia error: $e');
      // 如果无法获取麦克风，仍可创建 answer（但通话无声音）或拒接
    }
    // 设置远端 offer
    // NOTE: 来电的 offer 在 signaling msg 的 offer 字段
    // 我们假设 server 发来的 offer 格式为 { sdp, type }
    // 如果 offer 不在 currentCallId 的消息里，你应把刚收到的 incoming_call 的 offer 缓存
    // 这里尝试从 incoming call 处理（需 earlier 保存）
    // For safety, try to read a cached offer from incomingMeta or last message
    // but easier: expect server includes offer in incoming_call (we did in server).
    // We'll request the offer from the server by sending a 'get_offer' if needed.
    // For now, rely on msg.offer passed when incoming_call arrived and stored in incomingMeta
    // We'll search for it in incomingMeta (or you can modify server to guarantee offer in incoming_call)
    // Implementation below expects that incoming offer was stored in incomingMeta['offer'] or the incoming message previously kept it.

    // For robust approach: ask server for the offer if not present.
    // But in our flow the server forwarded offer in incoming_call, so we stored it earlier.
    // We'll retrieve from incomingMeta or from the earlier incoming message variable
    // (We stored none; so let's request the offer by a simple protocol: send 'get_offer')
    // To keep simple, assume incoming offer was included as last message - so caller included it.
    // If you find no offer, you should implement a 'get_offer' message to server.

    // Attempt: ask server for offer if we don't have one in incomingMeta
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

      if (mounted) {
        setState(() {
          inCall = true;
          isRinging = false;
        });
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
    if (mounted) {
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
    if (mounted) {
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

    _remoteRenderer.srcObject = null;
    // Protect against calling setState after dispose (defunct element)
    if (mounted) {
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
    _remoteRenderer.dispose();
    // Unregister callback first to avoid any in-flight messages calling into
    // this widget after dispose. Then close the websocket.
    try {
      signaling.unregister();
    } catch (e) {}
    signaling.close();
    _cleanupCall();
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
      setState(() {
        isMuted = true;
      });
      return;
    }
    try {
      for (var t in localStream!.getAudioTracks()) {
        t.enabled = !t.enabled;
      }
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
