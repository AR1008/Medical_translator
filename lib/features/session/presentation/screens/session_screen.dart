import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  bool _sessionActive = false;
  DateTime? _sessionStartTime;
  Duration _sessionDuration = Duration.zero;

  void _toggleSession() {
    setState(() {
      if (_sessionActive) {
        _sessionActive = false;
        _sessionStartTime = null;
      } else {
        _sessionActive = true;
        _sessionStartTime = DateTime.now();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _sessionActive ? Icons.timer : Icons.timer_outlined,
                size: 100,
                color: _sessionActive ? Colors.green : theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _sessionActive ? 'Session Active' : 'No Active Session',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_sessionActive) ...[
                Text(
                  'Started: ${DateFormat('hh:mm a').format(_sessionStartTime!)}',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(_sessionDuration),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _toggleSession,
                icon: Icon(_sessionActive ? Icons.stop : Icons.play_arrow),
                label: Text(_sessionActive ? 'End Session' : 'Start Session'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: _sessionActive ? Colors.red : Colors.green,
                ),
              ),
              if (_sessionActive) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Patient:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Text('John Doe'),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Department:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Text('General Medicine'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
