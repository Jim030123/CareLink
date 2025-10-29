import 'package:flutter/material.dart';


class AutoMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration scrollDuration;
  final Duration pauseDuration;

  const AutoMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.scrollDuration = const Duration(seconds: 3),
    this.pauseDuration = const Duration(seconds: 1),
  });

  @override
  State<AutoMarqueeText> createState() => _AutoMarqueeTextState();
}

class _AutoMarqueeTextState extends State<AutoMarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isOverflow = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: context.size!.width);

    setState(() {
      _isOverflow = textPainter.didExceedMaxLines;
    });

    if (_isOverflow) _startScrolling();
  }

  void _startScrolling() async {
    while (mounted && _isOverflow) {
      await Future.delayed(widget.pauseDuration);
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: widget.scrollDuration,
        curve: Curves.linear,
      );
      await Future.delayed(widget.pauseDuration);
      await _scrollController.animateTo(
        0,
        duration: widget.scrollDuration,
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: _isOverflow ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        );
      },
    );
  }
}
