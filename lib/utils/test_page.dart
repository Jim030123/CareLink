// import 'dart:async';
// import 'dart:convert';

// import 'package:carelink_mobile/utils/signal_service.dart';
// import 'package:carelink_mobile/screens/cg_emergency_call.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:uuid/uuid.dart';

// class TestPage extends StatefulWidget {
//   final String caregiverId;
//   final String signalingUrl;

//   const TestPage({
//     super.key,
//     required this.caregiverId,
//     required this.signalingUrl,
//   });

//   @override
//   State<TestPage> createState() => _TestPageState();
// }

// class _TestPageState extends State<TestPage> {
//   late SignalingService signaling;
//   RTCPeerConnection? pc;
//   MediaStream? localStream;
//   final _localRenderer = RTCVideoRenderer();
//   final _remoteRenderer = RTCVideoRenderer();
//   bool _permissionsGranted = false;

//   String? currentCallId;
//   // Completer to wait for server ack when starting a call
//   Completer<String?>? _startCallAckCompleter;
//   bool isCalling = false;
//   bool inCall = false;
//   bool isMuted = false;

//   @override
//   void initState() {
//     super.initState();

//     // Initialize video renderers asynchronously
//     initRenderers();

//     // ✅ 正确做法：在 constructor 传入回调
//     signaling = SignalingService(onMessage: handleSignalMessage);

//     // ✅ connect 也要传 role（"cr"）
//     // Use a unique clientId for this Care Recipient instance instead of
//     // accidentally re-using the caregiverId (which would cause both sides to
//     // register the same clientId and prevent routing).
//     final myClientId = 'CR-${const Uuid().v4()}';
//     print('TestPage: using clientId=$myClientId to join signaling');
//     signaling.connect(widget.signalingUrl, myClientId, "cr");
//     // Request permissions on startup (non-blocking init)
//     Future.microtask(() => _ensurePermissionsOnStart());
//   }

//   Future<void> initRenderers() async {
//     try {
//       await _localRenderer.initialize();
//       await _remoteRenderer.initialize();
//     } catch (e) {
//       print('initRenderers error: $e');
//     }
//   }

//   // Ensure camera & microphone permission on startup; if denied, prompt user
//   Future<void> _ensurePermissionsOnStart() async {
//     final ok = await _requestCameraAndMicPermission();
//     if (ok) {
//       setState(() { _permissionsGranted = true; });
//       return;
//     }

//     // show dialog to ask user to grant permission or open settings
//     if (!mounted) return;
//     final retry = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Permissions required'),
//         content: const Text('Camera and microphone permissions are required for video calling.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(true),
//             child: const Text('Retry'),
//           ),
//           TextButton(
//             onPressed: () {
//               openAppSettings();
//               Navigator.of(ctx).pop(false);
//             },
//             child: const Text('Open Settings'),
//           ),
//         ],
//       ),
//     );

//     if (retry == true) {
//       await _ensurePermissionsOnStart();
//     } else {
//       // leave permissionsGranted false; UI will disable call
//     }
//   }

//   // ───────────────────────────────────────────
//   // Step 1: CR 按按钮 → 创建 Offer & 发起呼叫
//   // ───────────────────────────────────────────
//   Future<void> startCall() async {
//     // Ensure signaling attempted connection / join before sending
//     await signaling.ready;
//     // 创建 PeerConnection
//     pc = await createPeerConnection({
//       'iceServers': [
//         {'urls': 'stun:stun.l.google.com:19302'},
//       ]
//     });
//     // Request permissions and capture microphone + camera
//     final ok = await _requestCameraAndMicPermission();
//     if (!ok) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera and microphone permission required')));
//       }
//       return;
//     }

