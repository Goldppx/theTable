import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'cas_protocol.dart';

/// UEM SliderCaptcha: 280×155 canvas, 40px handle, real a/b/c touch tracks.
class CampusSliderCaptcha extends StatefulWidget {
  const CampusSliderCaptcha({required this.challenge, required this.disabled, required this.onComplete, super.key});
  final SliderChallenge challenge;
  final bool disabled;
  final ValueChanged<Map<String, dynamic>> onComplete;
  @override
  State<CampusSliderCaptcha> createState() => _CampusSliderCaptchaState();
}
class _CampusSliderCaptchaState extends State<CampusSliderCaptcha> {
  double _distance = 0;
  Offset? _start;
  final _clock = Stopwatch();
  final List<Map<String, int>> _tracks = [];
  @override
  void didUpdateWidget(CampusSliderCaptcha oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challenge != widget.challenge) { _distance = 0; _start = null; _tracks.clear(); }
  }
  void _record(Offset point) {
    if (_start == null) return;
    _distance = (point.dx - _start!.dx).clamp(0.0, 240.0);
    final sample = {'a': _distance.round(), 'b': (point.dy - _start!.dy).round(), 'c': _clock.elapsedMilliseconds};
    final previous = _tracks.last;
    final dx = sample['a']! - previous['a']!;
    final dy = sample['b']! - previous['b']!;
    if (sample['c']! - previous['c']! >= 20 && sqrt(dx * dx + dy * dy) >= 2) _tracks.add(sample);
  }
  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final width = challenge.tagWidth > 0 ? (challenge.tagWidth / 590 * 280 - 2).clamp(1.0, 280.0) : 44.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 280, height: 155, child: Stack(children: [
        Positioned.fill(child: Image.memory(base64Decode(challenge.bigImage), fit: BoxFit.fill, gaplessPlayback: true)),
        Positioned(left: _distance, top: 0, width: width, height: 155,
          child: Image.memory(base64Decode(challenge.smallImage), fit: BoxFit.fill, gaplessPlayback: true)),
      ]))),
      const SizedBox(height: 12),
      SizedBox(width: 280, height: 44, child: Stack(children: [
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)), child: const Center(child: Text('向右拖动，将拼图对齐')))),
        Positioned(left: _distance, top: 2, width: 40, height: 40,
          child: Semantics(label: '拖动拼图滑块', child: GestureDetector(
            onPanStart: widget.disabled ? null : (details) {
              _start = details.globalPosition;
              _clock..reset()..start();
              _tracks..clear()..add({'a': 0, 'b': 0, 'c': 0});
              setState(() => _distance = 0);
            },
            onPanUpdate: widget.disabled ? null : (details) => setState(() => _record(details.globalPosition)),
            onPanCancel: () { _start = null; setState(() => _distance = 0); },
            onPanEnd: widget.disabled ? null : (_) {
              if (_start == null) return;
              _tracks.add({'a': _distance.round(), 'b': _tracks.last['b']!, 'c': _clock.elapsedMilliseconds});
              _clock.stop(); _start = null;
              widget.onComplete({'canvasLength': 280, 'moveLength': _distance.round(), 'tracks': List<Map<String, int>>.from(_tracks)});
            },
            child: DecoratedBox(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
              child: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onPrimary)),
          ))),
      ])),
    ]);
  }
}
