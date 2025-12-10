// lib/screens/cremergency_call.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:carelink_mobile/utils/signal_service.dart';
import 'package:carelink_mobile/screens/cg_emergency_call.dart'; // optional: navigate to CG page for testing

class CREmergencyCall extends StatefulWidget {
  final String careRecipientId;
  final String signalingUrl;

  const CREmergencyCall({
    super.key,
    required this.careRecipientId,
    required this.signalingUrl,
  });

  @override
  State<CREmergencyCall> createState() => _CREmergencyCallState();
}

class _CREmergencyCallState extends State<CREmergencyCall> {
  late SignalingService signaling;
  RTCPeerConnection? pc;
  MediaStream? localStream;
  String? currentCallId;
  Completer<String?>? _startCallAckCompleter;
  bool isCalling = false;
  bool inCall = false;
  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    signaling = SignalingService(onMessage: handleSignalMessage);
    final myClientId = 'CR-${const Uuid().v4()}';
    debugPrint('CREmergencyCall: joining as $myClientId');
    signaling.connect(widget.signalingUrl, myClientId, 'cr');
  }

  Future<void> startCall() async {
    await signaling.ready;
    // create PeerConnection
    pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    // capture mic (audio-only)
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      for (var t in localStream!.getTracks()) {
        pc!.addTrack(t, localStream!);
      }
    } catch (e) {
      debugPrint('CREmergencyCall: getUserMedia error: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      return;
    }

    // send ICE candidates
    pc!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate != null && currentCallId != null) {
        signaling.send({
          'type': 'candidate',
          'callId': currentCallId,
          'to': widget.careRecipientId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    // create offer
    final offer = await pc!.createOffer();
    await pc!.setLocalDescription(offer);

    // generate callId and wait for ack
    final callIdLocal = const Uuid().v4();
    _startCallAckCompleter = Completer<String?>();
    signaling.send({
      'type': 'start_call',
      'to': widget.careRecipientId,
      'callId': callIdLocal,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });

    if (mounted)
      setState(() {
        isCalling = true;
      });

    try {
      final ackCallId = await _startCallAckCompleter!.future.timeout(
        const Duration(seconds: 5),
      );
      if (ackCallId != null) {
        currentCallId = ackCallId;
        debugPrint(
          'CREmergencyCall: start_call ack received callId=$currentCallId',
        );
      } else {
        debugPrint('CREmergencyCall: start_call ack received null');
      }
    } catch (e) {
      debugPrint('CREmergencyCall: no start_call_ack within timeout: $e');
      currentCallId = null;
      if (mounted)
        setState(() {
          isCalling = false;
        });
    } finally {
      _startCallAckCompleter = null;
    }
  }

  void handleSignalMessage(Map<String, dynamic> msg) async {
    final type = msg['type'];
    if (type == 'start_call_ack') {
      try {
        _startCallAckCompleter?.complete(msg['callId'] as String?);
      } catch (_) {}
      return;
    }

    if (type == 'answer') {
      final ans = msg['answer'] as Map<String, dynamic>?;
      if (ans != null) {
        final desc = RTCSessionDescription(
          ans['sdp'] as String?,
          ans['type'] as String?,
        );
        try {
          await pc?.setRemoteDescription(desc);
          if (mounted)
            setState(() {
              inCall = true;
              isCalling = false;
            });
        } catch (e) {
          debugPrint('CREmergencyCall: setRemoteDescription(answer) error: $e');
        }
      }
      return;
    }

    if (type == 'candidate') {
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
          debugPrint('CREmergencyCall: addCandidate error: $e');
        }
      }
      return;
    }

    if (type == 'reject_call') {
      debugPrint('CREmergencyCall: call rejected');
      await endCall();
      if (mounted)
        setState(() {
          isCalling = false;
          inCall = false;
          currentCallId = null;
        });
      return;
    }

    if (type == 'end_call') {
      await endCall();
      if (mounted)
        setState(() {
          isCalling = false;
          inCall = false;
          currentCallId = null;
        });
      return;
    }

    if (type == 'error') {
      final msgTxt = msg['message'];
      debugPrint('CREmergencyCall: signaling error $msgTxt');
      try {
        _startCallAckCompleter?.complete(null);
      } catch (_) {}
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Signaling error: $msgTxt')));
      return;
    }
  }

  Future<void> endCall() async {
    if (currentCallId != null) {
      signaling.send({'type': 'end_call', 'callId': currentCallId});
      await Future.delayed(const Duration(milliseconds: 250));
    }
    try {
      pc?.close();
    } catch (_) {}
    pc = null;

    try {
      if (localStream != null) {
        for (var t in localStream!.getTracks()) {
          try {
            t.stop();
          } catch (_) {}
        }
        try {
          localStream?.dispose();
        } catch (_) {}
      }
    } catch (_) {}
    localStream = null;

    currentCallId = null;
    if (mounted)
      setState(() {
        isCalling = false;
        inCall = false;
      });
  }

  void _toggleMute() {
    if (localStream == null) {
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
      debugPrint('CREmergencyCall: toggle mute error $e');
    }
  }

  @override
  void dispose() {
    endCall();
    signaling.onMessage = null; // <-- remove listener
    signaling.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Care Recipient - Emergency Call')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inCall) ...[
              const Icon(Icons.call, size: 80, color: Colors.green),
              const SizedBox(height: 12),
              Text('In call with ${widget.careRecipientId}'),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.call_end),
                    label: const Text('Hang up'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
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
              Text('Calling ${widget.careRecipientId}...'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: endCall, child: const Text('Cancel')),
            ] else ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                ),
                child: const Text(
                  '📞 Emergency Call',
                  style: TextStyle(fontSize: 22),
                ),
                onPressed: startCall,
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: endCall, child: const Text('End Call')),
              const SizedBox(height: 20),
              Text('CallId: ${currentCallId ?? "none"}'),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              child: const Text('Open Caregiver page (for test)'),
              onPressed: () {
                context.push('/caregiveremergencycall');
              },
            ),
          ],
        ),
      ),
    );
  }
}
