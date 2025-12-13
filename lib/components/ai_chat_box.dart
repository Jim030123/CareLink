import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final String text;
  final ChatRole role;
  final DateTime time;

  ChatMessage({required this.text, required this.role}) : time = DateTime.now();
}

class AIChatBox extends StatefulWidget {
  /// Optional callback to handle sending the user's message to a remote
  /// API. If not provided, the chat will use a simple local mock responder.
  final Future<String> Function(String prompt)? onSend;

  const AIChatBox({super.key, this.onSend});

  @override
  State<AIChatBox> createState() => _AIChatBoxState();
}

class _AIChatBoxState extends State<AIChatBox> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() {
      _messages.add(ChatMessage(text: text, role: ChatRole.user));
      _isSending = true;
      _ctrl.clear();
    });
    _scrollToBottom();

    try {
      String reply;
      if (widget.onSend != null) {
        reply = await widget.onSend!(text);
      } else {
        reply = await _mockReply(text);
      }

      setState(() {
        _messages.add(ChatMessage(text: reply, role: ChatRole.assistant));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(text: 'Error: ${e.toString()}', role: ChatRole.assistant),
        );
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<String> _mockReply(String prompt) async {
    // Very small heuristic-based mock to feel like an assistant.
    await Future.delayed(const Duration(milliseconds: 800));
    final lower = prompt.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi')) {
      return 'Hello! How can I help you today?';
    }
    if (lower.contains('help') || lower.contains('how')) {
      return 'I can help with medication reminders, appointments, and caregiver management. What would you like to do?';
    }
    if (lower.contains('appointment')) {
      return 'You have an appointment on 2025-12-02 at 10:00 AM with Dr. Tan. Would you like to add a reminder?';
    }
    // Fallback: short echo-style reply
    return 'Got it — you said: "$prompt". (This is a local mock assistant.)';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Let parent control available space; avoid fixed-height constraints
    // which can cause overflow when the keyboard appears.
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5B21B6), Color(0xFF9B51E0)],
                    ),
                  ),
                  child: Center(child: Icon(Icons.smart_toy, color: Colors.white)),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'AI Assistant',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _messages.clear());
                  },
                  icon: Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),

          // Messages: make the message list flexible and avoid overflow by
          // using Expanded (when parent allows) and proper padding for
          // keyboard insets. We keep the ListView.builder which handles
          // scrolling internally.
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: ListView.builder(
                controller: _scroll,
                // Don't include the keyboard inset here — the input area
                // already accounts for `viewInsets.bottom`. Keeping only a
                // small internal padding prevents double-counting which can
                // cause tiny overflow values.
                padding: EdgeInsets.only(bottom: 12.h),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _messages.length) {
                    // typing indicator
                    return _TypingIndicator();
                  }
                  final m = _messages[i];
                  return Align(
                    alignment: m.role == ChatRole.user
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 6.h),
                      padding: EdgeInsets.symmetric(
                        vertical: 10.h,
                        horizontal: 12.w,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: m.role == ChatRole.user
                            ? Colors.blue.shade600
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        m.text,
                        style: TextStyle(
                          color: m.role == ChatRole.user
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Input: add bottom padding that matches keyboard inset to avoid
          // being overlapped when the keyboard opens.
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Ask me anything...',
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8.h,
                          horizontal: 12.w,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _isSending
                      ? Padding(
                          padding: EdgeInsets.only(right: 4.w),
                          child: SizedBox(
                            width: 36.w,
                            height: 36.w,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: _send,
                          icon: Icon(Icons.send, color: Colors.blue.shade700),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6.h),
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 6.w,
              height: 6.w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 6.w),
            SizedBox(
              width: 6.w,
              height: 6.w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 6.w),
            SizedBox(
              width: 6.w,
              height: 6.w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