//     try {
//       localStream = await navigator.mediaDevices.getUserMedia({
//         'audio': true,
//         'video': true,
//       });
//       // attach to local preview
//       _localRenderer.srcObject = localStream;
//       print('CR: acquired localStream id=${localStream?.id}');
//       // Debug: log local audio tracks
//       try {
//         final audioTracks = localStream!.getAudioTracks();
//         print('CR: got localStream id=${localStream!.id}, audioTracks=${audioTracks.length}');
//         for (var t in audioTracks) {
//           print('CR: local audio track id=${t.id}, kind=${t.kind}, enabled=${t.enabled}');
//         }
//       } catch (e) {
//         print('CR: error enumerating local tracks: $e');
//       }
//       // 旧 API: addStream, 新版建议 addTrack；这里用 addTrack 更稳
//       for (var t in localStream!.getTracks()) {
//         pc!.addTrack(t, localStream!);
//         print('CR: added local track id=${t.id}, kind=${t.kind}');
//       }
//     } catch (e) {
//       print('getUserMedia error: $e');
//       return;
//     }

//     // 监听 ICE candidate
//     pc!.onIceCandidate = (RTCIceCandidate? candidate) {
//       if (candidate != null && currentCallId != null) {
//         signaling.send({
//           "type": "candidate",
//           "callId": currentCallId,
//           // Include explicit recipient to help signaling server routing
//           "to": widget.caregiverId,
//           "candidate": {
//             "candidate": candidate.candidate,
//             "sdpMid": candidate.sdpMid,
//             "sdpMLineIndex": candidate.sdpMLineIndex,
//           }
//         });
//       }
//     };

//     // Handle remote tracks (video/audio)
//     pc!.onTrack = (RTCTrackEvent event) {
//       print('CR: onTrack fired streams=${event.streams.length}');
//       if (event.streams.isNotEmpty) {
//         final s = event.streams[0];
//         try {
//           print('CR: remote stream id=${s.id}, tracks=${s.getTracks().length}');
//         } catch (e) {}
//         _remoteRenderer.srcObject = s;
//       }
//     };
//     // compatibility
//     pc!.onAddStream = (MediaStream s) {
//       print('CR: onAddStream: ${s.id}');
//       _remoteRenderer.srcObject = s;
//     };

//     // Debug: connection/signaling state
//     try {
//       pc!.onConnectionState = (RTCPeerConnectionState state) {
//         print('CR: pc connection state -> $state');
//       };
//       pc!.onSignalingState = (RTCSignalingState state) {
//         print('CR: pc signaling state -> $state');
//       };
//     } catch (e) {
//       // ignore if older flutter_webrtc version doesn't support these callbacks
//     }

//     // 创建 offer
//     final offer = await pc!.createOffer();
//     await pc!.setLocalDescription(offer);

//     // 建立 callId
//     final callId = const Uuid().v4();

//     // prepare a completer and send start_call; we'll wait for start_call_ack
//     _startCallAckCompleter = Completer<String?>();

//     signaling.send({
//       "type": "start_call",
//       "to": widget.caregiverId,
//       "callId": callId,
//       "offer": {
//         "sdp": offer.sdp,
//         "type": offer.type,
//       }
//     });

//     print("📞 CR → 发起呼叫 (sent), awaiting ack, callId(local) = $callId");

//     // update UI to show calling state
//     if (mounted) setState(() { isCalling = true; });

//     // wait up to 5s for server ack that it forwarded the incoming_call
//     try {
//       final ackCallId = await _startCallAckCompleter!.future.timeout(const Duration(seconds: 5));
//       if (ackCallId != null) {
//         currentCallId = ackCallId;
//         print('start_call acknowledged by server, callId=$currentCallId');
//       } else {
//         print('start_call ack received but no callId');
//       }
//     } catch (e) {
//       print('No start_call_ack received within timeout: $e');
//       // leave currentCallId as null to prevent candidate sends
//       currentCallId = null;
//       if (mounted) {
//         setState(() { isCalling = false; });
//       }
//     } finally {
//       _startCallAckCompleter = null;
//     }
//   }

