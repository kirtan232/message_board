import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/validators.dart';
import 'board_screen.dart';

/// Keeps the board behind a complete Firestore user record.
///
/// Auth account creation and the Firestore write are two separate services,
/// so the account can exist while the record does not. This gate writes the
/// pending registration draft, shows loading/error states, offers a retry for
/// the same uid, and falls back to a "complete your profile" form.
class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.user,
    required this.auth,
    required this.users,
  });

  final User user;
  final AuthService auth;
  final UserService users;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final Stream<AppUser?> _record = widget.users.watchUser(widget.user.uid);
  ProfileDraft? _draft;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.users.pendingDraft;
    widget.users.pendingDraft = null;
    if (_draft != null) _save(_draft!);
  }

  Future<void> _save(ProfileDraft draft) async {
    setState(() {
      _draft = draft;
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.users.saveUserRecord(uid: widget.user.uid, draft: draft);
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _record,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Message(
            icon: Icons.error_outline,
            title: 'Could not load your profile.',
            body: 'Check your connection, then sign out and back in.',
            auth: widget.auth,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting || _saving) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final record = snapshot.data;
        if (record != null && record.isComplete) {
          return BoardScreen(
            auth: widget.auth,
            user: widget.user,
            profile: record,
          );
        }

        if (_saveFailed && _draft != null) {
          return _Message(
            icon: Icons.cloud_off_rounded,
            title: 'Account created, profile not saved.',
            body:
                'Your account exists, but your profile could not be saved. '
                'Check your connection and try again.',
            auth: widget.auth,
            onRetry: () => _save(_draft!),
          );
        }

        return _CompleteProfileForm(
          email: widget.user.email ?? '',
          auth: widget.auth,
          onSubmit: _save,
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.auth,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final AuthService auth;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              TextButton(
                onPressed: auth.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a signed-in user has no record (e.g. the app closed between
/// account creation and the profile write).
class _CompleteProfileForm extends StatefulWidget {
  const _CompleteProfileForm({
    required this.email,
    required this.auth,
    required this.onSubmit,
  });

  final String email;
  final AuthService auth;
  final Future<void> Function(ProfileDraft draft) onSubmit;

  @override
  State<_CompleteProfileForm> createState() => _CompleteProfileFormState();
}

class _CompleteProfileFormState extends State<_CompleteProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  String _role = kUserRoles.first;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(
      ProfileDraft(
        firstName: _firstName.text,
        lastName: _lastName.text,
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete your profile'),
        actions: [
          TextButton(
            onPressed: widget.auth.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Signed in as ${widget.email}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Finish your profile to reach the message board.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => Validators.name(v, label: 'first name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => Validators.name(v, label: 'last name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final role in kUserRoles)
                        DropdownMenuItem(
                          value: role,
                          child: Text(
                            role[0].toUpperCase() + role.substring(1),
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _role = value!),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Save profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
