import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class EditChannelModal extends ConsumerStatefulWidget {
  final Channel channel;

  const EditChannelModal({super.key, required this.channel});

  @override
  ConsumerState<EditChannelModal> createState() => _EditChannelModalState();
}

class _EditChannelModalState extends ConsumerState<EditChannelModal> {
  late TextEditingController _descController;
  late TextEditingController _topicController;
  // Kept in the dialog, not in the channel list state, so an old error never
  // shows when the dialog is opened again.
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.channel.description);
    _topicController = TextEditingController(text: widget.channel.topic);
  }

  @override
  void dispose() {
    _descController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    // A second tap before the screen rebuilds must not start a second save.
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final success = await ref
        .read(channelProvider.notifier)
        .updateChannelTopicOrDescription(
          channelId: widget.channel.id,
          topic: _topicController.text.trim(),
          description: _descController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Could not save the changes. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final isLoading = _isSaving;
    final errorMessage = _errorMessage;

    return Dialog(
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit #${widget.channel.name}',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Topic',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                hintText: 'Add a topic',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              'Description',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'What is this channel about?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save changes',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
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
