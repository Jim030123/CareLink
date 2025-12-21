import 'package:carelink_mobile/components/page_appbar.dart';
import 'dart:async';

import 'package:carelink_mobile/components/page_appbar.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

class RemoteMonitor extends StatefulWidget {
  const RemoteMonitor({super.key});

  @override
  State<RemoteMonitor> createState() => _RemoteMonitorState();
}

class _RemoteMonitorState extends State<RemoteMonitor> {
  VideoPlayerController? _controller;
  final TextEditingController _urlController = TextEditingController(
    text: 'http://10.150.123.100:8888/cam1/index.m3u8',
  );
  bool _ready = false;
  final List<String> _sources = ['Source 1', 'Source 2', 'Source 3'];
  final List<String> _sourceUrls = [
    'http://10.150.123.100:8888/cam1/index.m3u8',
    'http://10.150.123.100:8888/cam2/index.m3u8',
    'http://10.150.123.100:8888/cam3/index.m3u8',
  ];
  int _selectedSourceIndex = 0;
  Timer? _noContentTimer;
  bool _noContent = false;
  Timer? _timeoutTimer;
  bool _timeout = false;

  @override
  void initState() {
    super.initState();

    // Initialize using URL from the text field (allows user edits)
    _loadUrl(_urlController.text);
  }

  Future<void> _loadUrl(String url) async {
    setState(() {
      _ready = false;
    });
    // cancel previous timers and reset flags
    _noContentTimer?.cancel();
    _timeoutTimer?.cancel();
    _noContent = false;
    _timeout = false;
    // start a 5s timeout for connection failures
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      // if not initialized yet, show timeout
      if (_controller == null || !_controller!.value.isInitialized) {
        setState(() {
          _timeout = true;
          _ready = true; // stop spinner and show message
        });
      }
    });
    try {
      final uri = Uri.parse(url);
      // dispose previous controller if any
      // remove listener before disposing
      try {
        _controller?.removeListener(_videoListener);
      } catch (_) {}
      await _controller?.dispose();
      _controller = VideoPlayerController.networkUrl(uri)..setLooping(true);
      await _controller!.initialize();
      // Listen for playback progress to cancel no-content or timeout state
      _controller!.addListener(_videoListener);
      // start a 10s timer; if no playback progress by then, show message
      _noContentTimer = Timer(const Duration(seconds: 10), () {
        if (!mounted) return;
        // If not initialized or not progressed, mark as no content
        final hasProgress = _controller != null && _controller!.value.isInitialized && (_controller!.value.position > Duration.zero || _controller!.value.isPlaying);
        if (!hasProgress) {
          setState(() {
            _noContent = true;
            _ready = true; // stop spinner
          });
        }
      });
      if (!mounted) return;
      // controller initialized: cancel connection timeout
      _timeoutTimer?.cancel();
      setState(() => _ready = true);
      _controller!.play();
    } catch (e) {
      // keep ready false and show error
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e')));
      }
      setState(() => _ready = false);
    }
  }

  void _videoListener() {
    try {
      if (_controller == null) return;
      final v = _controller!.value;
      final progressed = v.isInitialized && (v.position > Duration.zero || v.isPlaying);
      if (progressed && _noContent) {
        // content arrived after timeout
        _noContentTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _noContent = false;
        });
      }
      // If content progresses before timer, cancel timer
      if (progressed) {
        _noContentTimer?.cancel();
        _timeoutTimer?.cancel();
        if (_timeout) {
          if (!mounted) return;
          setState(() {
            _timeout = false;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _noContentTimer?.cancel();
    _timeoutTimer?.cancel();
    try {
      _controller?.removeListener(_videoListener);
    } catch (_) {}
    _controller?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: 'Remote Monitor',
        showBack: true,
        showSearch: false,
        onSearch: () {
          setState(() {});
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Stream URL',
                      hintText: 'http://<host>:<port>/path/index.m3u8',
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => _loadUrl(_urlController.text),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _loadUrl(_urlController.text),
                  child: const Text('Load'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                Text(
                  'Remote ${_sources[_selectedSourceIndex]}',
                  style: TextStyle(
                    fontSize: 25.sp,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 10.0,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),

                Container(
                  height: 220.h,
                  decoration: BoxDecoration(
                    gradient:  LinearGradient(
                      colors: [Color(0xFFFFF4EE), Color(0xFFFFE0CC)],
                    ),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.25),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.25),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _timeout
                      ? Text('Timeout connection', style: TextStyle(fontSize: 16.sp, color: Colors.red))
                      : (_ready && _controller != null
                        ? (_noContent
                          ? Text('No remote source available', style: TextStyle(fontSize: 16.sp, color: Colors.grey))
                          : AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                            ))
                        : Lottie.asset(
                            'assets/animations/video_loading.json',
                            width: 80.w,
                            height: 80.h,
                            fit: BoxFit.contain,
                            repeat: true
                          )),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            // selectable single-choice chips for sources
            Wrap(
              spacing: 8.w,
              children: List<Widget>.generate(_sources.length, (i) {
                return ChoiceChip(
                  label: Text(_sources[i], style: TextStyle(fontSize: 14.sp)),
                  selected: _selectedSourceIndex == i,
                  onSelected: (selected) {
                    if (!selected) return;
                    setState(() {
                      _selectedSourceIndex = i;
                      // update URL field and load the selected stream
                      _urlController.text = _sourceUrls[i];
                    });
                    _loadUrl(_sourceUrls[i]);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
