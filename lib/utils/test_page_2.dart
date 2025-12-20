import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class TestPage2 extends StatefulWidget {
  const TestPage2({super.key});

  @override
  State<TestPage2> createState() => _TestPage2State();
}

class _TestPage2State extends State<TestPage2> {
  VideoPlayerController? _controller;
  final TextEditingController _urlController = TextEditingController(
    text: 'http://10.150.123.100:8888/cam1/index.m3u8',
  );
  bool _ready = false;

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
    try {
      final uri = Uri.parse(url);
      // dispose previous controller if any
      await _controller?.dispose();
      _controller = VideoPlayerController.networkUrl(uri)..setLooping(true);
      await _controller!.initialize();
      if (!mounted) return;
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

  @override
  void dispose() {
    _controller?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CCTV Live')),
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
            Container(
              height: 500,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
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
                child: _ready && _controller != null
                    ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
