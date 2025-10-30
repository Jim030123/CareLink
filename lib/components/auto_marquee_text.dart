import 'dart:async';
import 'package:flutter/material.dart';

class AutoMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration scrollDuration;
  final Duration pauseDuration;
  final double gap;

  const AutoMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.scrollDuration = const Duration(seconds: 3),
    this.pauseDuration = const Duration(seconds: 1),
    this.gap = 24.0,
  });

  @override
  State<AutoMarqueeText> createState() => _AutoMarqueeTextState();
}

class _AutoMarqueeTextState extends State<AutoMarqueeText> {
  final ScrollController _scrollController = ScrollController();
  double _textWidth = 0;
  double _boxWidth = 0;
  bool _isOverflow = false;
  bool _scrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureScrollLoop() async {
    if (_scrolling) return;
    _scrolling = true;
    try {
      while (mounted && _isOverflow) {
        await Future.delayed(widget.pauseDuration);
        // wait until controller attached
        if (!_scrollController.hasClients) {
          await WidgetsBinding.instance.endOfFrame;
          if (!_scrollController.hasClients) {
            // give a short delay and retry
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
        if (!_scrollController.hasClients) continue;

        final maxExtent = _scrollController.position.maxScrollExtent;
        final target = maxExtent > 0 ? maxExtent : (_textWidth - _boxWidth).clamp(0.0, double.infinity);

        if (target > 0) {
          await _scrollController.animateTo(
            target,
            duration: widget.scrollDuration,
            curve: Curves.linear,
          );
          await Future.delayed(widget.pauseDuration);
          if (!_scrollController.hasClients) break;
          await _scrollController.animateTo(
            0,
            duration: widget.scrollDuration,
            curve: Curves.linear,
          );
        } else {
          // nothing to scroll
          break;
        }
      }
    } finally {
      _scrolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.maybeOf(context)?.textScaleFactor ?? 1.0;
        // measure text width based on available constraints
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          textDirection: TextDirection.ltr,
          textScaleFactor: textScale,
          maxLines: 1,
        )..layout(maxWidth: double.infinity);

        _textWidth = tp.width;
        _boxWidth = constraints.maxWidth;
        final willOverflow = _textWidth > _boxWidth;

        // if overflow state changed, update and start loop
        if (willOverflow != _isOverflow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _isOverflow = willOverflow);
            if (_isOverflow) _ensureScrollLoop();
          });
        } else if (willOverflow && !_scrolling) {
          // ensure loop started after frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureScrollLoop();
          });
        }

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: _isOverflow ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
              ),
              // add small spacer so end isn't cut off when scrolling to max
              SizedBox(width: widget.gap),
            ],
          ),
        );
      },
    );
  }
}