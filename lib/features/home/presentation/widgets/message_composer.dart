import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MessageComposer extends ConsumerStatefulWidget {
  final ActiveChatState activeChat;
  final ValueChanged<String> onSend;

  const MessageComposer({
    super.key,
    required this.activeChat,
    required this.onSend,
  });

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isRecording = false;
  bool _showMentions = false;
  final List<String> _attachedFiles = [];
  final AudioRecorder _audioRecorder = AudioRecorder();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      setState(() => _isRecording = true);
      // In a real app we'd specify a path. Using default temp path for mock.
      await _audioRecorder.start(const RecordConfig(), path: '');
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      if (path != null) {
        _controller.text = '[Voice Note Attached]';
      }
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachedFiles.isEmpty) return;

    String finalMessage = text;
    if (_attachedFiles.isNotEmpty) {
      final attachmentsStr = _attachedFiles
          .map((f) => '[Attachment: $f]')
          .join(' ');
      finalMessage = text.isEmpty ? attachmentsStr : '$text\n$attachmentsStr';
    }

    widget.onSend(finalMessage);
    _controller.clear();
    setState(() {
      _attachedFiles.clear();
      _isRecording = false;
      _showMentions = false;
    });
  }

  void _onTextChanged(String value) {
    setState(() {
      if (value.endsWith('@')) {
        _showMentions = true;
      } else if (_showMentions && !value.contains('@')) {
        _showMentions = false;
      }
    });
  }

  void _insertMention(String name) {
    final text = _controller.text;
    final lastAt = text.lastIndexOf('@');
    if (lastAt != -1) {
      final newText = text.replaceRange(
        lastAt,
        text.length,
        '@${name.replaceAll(' ', '')} ',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    setState(() => _showMentions = false);
    _focusNode.requestFocus();
  }

  void _insertFormatting(String prefix, String suffix) {
    final text = _controller.text;
    final selection = _controller.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = selection.textInside(text);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset:
              selection.start +
              prefix.length +
              selectedText.length +
              suffix.length,
        ),
      );
    } else {
      final offset = selection.baseOffset >= 0
          ? selection.baseOffset
          : text.length;
      final newText = text.replaceRange(offset, offset, '$prefix$suffix');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + prefix.length),
      );
    }
    setState(() {}); // Trigger rebuild to show send icon
    _focusNode.requestFocus(); // Ensure cursor remains active
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final teamMembers = ref.watch(userProfileNotifierProvider).teamMembers;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          if (_showMentions)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: colors.background,
                border: Border.all(color: colors.divider),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: teamMembers.map((member) {
                  final name = member.name ?? member.email;
                  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                  return InkWell(
                    onTap: () => _insertMention(name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: colors.primary.withValues(
                              alpha: 0.1,
                            ),
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (_isFocused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.background,
                border: Border.all(color: colors.divider),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  _ToolbarButton(
                    icon: Icons.format_bold,
                    onPressed: () => _insertFormatting('**', '**'),
                    tooltip: 'Bold',
                  ),
                  _ToolbarButton(
                    icon: Icons.format_italic,
                    onPressed: () => _insertFormatting('*', '*'),
                    tooltip: 'Italic',
                  ),
                  _ToolbarButton(
                    icon: Icons.code,
                    onPressed: () => _insertFormatting('`', '`'),
                    tooltip: 'Code',
                  ),
                  _ToolbarButton(
                    icon: Icons.format_list_bulleted,
                    onPressed: () => _insertFormatting('- ', ''),
                    tooltip: 'Bullet List',
                  ),
                  _ToolbarButton(
                    icon: Icons.format_list_numbered,
                    onPressed: () => _insertFormatting('1. ', ''),
                    tooltip: 'Numbered List',
                  ),
                  const Spacer(),
                  _ToolbarButton(
                    icon: Icons.emoji_emotions_outlined,
                    onPressed: () => _insertFormatting('😀', ''),
                    tooltip: 'Emoji',
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(
                color: _isFocused ? colors.primary : colors.divider,
              ),
              borderRadius: _isFocused
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    )
                  : BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () async {
                    FilePickerResult? result = await FilePicker.pickFiles(
                      allowMultiple: true,
                    );
                    if (result != null) {
                      setState(() {
                        _attachedFiles.addAll(result.names.whereType<String>());
                      });
                    }
                  },
                  icon: Icon(Icons.add, color: colors.textHint),
                  splashRadius: 20,
                  tooltip: 'Attach file',
                ),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      final key = event.logicalKey;
                      // Allow submitting with Ctrl/Cmd+Enter like the DM composer.
                      if (key == LogicalKeyboardKey.enter &&
                          (HardwareKeyboard.instance.isControlPressed ||
                              HardwareKeyboard.instance.isMetaPressed)) {
                        _handleSend();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onTextChanged,
                      minLines: 1,
                      maxLines: 8,
                      style: TextStyle(color: colors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: widget.activeChat.type == ActiveChatType.groupDm
                            ? 'Message group...'
                            : 'Message #${widget.activeChat.id ?? "general"}',
                        hintStyle: TextStyle(color: colors.textHint),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                if (_controller.text.isEmpty && !_isRecording)
                  IconButton(
                    onPressed: _startRecording,
                    icon: Icon(Icons.mic_none, color: colors.textHint),
                    splashRadius: 20,
                    tooltip: 'Record voice note',
                  )
                else if (_isRecording)
                  Row(
                    children: [
                      Text(
                        'Recording... 0:05',
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                      IconButton(
                        onPressed: _stopRecording,
                        icon: Icon(Icons.stop_circle, color: colors.error),
                        splashRadius: 20,
                      ),
                    ],
                  )
                else
                  IconButton(
                    onPressed: _handleSend,
                    icon: Icon(Icons.send, color: colors.primary),
                    splashRadius: 20,
                  ),
              ],
            ),
          ),
          if (_attachedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _attachedFiles.map((fileName) {
                  return Chip(
                    label: Text(
                      fileName,
                      style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    ),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color: colors.textHint,
                    ),
                    onDeleted: () {
                      setState(() {
                        _attachedFiles.remove(fileName);
                      });
                    },
                    backgroundColor: colors.background,
                    side: BorderSide(color: colors.divider),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _ToolbarButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: context.colors.textHint),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
