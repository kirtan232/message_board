import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';
import '../utils/format.dart';
import '../widgets/edit_message_dialog.dart';

/// The message board: a live stream of messages plus a composer.
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.auth,
    required this.user,
    required this.profile,
  });

  final AuthService auth;
  final User user;
  final AppUser profile;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final BoardService _board = BoardService();

  /// Created once so rebuilds never open a second subscription.
  late final Stream<List<Message>> _messages = _board.messageBoard();

  final _composer = TextEditingController();
  bool _posting = false;

  /// One reserved id per composed message: a double-tap or retry of the same
  /// message targets the same document, so only one is ever created.
  late String _draftId = _board.newMessageId();

  /// Messages with an edit/delete in flight (prevents double actions).
  final Set<String> _busyIds = {};

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_posting) return;
    final text = _composer.text;
    final problem = BoardService.validateText(text);
    if (problem != null) {
      _showMessage(problem);
      return;
    }

    setState(() => _posting = true);
    try {
      await _board.postMessage(
        messageId: _draftId,
        authorUid: widget.user.uid,
        authorName: widget.profile.fullName,
        text: text,
      );
      _composer.clear();
      _draftId = _board.newMessageId();
    } on BoardException catch (error) {
      // Keep the same draft id so a retry cannot create a duplicate.
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _showActions(Message message) async {
    if (_busyIds.contains(message.id)) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit message'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete message',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await _edit(message);
    if (action == 'delete') await _delete(message);
  }

  Future<void> _edit(Message message) async {
    final newText = await showEditMessageDialog(context, message);
    if (newText == null) return;
    await _runBusy(message.id, () async {
      await _board.editMessage(messageId: message.id, newText: newText);
      _showMessage('Message updated.');
    });
  }

  Future<void> _delete(Message message) async {
    if (!await confirmDeleteMessage(context)) return;
    await _runBusy(message.id, () async {
      await _board.deleteMessage(messageId: message.id);
      _showMessage('Message deleted.');
    });
  }

  /// Marks [id] busy while [action] runs; the stream re-renders the board,
  /// so there is no manual refresh. Rule denials surface as friendly text.
  Future<void> _runBusy(String id, Future<void> Function() action) async {
    setState(() => _busyIds.add(id));
    try {
      await action();
    } on BoardException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will return to the sign-in screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Board'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                widget.profile.firstName,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBoard()),
          _Composer(controller: _composer, posting: _posting, onPost: _post),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return StreamBuilder<List<Message>>(
      stream: _messages,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return _CenteredNote(
            icon: Icons.error_outline,
            title: 'Could not load the board.',
            body: error is BoardException
                ? error.message
                : 'Something went wrong. Please try again.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? const <Message>[];
        if (messages.isEmpty) {
          return const _CenteredNote(
            icon: Icons.chat_bubble_outline,
            title: 'No messages yet',
            body: 'Be the first to post something on the board!',
          );
        }

        // reverse: true keeps the newest message pinned at the bottom.
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            final isMine = message.isOwnedBy(widget.user.uid);
            return _MessageBubble(
              key: ValueKey(message.id),
              message: message,
              isMine: isMine,
              busy: _busyIds.contains(message.id),
              // Convenience only: the security rules are what actually
              // block edits/deletes of other users' messages.
              onActions: isMine ? () => _showActions(message) : null,
            );
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.busy = false,
    this.onActions,
  });

  final Message message;
  final bool isMine;
  final bool busy;

  /// Opens the edit/delete sheet. Null for other users' messages.
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final background = isMine
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = isMine
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    final created = message.createdAt;
    final meta = [
      if (created == null) 'Sending…' else formatMessageTime(created),
      if (message.isEdited) 'edited',
    ].join(' · ');

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: busy ? null : onActions,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        isMine ? 'You' : message.authorName,
                        style: textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (onActions != null) ...[
                      const SizedBox(width: 8),
                      if (busy)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        )
                      else
                        InkWell(
                          onTap: onActions,
                          borderRadius: BorderRadius.circular(12),
                          child: Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: foreground,
                            semanticLabel: 'Message actions',
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message.text,
                  style: textTheme.bodyLarge?.copyWith(color: foreground),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: textTheme.labelSmall?.copyWith(
                    color: foreground.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.posting,
    required this.onPost,
  });

  final TextEditingController controller;
  final bool posting;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !posting,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: kMaxMessageLength,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onPost(),
                  decoration: const InputDecoration(
                    hintText: 'Write a message…',
                    border: OutlineInputBorder(),
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Post',
                onPressed: posting ? null : onPost,
                icon: posting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
