import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:carelink_mobile/utils/emergency_calling.dart';

/// Caregiver incoming-call screen wired to `EmergencyCalling` helper.
class CrEmergencyCall extends StatefulWidget {
  /// Signaling URL and client id can be overridden for testing.
  final String signalingUrl;
  final String clientId;
  /// Role: 'caregiver' (incoming) or 'cr' (outgoing caller)
  final String role;
  /// When acting as caller (role == 'cr'), the target caregiver client id to call.
  final String? targetClientId;

  CrEmergencyCall({super.key, this.signalingUrl = 'wss://localhost/ws', String? clientId, this.role = 'caregiver', this.targetClientId}) :
    clientId = clientId ?? (role == 'caregiver' ? 'caregiver-' + '${DateTime.now().millisecondsSinceEpoch}' : 'cr-' + '${DateTime.now().millisecondsSinceEpoch}');

  @override
  State<CrEmergencyCall> createState() => _CrEmergencyCallState();
}

class _CrEmergencyCallState extends State<CrEmergencyCall> {
  EmergencyCalling? _ec;
  late RTCVideoRenderer _remoteRenderer;
  late RTCVideoRenderer _localRenderer;

  bool inCall = false;
  bool isRinging = false;
  bool isMuted = false;
  String? incomingFrom;
  bool isDialing = false;

  Map<String, dynamic>? _lastIncomingMsg;

  @override
  void initState() {
    super.initState();
    _remoteRenderer = RTCVideoRenderer();
    _localRenderer = RTCVideoRenderer();
    _initRenderers();
    _initEmergencyCalling();
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();
  }

  Future<void> _initEmergencyCalling() async {
    try {
      final ec = await EmergencyCalling.create(widget.signalingUrl, widget.clientId, widget.role);
      _ec = ec;

      // remote stream -> renderer
      ec.onRemoteStream = (stream) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      };

      // local stream -> renderer
      ec.onLocalStream = (stream) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      };

      // incoming call
      ec.onIncomingCall = (msg) {
        setState(() {
          isRinging = true;
          incomingFrom = msg['from'] as String?;
          _lastIncomingMsg = msg;
        });
      };

      // If this widget is used by the care recipient to make an outgoing call,
      // start the call to the provided target client id.
      if (widget.role == 'cr' && widget.targetClientId != null) {
        try {
          setState(() {
            isRinging = false;
            inCall = false;
            isMuted = ec.isMuted;
            isDialing = true;
          });
          await ec.startCall(widget.targetClientId!);
          // startCall returns once request sent — call state updates come via onCallState
        } catch (e) {
          // ignore start errors; state updates will show failures via onCallState
          setState(() {
            isDialing = false;
          });
        }
      }

      // call state updates (used for both incoming and outgoing flows)
      ec.onCallState = (s) {
        setState(() {
          if (s == 'calling') {
            isDialing = true;
            inCall = false;
            isRinging = false;
          } else if (s == 'in_call') {
            inCall = true;
            isDialing = false;
            isRinging = false;
          } else if (s == 'ringing') {
            isRinging = true;
            isDialing = false;
          } else if (s == 'hung_up' || s == 'ended' || s == 'rejected' || s == 'call_start_failed' || s == 'call_start_timeout') {
            inCall = false;
            isRinging = false;
            isDialing = false;
            _cleanupRenderers();
          }
          isMuted = ec.isMuted;
        });
      };
    } catch (e) {
      // ignore connection errors — UI will show waiting state
    }
  }

  Widget _incomingCallWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Incoming call from ${incomingFrom ?? 'CR'}', style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.call),
              label: const Text('Accept'),
              onPressed: _acceptCall,
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.call_end),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _rejectCall,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _acceptCall() async {
    if (_ec == null || _lastIncomingMsg == null) return;
    final callId = _lastIncomingMsg!['callId'] as String?;
    final offer = _lastIncomingMsg!['offer'] as Map<String, dynamic>?;
    if (callId != null && offer != null) {
      await _ec!.acceptCall(callId, offer);
      setState(() {
        isRinging = false;
        inCall = true;
        incomingFrom = _lastIncomingMsg?['from'] as String?;
      });
    }
  }

  void _rejectCall() {
    if (_ec == null || _lastIncomingMsg == null) return;
    try {
      _ec!.signaling.send({'type': 'reject_call', 'from': _ec!.clientId, 'callId': _lastIncomingMsg!['callId']});
    } catch (_) {}
    setState(() {
      isRinging = false;
      _lastIncomingMsg = null;
    });
  }

  Future<void> hangup() async {
    try {
      await _ec?.hangup();
    } catch (_) {}
    setState(() {
      inCall = false;
      isRinging = false;
      _cleanupRenderers();
    });
  }

  void _cleanupRenderers() {
    try {
      _remoteRenderer.srcObject = null;
    } catch (_) {}
    try {
      _localRenderer.srcObject = null;
    } catch (_) {}
  }

  void _toggleMute() {
    if (_ec == null) return;
    final newMuted = _ec!.toggleMute();
    setState(() {
      isMuted = newMuted;
    });
  }

  void _simulateIncomingCall() {
    if (_ec == null) return;
    final msg = {
      'type': 'incoming_call',
      'from': 'CR-debug',
      'callId': 'sim-${DateTime.now().millisecondsSinceEpoch}',
      'offer': {'sdp': '', 'type': 'offer'}
    };
    _ec!.incomingCallController.add(msg);
  }

  Widget _inCallWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 320,
          height: 240,
          child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
        ),
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
        const SizedBox(height: 12),
        SizedBox(
          width: 120,
          height: 90,
          child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
        ),
      ],
    );
  }

  Widget _dialingWidget() {
    final label = widget.role == 'cr' ? (widget.targetClientId ?? 'Caregiver') : (incomingFrom ?? 'Other');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 320,
          height: 180,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text('Calling $label...', style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
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
        const SizedBox(height: 12),
        SizedBox(
          width: 120,
          height: 90,
          child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
        ),
      ],
    );
  }

  @override
  void dispose() {
    try { _ec?.dispose(); } catch (_) {}
    try { _remoteRenderer.dispose(); } catch (_) {}
    try { _localRenderer.dispose(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.role == 'cr' ? 'Care Recipient - Call Portal' : 'Caregiver - Incoming Calls';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: Center(
                child: inCall
                  ? _inCallWidget()
                  : isDialing
                    ? _dialingWidget()
                    : isRinging
                        ? _incomingCallWidget()
                          : (widget.role == 'cr' ? const Text('Preparing call...', style: TextStyle(fontSize: 18)) : const Text('Waiting for calls...', style: TextStyle(fontSize: 18))),
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

}