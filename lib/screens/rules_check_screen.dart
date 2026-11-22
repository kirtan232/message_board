import 'package:flutter/material.dart';

import '../services/board_service.dart';
import '../services/rules_probe_service.dart';
import '../utils/format.dart';

/// Runs real requests against Firestore and shows, for each one, the
/// expected and observed outcome — evidence that the rules (not the UI)
/// deny signed-out reads, forged authors, and cross-user writes.
class RulesCheckScreen extends StatefulWidget {
  const RulesCheckScreen({
    super.key,
    required this.uid,
    required this.displayName,
    required this.email,
  });

  final String uid;
  final String displayName;
  final String email;

  @override
  State<RulesCheckScreen> createState() => _RulesCheckScreenState();
}

class _RulesCheckScreenState extends State<RulesCheckScreen> {
  final RulesProbeService _probe = RulesProbeService();
  List<ProbeResult>? _results;
  DateTime? _ranAt;
  bool _running = false;

  final BoardService _board = BoardService();
  String? _dupResult;
  bool? _dupPassed;
  bool _dupRunning = false;

  /// Spice #4 evidence: fire the same post twice at once (a double-tap /
  /// retry) through the real BoardService, then count documents on the server.
  Future<void> _runDuplicateCheck() async {
    if (_dupRunning) return;
    setState(() {
      _dupRunning = true;
      _dupResult = null;
      _dupPassed = null;
    });
    try {
      final before = await _board.countMessagesBy(widget.uid);
      final id = _board.newMessageId();
      const text = '[duplicate check] posted twice with one id';
      await Future.wait([
        for (var i = 0; i < 2; i++)
          _board.postMessage(
            messageId: id,
            authorUid: widget.uid,
            authorName: widget.displayName,
            text: text,
          ),
      ]);
      final after = await _board.countMessagesBy(widget.uid);
      final stored = await _board.getMessage(id);
      await _board.deleteMessage(messageId: id); // clean up the probe

      final created = after - before;
      final passed = created == 1 && stored?.text == text;
      setState(() {
        _dupPassed = passed;
        _dupResult =
            'Calls sent: 2 (same id $id)\n'
            'Your messages before: $before, after: $after\n'
            'New documents created: $created (expected 1)\n'
            'Probe message deleted afterwards.';
      });
    } on BoardException catch (e) {
      setState(() {
        _dupPassed = false;
        _dupResult = 'Error: ${e.message}';
      });
    } finally {
      if (mounted) setState(() => _dupRunning = false);
    }
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final results = await _probe.runAll(
        myUid: widget.uid,
        myName: widget.displayName,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _ranAt = DateTime.now();
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    final ran = results?.where((r) => !r.skipped).length ?? 0;
    final passed = results?.where((r) => r.passed).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Rules Check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Sends real requests to Cloud Firestore. "DENIED" means the '
            'Firestore server returned permission-denied — the security '
            'rules blocked it, not the app.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Signed in as ${widget.email}',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_running ? 'Running…' : 'Run rules check'),
          ),
          if (results != null) ...[
            const SizedBox(height: 16),
            Card(
              color: passed == ran
                  ? Colors.green.withValues(alpha: 0.15)
                  : theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  passed == ran ? Icons.verified_user : Icons.gpp_bad,
                  color: passed == ran ? Colors.green : theme.colorScheme.error,
                ),
                title: Text('$passed / $ran checks passed'),
                subtitle: Text(
                  'Run at ${formatMessageTime(_ranAt!)}'
                  '${results.any((r) => r.skipped) ? ' · some skipped' : ''}',
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < results.length; i++)
              _ResultTile(index: i + 1, result: results[i]),
          ],
          const Divider(height: 40),
          Text('Duplicate-submit check', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Sends the same post twice at the same moment (like a double-tap '
            'or a retry) and counts how many documents Firestore stored.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _dupRunning ? null : _runDuplicateCheck,
            icon: _dupRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy_all),
            label: Text(_dupRunning ? 'Running…' : 'Run duplicate check'),
          ),
          if (_dupResult != null) ...[
            const SizedBox(height: 12),
            Card(
              color: _dupPassed == true
                  ? Colors.green.withValues(alpha: 0.15)
                  : theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  _dupPassed == true ? Icons.check_circle : Icons.error,
                  color: _dupPassed == true
                      ? Colors.green
                      : theme.colorScheme.error,
                ),
                title: Text(_dupPassed == true ? 'PASS' : 'FAIL'),
                subtitle: Text(_dupResult!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.index, required this.result});

  final int index;
  final ProbeResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color;
    final String badge;
    if (result.skipped) {
      color = theme.colorScheme.outline;
      badge = 'SKIP';
    } else if (result.passed) {
      color = Colors.green;
      badge = 'PASS';
    } else {
      color = theme.colorScheme.error;
      badge = 'FAIL';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index. ${result.name}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('Expected: ${result.expectedLabel}'),
                  Text('Observed: ${result.observedLabel}'),
                  if (result.skippedReason != null)
                    Text(
                      result.skippedReason!,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Text(
                badge,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
