// caregiver_call_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:carelink_mobile/utils/signal_service.dart';
import 'package:carelink_mobile/utils/user_service.dart';

class CGEmergencyCall extends StatefulWidget {
  final String careRecipientID;
  final String signalingUrl;

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

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  String localDisplayName = '';
  String remoteDisplayName = '';

  bool _hasCurrentUser = false;
  bool isRinging = false;
  bool inCall = false;
  bool isMuted = false;

  String? incomingFrom;
  String? currentCallId;
  Map<String, dynamic>? incomingMeta;
  Map<String, dynamic>? incomingOffer;

  final List<Map<String, dynamic>> _bufferedCandidates = [];
  Completer<Map<String, dynamic>?>? _offerCompleter;

  bool _disposed = false;

  // =======================
  // Lifecycle
  // =======================
  @override
  void initState() {
    super.initState();
    _initRenderers();
    signaling = SignalingService(onMessage: handleSignalMessage);
    signaling.connect(widget.signalingUrl, widget.careRecipientID, 'caregiver');
    _loadLocalUser();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _loadLocalUser() async {
    final u = await fetchCurrentUser();
    if (!mounted || _disposed) return;

    setState(() {
      if (u != null) {
        localDisplayName =
            (u['displayName'] as String?) ?? widget.careRecipientID;
        _hasCurrentUser = true;
      } else {
        localDisplayName = widget.careRecipientID;
        _hasCurrentUser = false;
      }
    });
  }

  // =======================
  // Signaling
  // =======================
  Future<void> handleSignalMessage(Map<String, dynamic> msg) async {
    if (!mounted || _disposed) return;

    switch (msg['type']) {
      case 'incoming_call':
        incomingFrom = msg['from'];
        currentCallId = msg['callId'];
        incomingMeta = msg['meta'];
        incomingOffer = msg['offer'];

        setState(() => isRinging = true);

        if (incomingFrom != null) {
          fetchUserByUid(incomingFrom!).then((u) {
            if (!mounted || _disposed) return;
            setState(() {
              remoteDisplayName =
                  (u?['displayName'] as String?) ?? incomingFrom!;
            });
          });
        }
        break;

      case 'candidate':
        if (pc != null) {
          final c = msg['candidate'];
          await pc!.addCandidate(
            RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
          );
        } else {
          _bufferedCandidates.add(Map<String, dynamic>.from(msg['candidate']));
        }
        break;

      case 'end_call':
        _hangupFromRemote();
        break;

      case 'offer':
        incomingOffer = msg['offer'];
        _offerCompleter?.complete(incomingOffer);
        break;
    }
  }

  // =======================
  // Call control
  // =======================
  Future<void> acceptCall() async {
    pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    });

    pc!.onTrack = (e) {
      if (e.streams.isNotEmpty) {
        _remoteRenderer.srcObject = e.streams[0];
      }
    };

    pc!.onIceCandidate = (c) {
      if (c.candidate != null) {
        signaling.send({
          'type': 'candidate',
          'callId': currentCallId,
          'to': incomingFrom,
          'candidate': {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          }
        });
      }
    };

    // Disable video if the incoming caller is Watch-003
    final bool videoEnabled = (incomingFrom != 'Watch-003');

    if (!await _requestPermissions(camera: videoEnabled)) return;

    localStream = await navigator.mediaDevices
      .getUserMedia({'audio': true, 'video': videoEnabled});
    _localRenderer.srcObject = localStream;

    for (var t in localStream!.getTracks()) {
      pc!.addTrack(t, localStream!);
    }

    if (incomingOffer == null) {
      _offerCompleter = Completer();
      signaling.send({'type': 'get_offer', 'callId': currentCallId});
      incomingOffer =
          await _offerCompleter!.future.timeout(const Duration(seconds: 5));
    }

    await pc!.setRemoteDescription(
      RTCSessionDescription(
        incomingOffer!['sdp'],
        incomingOffer!['type'],
      ),
    );

    final answer = await pc!.createAnswer();
    await pc!.setLocalDescription(answer);

    signaling.send({
      'type': 'answer',
      'callId': currentCallId,
      'answer': {'sdp': answer.sdp, 'type': answer.type}
    });

    for (var c in _bufferedCandidates) {
      await pc!.addCandidate(
        RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
      );
    }
    _bufferedCandidates.clear();

    if (!mounted || _disposed) return;

    setState(() {
      inCall = true;
      isRinging = false;
    });
  }

  Future<bool> _requestPermissions({bool camera = false}) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    if (camera) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return false;
    }
    return true;
  }

  void hangup() {
    signaling.send({'type': 'end_call', 'callId': currentCallId});
    _cleanupCall();
  }

  void _hangupFromRemote() {
    if (!mounted || _disposed) return;

    _cleanupCall();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disposed) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Call ended')));
    });
  }

  // =======================
  // Cleanup (SAFE)
  // =======================
  void _cleanupCallInternal() {
    pc?.close();
    pc = null;

    localStream?.getTracks().forEach((t) => t.stop());
    localStream = null;

    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;

    isRinging = false;
    inCall = false;
    currentCallId = null;
    incomingFrom = null;
  }

  void _cleanupCall() {
    _cleanupCallInternal();
    if (mounted && !_disposed) {
      setState(() {});
    }
  }

  void _toggleMute() {
    if (localStream == null) return;
    for (var t in localStream!.getAudioTracks()) {
      t.enabled = !t.enabled;
    }
    if (!mounted || _disposed) return;
    setState(() {
      isMuted = localStream!.getAudioTracks().every((t) => !t.enabled);
    });
  }

  // =======================
  // UI
  // =======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(
        title: 'Emergency Call',
        showBack: true,
        showSearch: false,
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return orientation == Orientation.landscape
              ? _buildLandscapeUI()
              : _buildPortraitUI();
        },
      ),
    );
  }

  Widget _buildPortraitUI() {
    return LayoutBuilder(
      builder: (context, c) {
        final videoHeight = c.maxHeight * 0.45;
        return Column(
          children: [
            SizedBox(height: videoHeight, child: _videoView()),
            Expanded(child: _controlArea()),
          ],
        );
      },
    );
  }

  Widget _buildLandscapeUI() {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
            Expanded(child: RTCVideoView(_remoteRenderer)),
          ],
        ),
        Positioned(bottom: 24, left: 0, right: 0, child: _floatingControls()),
      ],
    );
  }

  Widget _videoView() {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
            Expanded(child: RTCVideoView(_remoteRenderer)),
          ],
        ),
      ],
    );
  }

  Widget _controlArea() {
    if (inCall) return _inCallControls();
    if (isRinging) return _incomingCallWidget();
    return const Center(child: Text('Waiting for calls...'));
  }

  Widget _inCallControls() {
    return Column(
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
    );
  }

  Widget _floatingControls() {
    if (!inCall) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          backgroundColor: Colors.red,
          onPressed: hangup,
          child: const Icon(Icons.call_end),
        ),
        const SizedBox(width: 16),
        FloatingActionButton(
          onPressed: _toggleMute,
          child: Icon(isMuted ? Icons.mic_off : Icons.mic),
        ),
      ],
    );
  }

  Widget _incomingCallWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.notifications_active,
            size: 80, color: Colors.orange),
        const SizedBox(height: 12),
        Text('Incoming call from ${incomingFrom ?? 'CR'}'),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: acceptCall,
              child: Text(incomingFrom == 'Watch-003' ? 'Accept (Audio Only)' : 'Accept'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: hangup,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text('Reject'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _disposed = true;
    signaling.close();
    _cleanupCallInternal();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }
}