//   // ───────────────────────────────────────────
//   // Step 2: 处理从服务器收到的信令消息
//   // ───────────────────────────────────────────
//   void handleSignalMessage(Map<String, dynamic> msg) async {
//     final type = msg['type'];

//     // Caregiver 已接听 → 收到 answer
//     if (type == "answer") {
//       print("📲 收到 caregiver answer");

//       final answer = RTCSessionDescription(
//         msg['answer']['sdp'] as String,
//         msg['answer']['type'] as String,
//       );
//       try {
//         await pc?.setRemoteDescription(answer);
//         print("🔗 通话建立完成");
//         if (mounted) {
//           setState(() {
//             inCall = true;
//             isCalling = false;
//           });
//         }
//       } catch (e) {
//         print('setRemoteDescription error: $e');
//       }
//       return;
//     }

//     // 收到 candidate
//     if (type == "candidate") {
//       print("📡 收到 candidate");

//       final c = msg['candidate'];
//       if (c != null) {
//         final candidate = RTCIceCandidate(
//           c['candidate'] as String?,
//           c['sdpMid'] as String?,
//           c['sdpMLineIndex'] as int?,
//         );
//         try {
//           await pc?.addCandidate(candidate);
//         } catch (e) {
//           // some flutter_webrtc versions use addCandidate, others use addIceCandidate;
//           // if addCandidate is not available, try addIceCandidate (but do not define an extension)
//           print('addCandidate error: $e');
//         }
//       }
//       return;
//     }

//     // server-side error notifications
//     if (type == 'error') {
//       final err = msg['message'];
//       print('Signaling error from server: $err');
//       // If we were awaiting start_call_ack, notify the waiter
//       if (_startCallAckCompleter != null) {
//         try {
//           _startCallAckCompleter?.complete(null);
//         } catch (e) {}
//       }
//       // Optionally show UI message
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Signaling error: $err')));
//       }
//       return;
//     }

//     if (type == "reject_call") {
//       print("❌ Caregiver 拒接");
//       // 可以提示 UI
//       endCall();
//       if (mounted) setState(() { isCalling = false; inCall = false; currentCallId = null; });
//       return;
//     }

//     if (type == "end_call") {
//       print("🛑 通话结束");
//       endCall();
//       if (mounted) setState(() { isCalling = false; inCall = false; currentCallId = null; });
//       return;
//     }

//     // 处理其他类型如 incoming_call (如果 CR 也能收到自己的 start_call 回 ack)
//     if (type == 'start_call_ack') {
//       // server ack with callId
//       print('start_call ack: ${msg['callId']}');
//       try {
//         _startCallAckCompleter?.complete(msg['callId'] as String?);
//       } catch (e) {}
//     }
//   }

//   // ───────────────────────────────────────────
//   // Step 3: 挂断
//   // ───────────────────────────────────────────
//   Future<void> endCall() async {
//     if (currentCallId != null) {
//       final ok = signaling.send({
//         "type": "end_call",
//         "callId": currentCallId,
//       });
//       print('CR: sent end_call (callId=$currentCallId) sendReturned=$ok');
//       // Small delay to allow signaling message to be delivered before tearing down
//       await Future.delayed(const Duration(milliseconds: 250));
//     }

//     try {
//       print('CR: closing pc');
//       pc?.close();
//     } catch (_) {}
//     pc = null;

//     try {
//       if (localStream != null) {
//         print('CR: stopping localStream id=${localStream!.id}');
//         for (var t in localStream!.getTracks()) {
//           print('CR: stopping track id=${t.id}');
//           try { t.stop(); } catch (_) {}
//         }
//         try { localStream?.dispose(); } catch (_) {}
//       }
//     } catch (_) {}

//     currentCallId = null;
//     if (mounted) setState(() { isCalling = false; inCall = false; });
//   }

//   @override
//   void dispose() {
//     endCall();
//     try {
//       signaling.unregister();
//     } catch (e) {}
//     signaling.close();
//     try { _localRenderer.dispose(); } catch (_) {}
//     try { _remoteRenderer.dispose(); } catch (_) {}
//     super.dispose();
//   }

