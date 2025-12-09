import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebRTCCallPage extends StatefulWidget {
  const WebRTCCallPage({super.key});

  @override
  State<WebRTCCallPage> createState() => _WebRTCCallPageState();
}

class _WebRTCCallPageState extends State<WebRTCCallPage> {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  WebSocketChannel? _channel;

  bool _isCaller = false;
  bool _inCall = false;

  @override
  void initState() {
    super.initState();
    _connectSignaling();
  }

  @override
  void dispose() {
    _localStream?.dispose();
    _pc?.close();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _connectSignaling() async {
    // TODO: 把这里改成你服务器的 IP/域名
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://YOUR_SERVER_IP:8080'),
    );

    _channel!.stream.listen((message) async {
      final data = jsonDecode(message);
      final type = data['type'];

      if (type == 'offer') {
        await _onRemoteOffer(data['sdp']);
      } else if (type == 'answer') {
        await _onRemoteAnswer(data['sdp']);
      } else if (type == 'candidate') {
        await _onRemoteCandidate(data['candidate']);
      }
    });
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {
          'urls': ['stun:stun.l.google.com:19302'],
        }
      ]
    };

    final pc = await createPeerConnection(config);

    // 获取本地音频流（麦克风）
    _localStream ??= await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    for (var track in _localStream!.getTracks()) {
      pc.addTrack(track, _localStream!);
    }

    // ICE 回调：发现 candidate 就发给对方
    pc.onIceCandidate = (candidate) {
      if (candidate == null) return;
      _sendSignal({
        'type': 'candidate',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    // 远端流（这里只是为了触发音频播放，不显示视频）
    pc.onTrack = (event) {
      // 对于 audio only，只要 track 存在，音频就会通过系统播放
      debugPrint('Remote track added: ${event.track.kind}');
    };

    return pc;
  }

  void _sendSignal(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  Future<void> _startCall() async {
    _isCaller = true;
    _pc ??= await _createPeerConnection();

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    _sendSignal({
      'type': 'offer',
      'sdp': offer.sdp,
    });

    setState(() {
      _inCall = true;
    });
  }

  Future<void> _onRemoteOffer(String sdp) async {
    _isCaller = false;
    _pc ??= await _createPeerConnection();

    final desc = RTCSessionDescription(sdp, 'offer');
    await _pc!.setRemoteDescription(desc);

    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    _sendSignal({
      'type': 'answer',
      'sdp': answer.sdp,
    });

    setState(() {
      _inCall = true;
    });
  }

  Future<void> _onRemoteAnswer(String sdp) async {
    if (_pc == null) return;
    final desc = RTCSessionDescription(sdp, 'answer');
    await _pc!.setRemoteDescription(desc);
  }

  Future<void> _onRemoteCandidate(Map<String, dynamic> data) async {
    if (_pc == null) return;

    final candidate = RTCIceCandidate(
      data['candidate'],
      data['sdpMid'],
      data['sdpMLineIndex'],
    );
    await _pc!.addCandidate(candidate);
  }

  Future<void> _hangup() async {
    await _pc?.close();
    _pc = null;
    _localStream?.dispose();
    _localStream = null;

    setState(() {
      _inCall = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC Voice Call Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_inCall ? 'In Call' : 'Not in Call'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _inCall ? null : _startCall,
              child: const Text('Call'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _inCall ? _hangup : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Hang Up'),
            ),
          ],
        ),
      ),
    );
  }
}
