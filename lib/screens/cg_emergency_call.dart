// lib/screens/cgemergency_call.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:carelink_mobile/utils/signal_service.dart';

class CGEmergencyCall extends StatefulWidget {
  final String caregiverId;
  final String signalingUrl;
  const CGEmergencyCall({
    super.key,
    required this.caregiverId,
    required this.signalingUrl,
  });

  @override
  State<CGEmergencyCall> createState() => _CGEmergencyCallState();
}

class _CGEmergencyCallState extends State<CGEmergencyCall> {
  late SignalingService signaling;
  RTCPeerConnection? pc;
  MediaStream? localStream;
  final _remoteRenderer = RTCVideoRenderer();
  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'incoming_calls',
    'Incoming Calls',
    description: 'Incoming call notifications',
    importance: Importance.max,
  );
  Map<String, dynamic>? incomingOffer;
  String? incomingFrom;
  String? currentCallId;
  bool isRinging = false;
  bool inCall = false;
  bool isMuted = false;
  final List<Map<String, dynamic>> _bufferedCandidates = [];
  Completer<Map<String, dynamic>?>? _offerCompleter;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initNotifications();
    signaling = SignalingService(onMessage: handleSignalMessage);
    // Some signaling servers expect clientId/role in the websocket URL
    // instead of receiving a separate 'register' message. Use query params
    // to identify this client so the server can route incoming calls.
    signaling.connect(widget.signalingUrl, widget.caregiverId, 'caregiver', useQueryParams: true);
  }

  Future<void> _initNotifications() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _fln.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && mounted) {
            if (payload.startsWith('accept:')) {
              // user tapped notification to accept
              acceptCall();
            } else if (payload.startsWith('reject:')) {
              rejectCall();
            }
          }
        },
      );

      await _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    } catch (e) {
      debugPrint('CGEmergencyCall: notification init error $e');
    }
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
  }

  void handleSignalMessage(Map<String, dynamic> msg) async {
    if (!mounted) return;
    final type = msg['type'];
    if (type == 'incoming_call') {
      incomingFrom = msg['from'] as String?;
      currentCallId = msg['callId'] as String?;
      incomingOffer = (msg['offer'] as Map<String, dynamic>?);
      isRinging = true;
      setState(() {});
      // show a local notification for incoming call
      try {
        _requestNotificationPermission();
        _showIncomingNotification();
      } catch (e) {
        debugPrint('CGEmergencyCall: show notification error $e');
      }
      return;
    }

    if (type == 'candidate') {
      final c = msg['candidate'];
      if (c != null) {
        if (pc != null) {
          final candidate = RTCIceCandidate(
            c['candidate'] as String?,
            c['sdpMid'] as String?,
            c['sdpMLineIndex'] as int?,
          );
          try {
            await pc!.addCandidate(candidate);
          } catch (e) {
            debugPrint('CGEmergencyCall: addCandidate error $e');
          }
        } else {
          _bufferedCandidates.add(c as Map<String, dynamic>);
        }
      }
      return;
    }

    if (type == 'offer') {
      incomingOffer = msg['offer'] as Map<String, dynamic>?;
      try {
        _offerCompleter?.complete(incomingOffer);
      } catch (_) {}
      return;
    }

    if (type == 'end_call') {
      final callId = msg['callId'];
      if (callId == currentCallId) {
        _hangupFromRemote();
      }
      return;
    }

    if (type == 'error') {
      debugPrint('CGEmergencyCall: signaling error ${msg['message']}');
      return;
    }
  }

  Future<void> acceptCall() async {
    if (currentCallId == null) return;
    pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        final s = event.streams[0];
        _remoteRenderer.srcObject = s;
      }
    };
    pc!.onAddStream = (MediaStream s) {
      _remoteRenderer.srcObject = s;
    };

    pc!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate != null && currentCallId != null) {
        signaling.send({
          'type': 'candidate',
          'callId': currentCallId,
          'to': incomingFrom,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    // request mic
    final ok = await _requestMicPermission();
    if (!ok) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      return;
    }

    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      for (var t in localStream!.getTracks()) {
        pc!.addTrack(t, localStream!);
      }
    } catch (e) {
      debugPrint('CGEmergencyCall: getUserMedia error $e');
    }

    // set remote offer (from incomingOffer or request)
    String? offerSdp;
    String? offerType;
    if (incomingOffer != null) {
      offerSdp = incomingOffer!['sdp'];
      offerType = incomingOffer!['type'];
    } else {
      _offerCompleter = Completer<Map<String, dynamic>?>();
      signaling.send({'type': 'get_offer', 'callId': currentCallId});
      try {
        final offerMap = await _offerCompleter!.future.timeout(
          const Duration(seconds: 5),
        );
        if (offerMap != null) {
          offerSdp = offerMap['sdp'];
          offerType = offerMap['type'];
        }
      } catch (e) {
        debugPrint('CGEmergencyCall: timed out waiting for offer: $e');
      } finally {
        _offerCompleter = null;
      }
    }

    if (offerSdp != null) {
      final desc = RTCSessionDescription(offerSdp, offerType ?? 'offer');
      try {
        await pc!.setRemoteDescription(desc);
      } catch (e) {
        debugPrint('CGEmergencyCall: setRemoteDescription error $e');
      }
    } else {
      debugPrint('CGEmergencyCall: no offer available');
    }

    try {
      final answer = await pc!.createAnswer();
      await pc!.setLocalDescription(answer);
      signaling.send({
        'type': 'answer',
        'callId': currentCallId,
        'answer': {'sdp': answer.sdp, 'type': answer.type},
      });

      // drain buffered candidates
      for (var bc in _bufferedCandidates) {
        try {
          final candidate = RTCIceCandidate(
            bc['candidate'] as String?,
            bc['sdpMid'] as String?,
            bc['sdpMLineIndex'] as int?,
          );
          await pc!.addCandidate(candidate);
        } catch (e) {
          debugPrint('CGEmergencyCall: addCandidate(buffered) error $e');
        }
      }
      _bufferedCandidates.clear();

      setState(() {
        inCall = true;
        isRinging = false;
      });
    } catch (e) {
      debugPrint('CGEmergencyCall: createAnswer error $e');
    }
  }

  Future<bool> _requestMicPermission() async {
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) return true;
      final res = await Permission.microphone.request();
      return res.isGranted;
    } catch (e) {
      debugPrint('CGEmergencyCall: permission error $e');
      return false;
    }
  }

  void rejectCall() {
    if (currentCallId != null) {
      signaling.send({'type': 'reject_call', 'callId': currentCallId});
    }
    _cancelIncomingNotification();
    setState(() {
      isRinging = false;
      currentCallId = null;
      incomingFrom = null;
      incomingOffer = null;
    });
  }

  void _hangupFromRemote() {
    _cleanupCall();
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Call ended')));
  }

  Future<void> hangup() async {
    if (currentCallId != null) {
      signaling.send({'type': 'end_call', 'callId': currentCallId});
      await Future.delayed(const Duration(milliseconds: 250));
    }
    _cancelIncomingNotification();
    _cleanupCall();
  }

  void _cleanupCall() {
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
    _remoteRenderer.srcObject = null;
    setState(() {
      currentCallId = null;
      incomingFrom = null;
      incomingOffer = null;
      isRinging = false;
      inCall = false;
    });
    _cancelIncomingNotification();
  }

  Future<void> _showIncomingNotification() async {
    if (currentCallId == null) return;
    final id = currentCallId.hashCode & 0x7fffffff;
    try {
      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        playSound: true,
        ongoing: true,
        visibility: NotificationVisibility.public,
      );
      final iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);

      await _fln.show(
        id,
        'Incoming call',
        'Call from ${incomingFrom ?? 'Care Receiver'}',
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: 'accept:$currentCallId',
      );
    } catch (e) {
      debugPrint('CGEmergencyCall: showIncomingNotification error $e');
    }
  }

  Future<void> _cancelIncomingNotification() async {
    if (currentCallId == null) return;
    final id = currentCallId.hashCode & 0x7fffffff;
    try {
      await _fln.cancel(id);
    } catch (e) {
      debugPrint('CGEmergencyCall: cancel notification error $e');
    }
  }

  Future<bool> _requestNotificationPermission() async {
    try {
      var status = await Permission.notification.status;
      if (status.isGranted) return true;
      final res = await Permission.notification.request();
      return res.isGranted;
    } catch (e) {
      debugPrint('CGEmergencyCall: notification permission error $e');
      return true;
    }
  }

  @override
  void dispose() {
    signaling.onMessage = null; // <-- remove listener
    signaling.close();
    try {
      _remoteRenderer.dispose();
    } catch (_) {}
    _cleanupCall();
    super.dispose();
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
      debugPrint('CGEmergencyCall: toggle mute error $e');
    }
  }

  void _simulateIncomingCall() {
    final fake = {
      'type': 'incoming_call',
      'from': 'CR-SIM',
      'callId': 'sim-${DateTime.now().millisecondsSinceEpoch}',
      'meta': {'priority': 'sim'},
    };
    handleSignalMessage(fake);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Caregiver - Incoming Calls (${widget.caregiverId})'),
      ),
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
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
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          size: 80,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Incoming call from ${incomingFrom ?? 'CR'}',
                          style: const TextStyle(fontSize: 18),
                        ),
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                              ),
                              onPressed: rejectCall,
                            ),
                          ],
                        ),
                      ],
                    )
                  : const Text(
                      'Waiting for calls...',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ),
          if (kDebugMode && !inCall)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bug_report),
                label: const Text('Simulate incoming call (debug)'),
                onPressed: _simulateIncomingCall,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }
}
