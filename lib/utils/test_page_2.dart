import 'package:flutter/material.dart';
import 'package:carelink_mobile/utils/notification_service.dart' as notif;

class TestPage2 extends StatefulWidget {
  const TestPage2({super.key});

  @override
  State<TestPage2> createState() => _TestPage2State();
}

class _TestPage2State extends State<TestPage2> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _includeNowTimestamp = true;
  // timezone offset in hours; null = device local, otherwise offset hours from UTC
  int? _selectedOffsetHours = 8; // default to UTC+8
  @override
  void initState() {
    super.initState();
    // Initialize shared notification service (handles permissions/channels)
    notif.initializeNotifications();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    // _timestampController removed; nothing to dispose for picker's controller
    super.dispose();
  }

  Future<void> _showImmediateNotification() async {
    await notif.showHighPriorityNotification(
      id: notif.generateNotificationId(),
      title: 'Hello',
      body: 'This is an immediate local notification',
      payload: 'immediate_payload',
      fullScreen: false,
    );
  }

  Future<void> _scheduleNotificationInSeconds(int seconds) async {
    await notif.scheduleHighPriorityInSeconds(
      id: notif.generateNotificationId(),
      title: 'Scheduled',
      body: 'This notification was scheduled $seconds seconds ago',
      seconds: seconds,
    );
  }

  Future<void> _showPeriodicNotification() async {
    await notif.showHighPriorityNotification(
      id: notif.generateNotificationId(),
      title: 'Repeating (demo)',
      body:
          'Periodic demo: single notification shown instead of scheduled repeats.',
    );
  }

  Future<void> _showFullScreenNotification() async {
    await notif.showHighPriorityNotification(
      id: notif.generateNotificationId(),
      title: 'Full-screen Alert',
      body: 'This uses a full-screen intent (demo).',
      fullScreen: true,
    );
  }

  Future<void> _openNotificationSettings() async {
    await notif.openNotificationSettings();
  }

  Future<void> _cancelNotification(int id) async {
    await notif.cancelNotification(id);
  }

  Future<void> _cancelAllNotifications() async {
    await notif.cancelAllNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Notifications Demo')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter notification title',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  hintText: 'Enter notification body',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        // Open date picker then time picker
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDateTime ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedDateTime != null
                              ? TimeOfDay.fromDateTime(_selectedDateTime!)
                              : TimeOfDay.now(),
                        );
                        if (time == null) return;
                        setState(() {
                          _selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(
                            text: _selectedDateTime != null
                                ? _selectedDateTime!.toIso8601String()
                                : '',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Timestamp (pick)',
                            hintText: 'Tap to pick date & time',
                          ),
                          readOnly: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      const Text('Use now'),
                      Switch(
                        value: _includeNowTimestamp,
                        onChanged: (v) => setState(() {
                          _includeNowTimestamp = v;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Timezone:'),
                  const SizedBox(width: 12),
                  DropdownButton<int?>(
                    value: _selectedOffsetHours,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Device local'),
                      ),
                      const DropdownMenuItem<int?>(
                        value: 0,
                        child: Text('UTC±0'),
                      ),
                      // add offsets -12..+14
                      ...List<DropdownMenuItem<int>>.generate(27, (i) {
                        final offset = i - 12; // -12..+14
                        return DropdownMenuItem<int>(
                          value: offset,
                          child: Text('UTC${offset >= 0 ? '+' : ''}$offset'),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _selectedOffsetHours = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final title = _titleController.text.isNotEmpty
                      ? _titleController.text
                      : 'No title';
                  final bodyText = _bodyController.text.isNotEmpty
                      ? _bodyController.text
                      : 'No body';
        
                  DateTime targetLocal;
                  if (_includeNowTimestamp) {
                    targetLocal = DateTime.now();
                  } else if (_selectedDateTime != null) {
                    targetLocal = _selectedDateTime!;
                  } else {
                    targetLocal = DateTime.now();
                  }
        
                  // Compute absolute UTC moment based on selected timezone choice.
                  DateTime targetAbsoluteUtc;
                  if (_selectedOffsetHours == null) {
                    // Device local: interpret targetLocal as local time
                    targetAbsoluteUtc = targetLocal.toUtc();
                  } else {
                    // Interpret the picked date-time as being in the chosen UTC offset
                    final offset = _selectedOffsetHours!;
                    // Construct UTC moment by subtracting the offset hours
                    targetAbsoluteUtc = DateTime.utc(
                      targetLocal.year,
                      targetLocal.month,
                      targetLocal.day,
                      targetLocal.hour - offset,
                      targetLocal.minute,
                      targetLocal.second,
                    );
                  }
        
                  final fullBody =
                      '$bodyText\nTimestamp: ${targetAbsoluteUtc.toIso8601String()}';
        
                  final id = notif.generateNotificationId();
                  if (targetAbsoluteUtc.isAfter(
                    DateTime.now().toUtc().add(const Duration(seconds: 1)),
                  )) {
                    // schedule if target is in the future
                    await notif.scheduleAt(
                      id: id,
                      title: title,
                      body: fullBody,
                      payload: 'from_testpage2',
                      target: targetAbsoluteUtc,
                      fullScreen: false,
                    );
                  } else {
                    await notif.showHighPriorityNotification(
                      id: id,
                      title: title,
                      body: fullBody,
                      payload: 'from_testpage2',
                      fullScreen: false,
                    );
                  }
                },
                child: const Text('Send Notification (high priority)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _showFullScreenNotification,
                child: const Text('Send Full-Screen Notification'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _showImmediateNotification,
                child: const Text('Show Immediate Notification'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _scheduleNotificationInSeconds(5),
                child: const Text('Schedule in 5 seconds'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _showPeriodicNotification,
                child: const Text('Start Periodic (every minute)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _openNotificationSettings,
                child: const Text('Open Notification Settings'),
              ),
              const SizedBox(height: 12),
           
            ],
          ),
        ),
      ),
    );
  }
}
