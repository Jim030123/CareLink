import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

typedef ReadTimes = Future<List<Map<String, dynamic>>> Function();
typedef SaveTimes = Future<void> Function(List<Map<String, dynamic>>);

class AvailableTimeEditor extends StatelessWidget {
  final ReadTimes readTimes;
  final SaveTimes saveTimes;

  const AvailableTimeEditor({super.key, required this.readTimes, required this.saveTimes});

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  String _format(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool _isAllowed(TimeOfDay t) {
    final min = TimeOfDay(hour: 0, minute: 0);
    final max = TimeOfDay(hour: 23, minute: 59);
    final tm = _toMinutes(t);
    return tm >= _toMinutes(min) && tm <= _toMinutes(max);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: readTimes(),
      builder: (fctx, snap) {
        if (!snap.hasData) {
          return SizedBox(height: 200.h, child: Center(child: CircularProgressIndicator()));
        }
        final times = snap.data!;
        List<String?> errors = List<String?>.filled(times.length, null);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 0.h),
          child: StatefulBuilder(
            builder: (c, setStateLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 36.w, height: 4.h, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.r))),
                  ),
                  SizedBox(height: 12.h),
                  Text('Available Time', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                  SizedBox(height: 12.h),
                  ...List.generate(times.length, (i) {
                    final item = times[i];
                    final startParts = (item['start'] ?? '00:00').toString().split(':');
                    final endParts = (item['end'] ?? '00:00').toString().split(':');
                    final startTod = TimeOfDay(hour: int.tryParse(startParts[0]) ?? 0, minute: int.tryParse(startParts[1]) ?? 0);
                    final endTod = TimeOfDay(hour: int.tryParse(endParts[0]) ?? 0, minute: int.tryParse(endParts[1]) ?? 0);
                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Row(
                            children: [
                              Expanded(child: Text(item['day'] ?? 'Day', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500))),
                              if (item['enabled'] == true)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(context: context, initialTime: startTod);
                                        if (picked != null) {
                                          if (!_isAllowed(picked)) {
                                            setStateLocal(() => errors[i] = 'Time must be between 00:00 and 23:59');
                                          } else {
                                            setStateLocal(() {
                                              item['start'] = _format(picked);
                                              final currentEnd = _parseTime(item['end'] ?? '00:00');
                                              if (_toMinutes(_parseTime(item['start'] ?? '00:00')) < _toMinutes(currentEnd)) {
                                                errors[i] = null;
                                              }
                                            });
                                          }
                                        }
                                      },
                                      child: Text(TimeOfDay(hour: startTod.hour, minute: startTod.minute).format(context)),
                                    ),
                                    Text(' - '),
                                    TextButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(context: context, initialTime: endTod);
                                        if (picked != null) {
                                          if (!_isAllowed(picked)) {
                                            setStateLocal(() => errors[i] = 'Time must be between 00:00 and 23:59');
                                          } else {
                                            final currentStart = _parseTime(item['start'] ?? '00:00');
                                            if (_toMinutes(currentStart) >= _toMinutes(picked)) {
                                              setStateLocal(() => errors[i] = '${item['day']}: end must be after star');
                                            } else {
                                              setStateLocal(() {
                                                item['end'] = _format(picked);
                                                errors[i] = null;
                                              });
                                            }
                                          }
                                        }
                                      },
                                      child: Text(TimeOfDay(hour: endTod.hour, minute: endTod.minute).format(context)),
                                    ),
                                  ],
                                )
                              else
                                SizedBox.shrink(),
                              SizedBox(width: 8.w),
                              Switch(
                                value: item['enabled'] == true,
                                onChanged: (v) => setStateLocal(() {
                                  item['enabled'] = v;
                                  errors[i] = null;
                                  if (v == true) {
                                    final s = (item['start'] ?? '00:00').toString();
                                    final e = (item['end'] ?? '00:00').toString();
                                    final startMin = _toMinutes(_parseTime(s));
                                    final endMin = _toMinutes(_parseTime(e));
                                    if ((s == '00:00' && e == '00:00') || startMin >= endMin) {
                                      item['start'] = '09:00';
                                      item['end'] = '17:00';
                                    }
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                        if (errors[i] != null) ...[
                          Padding(
                            padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 8.h),
                            child: Text(errors[i]!, style: TextStyle(color: Colors.red, fontSize: 12.sp)),
                          ),
                        ],
                        Divider(height: 1.h),
                      ],
                    );
                  }),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close')),
                      SizedBox(width: 8.w),
                      ElevatedButton(
                        onPressed: (() {
                          for (var i = 0; i < times.length; i++) {
                            final item = times[i];
                            if (item['enabled'] == true) {
                              final start = _parseTime(item['start'] ?? '00:00');
                              final end = _parseTime(item['end'] ?? '00:00');
                              if (!_isAllowed(start) || !_isAllowed(end)) return null;
                              if (_toMinutes(start) >= _toMinutes(end)) return null;
                            }
                          }
                          return () async {
                            var hasError = false;
                            for (var i = 0; i < times.length; i++) {
                              final item = times[i];
                              errors[i] = null;
                              if (item['enabled'] == true) {
                                final start = _parseTime(item['start'] ?? '00:00');
                                final end = _parseTime(item['end'] ?? '00:00');
                                if (!_isAllowed(start) || !_isAllowed(end)) {
                                  errors[i] = 'Times must be within 00:00-23:59';
                                  hasError = true;
                                  continue;
                                }
                                if (_toMinutes(start) >= _toMinutes(end)) {
                                  errors[i] = 'End time must be after start time';
                                  hasError = true;
                                }
                              }
                            }
                            setStateLocal(() {});
                            if (hasError) return;
                            await saveTimes(times);
                            if (Navigator.of(context).mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Available times saved')));
                            }
                            Navigator.of(context).pop();
                          };
                        })(),
                        child: Text('Save'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