//   void _toggleMute() {
//     if (localStream == null) {
//       // nothing to mute; reflect UI state
//       setState(() {
//         isMuted = true;
//       });
//       return;
//     }
//     try {
//       for (var t in localStream!.getAudioTracks()) {
//         t.enabled = !t.enabled;
//       }
//       setState(() {
//         isMuted = localStream!.getAudioTracks().every((t) => !t.enabled);
//       });
//     } catch (e) {
//       print('CR: toggle mute error: $e');
//     }
//   }

//   Future<bool> _requestCameraAndMicPermission() async {
//     try {
//       final mic = await Permission.microphone.status;
//       if (!mic.isGranted) {
//         final r = await Permission.microphone.request();
//         if (!r.isGranted) return false;
//       }
//       final cam = await Permission.camera.status;
//       if (!cam.isGranted) {
//         final r2 = await Permission.camera.request();
//         if (!r2.isGranted) return false;
//       }
//       return true;
//     } catch (e) {
//       print('permission request error: $e');
//       return false;
//     }
//   }

//   // ───────────────────────────────────────────
//   // UI
//   // ───────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("CR Emergency Call")),
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (inCall) ...[
//               // show remote video if available
//               SizedBox(
//                 width: 320,
//                 height: 240,
//                 child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
//               ),
//               const SizedBox(height: 12),
//               Text('In call with ${widget.caregiverId}'),
//               const SizedBox(height: 12),
//               Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   ElevatedButton.icon(
//                     icon: const Icon(Icons.call_end),
//                     label: const Text('Hang up'),
//                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                     onPressed: endCall,
//                   ),
//                   const SizedBox(width: 12),
//                   ElevatedButton.icon(
//                     icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
//                     label: Text(isMuted ? 'Unmute' : 'Mute'),
//                     onPressed: _toggleMute,
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               // local preview
//               SizedBox(
//                 width: 120,
//                 height: 90,
//                 child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
//               ),
//             ] else if (isCalling) ...[
//               const Icon(Icons.call_made, size: 80, color: Colors.orange),
//               const SizedBox(height: 12),
//               Text('Calling ${widget.caregiverId}...'),
//               const SizedBox(height: 12),
//               SizedBox(
//                 width: 320,
//                 height: 240,
//                 child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
//               ),
//               const SizedBox(height: 12),
//               ElevatedButton(
//                 onPressed: () {
//                   // cancel the outgoing call
//                   endCall();
//                 },
//                 child: const Text('Cancel'),
//               ),
//             ] else ...[
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red,
//                   padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
//                 ),
//                 child: const Text('📞 Emergency Call', style: TextStyle(fontSize: 22)),
//                 onPressed: _permissionsGranted ? startCall : () => _ensurePermissionsOnStart(),


//               ),
//               if (!_permissionsGranted)
//                 const Padding(
//                   padding: EdgeInsets.only(top: 8.0),
//                   child: Text('Camera & microphone permissions required', style: TextStyle(color: Colors.red)),
//                 ),
//               const SizedBox(height: 12),
//               ElevatedButton(
//                 onPressed: endCall,
//                 child: const Text('End Call'),
//               ),
//               const SizedBox(height: 20),
//               Text('CallId: ${currentCallId ?? "none"}'),
//             ],

//             const SizedBox(height: 12),
//             // ElevatedButton(
//             //   child: const Text('Go to TestPage3', style: TextStyle(fontSize: 22)),
//             //   onPressed: () => Navigator.push(
//             //     context,
//             //     // MaterialPageRoute(
//             //     //   builder: (context) => CGEmergencyCall(
//             //     //     caregiverId: widget.caregiverId,
//             //     //     signalingUrl: widget.signalingUrl,
//             //     //   ),
//             //     // ),
//             //   ),
//             // ),
//           ],
//         ),
//       ),
//     );
//   }
// }
