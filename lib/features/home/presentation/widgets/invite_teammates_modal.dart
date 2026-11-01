import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class InviteTeammatesModal extends ConsumerStatefulWidget {
  const InviteTeammatesModal({super.key});

  @override
  ConsumerState<InviteTeammatesModal> createState() =>
      _InviteTeammatesModalState();
}

class _InviteTeammatesModalState extends ConsumerState<InviteTeammatesModal> {
  final _emailController = TextEditingController();
  final List<Map<String, String?>> _invites = [];
  List<Map<String, dynamic>> _registeredUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = false;
  bool _isAddingEveryone = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    final notifier = ref.read(userProfileNotifierProvider.notifier);
    final users = await notifier.fetchRegisteredUsers();
    if (mounted) {
      setState(() {
        _registeredUsers = users;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _filteredUsers = []);
      return;
    }
    setState(() {
      _filteredUsers = _registeredUsers.where((u) {
        final email = (u['email'] as String?)?.toLowerCase() ?? '';
        final name = (u['full_name'] as String?)?.toLowerCase() ?? '';
        final username = (u['username'] as String?)?.toLowerCase() ?? '';
        final q = query.toLowerCase();
        return email.contains(q) || name.contains(q) || username.contains(q);
      }).toList();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Adds the typed email as an invite. Returns false, and shows an error,
  /// when the box holds text that is not a valid email address.
  bool _addEmailFromInput() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return true;
    if (Validators.validateEmail(context, email) != null) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return false;
    }
    _addInvite(email, null);
    return true;
  }

  void _addInvite(String email, String? userId) {
    final key = email.toLowerCase();
    if (!_invites.any((invite) => invite['email']!.toLowerCase() == key)) {
      setState(() {
        _invites.add({'email': email, 'userId': userId});
        _filteredUsers = [];
      });
    }
    _emailController.clear();
    if (_emailError != null) setState(() => _emailError = null);
  }

  void _removeInvite(String email) {
    setState(() {
      _invites.removeWhere((invite) => invite['email'] == email);
    });
  }

  Future<void> _submit() async {
    // Catch any typed email not yet submitted
    if (!_addEmailFromInput()) return;

    if (_invites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter at least one email address.'),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final notifier = ref.read(userProfileNotifierProvider.notifier);
    int successCount = 0;
    String? lastError;

    // Loop through and invite all
    for (final invite in _invites) {
      // Assuming 'User' role by default since there's no dropdown in UI
      await notifier.inviteMember(
        email: invite['email']!,
        role: 'User',
        userId: invite['userId'],
      );
      final state = ref.read(userProfileNotifierProvider);
      if (state.error != null) {
        lastError = state.error;
      } else {
        successCount++;
      }
    }

    if (!mounted) return;

    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully invited $successCount teammates.'),
          backgroundColor: context.colors.success,
        ),
      );
      Navigator.pop(context);
    } else if (lastError != null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lastError),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  Future<void> _addEveryone() async {
    setState(() => _isAddingEveryone = true);
    final result = await ref.read(addEveryoneToChannelProvider).call();
    if (!mounted) return;
    setState(() => _isAddingEveryone = false);

    final colors = context.colors;
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case AddEveryoneAdded(:final count, :final channelName):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Added $count ${count == 1 ? 'person' : 'people'} to #$channelName.',
            ),
            backgroundColor: colors.success,
          ),
        );
        Navigator.pop(context);
      case AddEveryoneNobodyToAdd(:final channelName):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Everyone in your organisation is already in #$channelName.',
            ),
          ),
        );
      case AddEveryoneFailed(:final message):
        messenger.showSnackBar(
          SnackBar(content: Text(message), backgroundColor: colors.error),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final channelName = openChannelName(ref.watch(activeChatProvider));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: colors.background,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Add people to #$channelName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textHint),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Send to',
              style: TextStyle(
                fontSize: 14,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ..._invites.map(
                    (invite) => Chip(
                      label: Text(invite['email']!),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                      backgroundColor: colors.background,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeInvite(invite['email']!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                        side: BorderSide(color: colors.divider),
                      ),
                    ),
                  ),
                  IntrinsicWidth(
                    child: TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: _invites.isEmpty
                            ? '|Enter name or email'
                            : '',
                        hintStyle: TextStyle(
                          color: colors.textHint.withValues(alpha: 0.7),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (value) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                        _onSearchChanged(value);
                      },
                      onSubmitted: (_) => _addEmailFromInput(),
                      onEditingComplete: _addEmailFromInput,
                    ),
                  ),
                ],
              ),
            ),
            if (_emailError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _emailError!,
                  style: TextStyle(color: colors.error, fontSize: 12),
                ),
              ),
            if (_filteredUsers.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 150),
                child: Material(
                  color: colors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: colors.divider),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final email = user['email'] as String? ?? '';
                      final name =
                          user['full_name'] as String? ??
                          user['username'] as String? ??
                          'Unknown';
                      final userId = user['id'] as String?;
                      return ListTile(
                        title: Text(
                          name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          email,
                          style: TextStyle(
                            color: colors.textHint,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () {
                          if (email.isNotEmpty) _addInvite(email, userId);
                        },
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Search for people in your organisation and add them to #$channelName.',
              style: TextStyle(fontSize: 12, color: colors.textHint),
            ),
            const SizedBox(height: 24),
            Divider(color: colors.divider.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.link, color: colors.textPrimary),
                      tooltip: 'Copy Invite Link',
                      onPressed: () async {
                        final notifier = ref.read(
                          userProfileNotifierProvider.notifier,
                        );
                        final link = await notifier.generateInviteLink();
                        if (link != null && context.mounted) {
                          await Clipboard.setData(ClipboardData(text: link));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Invite link copied to clipboard!',
                                ),
                                backgroundColor: colors.success,
                              ),
                            );
                          }
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Failed to generate link'),
                              backgroundColor: colors.error,
                            ),
                          );
                        }
                      },
                    ),
                    TextButton(
                      onPressed: _isLoading || _isAddingEveryone
                          ? null
                          : _addEveryone,
                      style: TextButton.styleFrom(
                        backgroundColor: colors.background,
                        foregroundColor: colors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        _isAddingEveryone ? 'Adding…' : 'Add everyone',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.primary.withValues(
                      alpha: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.onPrimary,
                            ),
                          ),
                        )
                      : const Text(
                          'Add',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
