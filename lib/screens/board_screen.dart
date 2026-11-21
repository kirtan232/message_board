import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/board_service.dart';
import '../utils/format.dart';

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
            return _MessageBubble(
              key: ValueKey(message.id),
              message: message,
              isMine: message.isOwnedBy(widget.user.uid),
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
  });

  final Message message;
  final bool isMine;

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
              Text(
                isMine ? 'You' : message.authorName,
                style: textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                ),
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
