import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

/// Full-featured "Set a status" dialog that matches the Figma design.
///
/// Flow:
///   1. User types status text (emoji icon prefix is separate).
///   2. User picks a timeout from the [StatusTimeout] dropdown.
///   3. User optionally checks "Pause notifications".
///   4. On Save → [AuthNotifier.changeStatus] is called; dialog pops on success.
///
/// Quick-pick presets (matching the second Figma screen) are shown below the
/// text field and auto-populate the form when tapped.
class SetStatusDialog extends ConsumerStatefulWidget {
  const SetStatusDialog({super.key});

  @override
  ConsumerState<SetStatusDialog> createState() => _SetStatusDialogState();
}

class _SetStatusDialogState extends ConsumerState<SetStatusDialog> {
  late final TextEditingController _textCtrl;
  String? _selectedEmoji;
  StatusTimeout _timeout = StatusTimeout.thirtyMinutes;
  bool _pauseNotifications = false;
  bool _isSaving = false;

  // ── Preset statuses (second Figma screen) ──────────────────────────────────
  static const _presets = [
    _StatusPreset('📅', 'In a meeting', StatusTimeout.oneHour),
    _StatusPreset('🚗', 'Commuting', StatusTimeout.thirtyMinutes),
    _StatusPreset('🤒', 'Out sick', StatusTimeout.today),
    _StatusPreset('🌴', 'Vacationing', StatusTimeout.dontRemove),
    _StatusPreset('🏠', 'Working remotely', StatusTimeout.today),
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill from current status if any.
    final current = ref.read(authNotifierProvider).user?.status;
    _textCtrl = TextEditingController(text: current?.text ?? '');
    _selectedEmoji = current?.emoji;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  /// The preset whose emoji, text and timeout all match the current form
  /// values, or null once the user edits them into a custom status.
  _StatusPreset? get _selectedPreset {
    final text = _textCtrl.text.trim();
    for (final preset in _presets) {
      if (preset.emoji == _selectedEmoji &&
          preset.label == text &&
          preset.timeout == _timeout) {
        return preset;
      }
    }
    return null;
  }

  void _applyPreset(_StatusPreset preset) {
    setState(() {
      _selectedEmoji = preset.emoji;
      _textCtrl.text = preset.label;
      _timeout = preset.timeout;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final online = ref.read(authNotifierProvider).user?.status.online ?? true;
    final success = await ref
        .read(authNotifierProvider.notifier)
        .changeStatus(
          icon: _selectedEmoji ?? '',
          text: _textCtrl.text.trim(),
          timeout: _timeout,
          pauseNotifications: _pauseNotifications,
          online: online,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop();
    } else {
      final error =
          ref.read(authNotifierProvider).error ?? 'Failed to update status.';
      AppToastService.show(context, type: AppToastType.error, message: error);
    }
  }

  Future<void> _pickEmoji() async {
    final emoji = await showDialog<String>(
      context: context,
      builder: (_) => const EmojiPickerDialog(),
    );
    if (emoji != null && mounted) setState(() => _selectedEmoji = emoji);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Set a status',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textHint, size: 20),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Status text field with emoji prefix ────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.borderOutline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // Emoji picker trigger
                    InkWell(
                      onTap: _pickEmoji,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: _selectedEmoji != null
                            ? Text(
                                _selectedEmoji!,
                                style: const TextStyle(fontSize: 20),
                              )
                            : Icon(
                                Icons.sentiment_satisfied_alt_outlined,
                                color: colors.textHint,
                                size: 22,
                              ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: colors.borderOutline,
                    ),
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _textCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: "What's your status?",
                          hintStyle: context.textTheme.bodyMedium?.copyWith(
                            color: colors.textHint,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                        ),
                        maxLength: 100,
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              maxLength,
                              required isFocused,
                            }) => null,
                      ),
                    ),
                    // Clear button
                    if (_textCtrl.text.isNotEmpty || _selectedEmoji != null)
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16,
                          color: colors.textHint,
                        ),
                        splashRadius: 14,
                        onPressed: () => setState(() {
                          _textCtrl.clear();
                          _selectedEmoji = null;
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Quick-pick presets ─────────────────────────────────────────
              Text(
                'Suggested',
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.textHint,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...[
                for (final preset in _presets)
                  _PresetTile(
                    preset: preset,
                    selected: preset == _selectedPreset,
                    onTap: () => _applyPreset(preset),
                  ),
              ],
              const SizedBox(height: 20),

              // ── Remove after dropdown ──────────────────────────────────────
              Text(
                'Remove status after…',
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              _TimeoutDropdown(
                value: _timeout,
                onChanged: (v) => setState(() => _timeout = v),
              ),
              const SizedBox(height: 16),

              // ── Pause notifications checkbox ───────────────────────────────
              Row(
                children: [
                  Checkbox(
                    value: _pauseNotifications,
                    activeColor: colors.primary,
                    onChanged: (v) =>
                        setState(() => _pauseNotifications = v ?? false),
                  ),
                  GestureDetector(
                    onTap: () => setState(
                      () => _pauseNotifications = !_pauseNotifications,
                    ),
                    child: Text(
                      'Pause notifications',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Actions ────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.borderOutline),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small internal widgets ─────────────────────────────────────────────────────

class _StatusPreset {
  const _StatusPreset(this.emoji, this.label, this.timeout);
  final String emoji;
  final String label;
  final StatusTimeout timeout;
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final _StatusPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(8);
    return Material(
      color: selected ? colors.primaryBg : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: selected ? BorderSide(color: colors.primary) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          child: Row(
            children: [
              Text(preset.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  preset.label,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
              ),
              Text(
                '– ${preset.timeout.label}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: selected ? colors.primary : colors.textHint,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, size: 18, color: colors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeoutDropdown extends StatelessWidget {
  const _TimeoutDropdown({required this.value, required this.onChanged});

  final StatusTimeout value;
  final ValueChanged<StatusTimeout> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderOutline),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<StatusTimeout>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: Icon(Icons.keyboard_arrow_down, color: colors.textHint),
        style: context.textTheme.bodyMedium?.copyWith(
          color: colors.textPrimary,
        ),
        dropdownColor: colors.background,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: StatusTimeout.values.map((t) {
          return DropdownMenuItem(value: t, child: Text(t.label));
        }).toList(),
      ),
    );
  }
}

/// A small coloured dot that represents user online/away presence.
/// Used in the sidebar rail user button and conversation tiles.
class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.online, this.size = 10});

  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: online ? colors.presenceActive : colors.presenceAway,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
