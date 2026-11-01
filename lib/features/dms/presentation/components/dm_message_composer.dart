import 'dart:async';
import 'dart:io' show Directory, File, Platform;

import 'package:audioplayers/audioplayers.dart'
    show AudioPlayer, DeviceFileSource;

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import 'composer/composer.dart';

class DmMessageComposer extends ConsumerStatefulWidget {
  final String recipientName;
  final String channelId;
  final List<DmParticipant> participants;
  final ValueChanged<String>? onSend;
  final bool isChannel;

  const DmMessageComposer({
    super.key,
    required this.recipientName,
    required this.channelId,
    this.participants = const [],
    this.onSend,
    this.isChannel = false,
  });

  @override
  ConsumerState<DmMessageComposer> createState() => DmMessageComposerState();
}

class DmMessageComposerState extends ConsumerState<DmMessageComposer> {
  late final RichTextController _controller;
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  bool _showEmojiPicker = false;
  bool _isEditMode = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isStarting = false;
  // File the recorder is writing to right now, so it can be removed if the
  // composer is closed while starting or recording.
  String? _activeRecordingPath;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  XFile? _voiceNote;
  AudioPlayer? _previewPlayer;
  bool _isPreviewPlaying = false;
  String? _editingMessageId;

  bool _isBold = false;
  bool _isItalic = false;
  bool _isStrikethrough = false;
  bool _isCode = false;

  List<XFile> _pendingFiles = [];

  List<DmParticipant> _mentionSuggestions = [];
  String _mentionQuery = '';

  /// channelId whose draft this composer instance is currently bound to.
  String? _draftChannelId;

  Timer? _draftSaveDebounce;

  /// Draft store for the current user and org. Held in a field because `ref`
  /// can't be used in [dispose], and a flush must go to the store the draft
  /// was typed against.
  late DmDraftStore _drafts;

  /// Set when this conversation is deleted, so closing the composer doesn't
  /// save its text back as a draft.
  bool _channelDeleted = false;

  @override
  void initState() {
    super.initState();
    _drafts = ref.read(dmDraftStoreProvider);
    _controller = RichTextController();
    _controller.addListener(_onTextChanged);
    _draftChannelId = widget.channelId;
    _restoreDraft();
  }

  @override
  void didUpdateWidget(covariant DmMessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The same composer widget is re-bound when the user switches chats while
    // the chat area stays mounted. Flush the debounced save for the previous
    // conversation (the listener may have saved already; this is a no-op then),
    // then swap to the new conversation and restore its draft if any.
    if (oldWidget.channelId != widget.channelId) {
      _draftSaveDebounce?.cancel();
      final previousChannel = _draftChannelId ?? oldWidget.channelId;
      final previousDrafts = _drafts;
      final wasEditing = _isEditMode;

      // Edit-mode text is an already-sent message, never a draft. Otherwise
      // flush the previous conversation's text. Store and chat-history writes
      // notify providers, so they're deferred until the build has finished.
      if (wasEditing) {
        final previousHistory = ref.read(
          chatHistoryProvider(oldWidget.channelId),
        );
        Future.microtask(previousHistory.cancelEditing);
      } else {
        final previousText = _controller.text;
        Future.microtask(
          () => previousDrafts.save(previousChannel, previousText),
        );
      }
      _drafts = ref.read(dmDraftStoreProvider);
      _draftChannelId = widget.channelId;
      _channelDeleted = false;

      setState(() {
        _pendingFiles = [];
        _showEmojiPicker = false;
        _isEditMode = false;
        _editingMessageId = null;
      });
      _controller.clear();
      _restoreDraft();
    }
  }

  @override
  void dispose() {
    // Flush any un-debounced text. The debounced save normally covers this;
    // the write is deferred because the store notifies providers, which isn't
    // allowed while the tree is unmounting.
    _draftSaveDebounce?.cancel();
    if (!_isEditMode &&
        !_channelDeleted &&
        _controller.text.trim().isNotEmpty) {
      final drafts = _drafts;
      final channelId = _draftChannelId ?? widget.channelId;
      final text = _controller.text;
      Future.microtask(() => drafts.save(channelId, text));
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _previewPlayer?.dispose();
    _deleteRecording(_voiceNote?.path);
    if (_isRecording || _isStarting) {
      final path = _activeRecordingPath;
      _audioRecorder
          .stop()
          .then((stopped) async {
            await _deleteOwnRecording(stopped);
            await _deleteOwnRecording(path);
          })
          .catchError((_) {})
          .whenComplete(_audioRecorder.dispose);
    } else {
      _audioRecorder.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final entry = await _drafts.load(widget.channelId);
    if (!mounted) return;
    if (entry == null || _controller.text.isNotEmpty) return;

    _controller.value = TextEditingValue(
      text: entry.text,
      selection: TextSelection.collapsed(offset: entry.text.length),
    );
  }

  void _onTextChanged() {
    _updateFormattingState();
    _updateMentionSuggestions();
    if (mounted) setState(() {});

    if (_isEditMode) return;

    final text = _controller.text;
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _drafts.save(widget.channelId, text);
    });
  }

  void _updateFormattingState() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      setState(() {
        _isBold = false;
        _isItalic = false;
        _isStrikethrough = false;
        _isCode = false;
      });
      return;
    }
    final before = text.substring(0, sel.baseOffset);
    setState(() {
      _isBold = '**'.allMatches(before).length % 2 != 0;
      _isItalic = RegExp(r'(?<!\*)\*(?!\*)').allMatches(before).length % 2 != 0;
      _isStrikethrough = '~~'.allMatches(before).length % 2 != 0;
      _isCode = '`'.allMatches(before).length % 2 != 0;
    });
  }

  void _updateMentionSuggestions() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      setState(() => _mentionSuggestions = []);
      return;
    }
    final before = text.substring(0, sel.baseOffset);
    final atMatch = RegExp(r'@(\w*)$').firstMatch(before);
    if (atMatch == null) {
      setState(() {
        _mentionSuggestions = [];
        _mentionQuery = '';
      });
      return;
    }
    final query = atMatch.group(1)!.toLowerCase();
    _mentionQuery = query;
    final suggestions = widget.participants.where((p) {
      return p.username.toLowerCase().contains(query) ||
          p.email.toLowerCase().contains(query);
    }).toList();
    setState(() => _mentionSuggestions = suggestions);
  }

  void _insertMention(DmParticipant participant) {
    final text = _controller.text;
    final sel = _controller.selection;
    final before = text.substring(0, sel.baseOffset);
    final atIndex = before.lastIndexOf('@');
    if (atIndex == -1) return;

    final after = text.substring(sel.baseOffset);
    final replacement = '@${participant.username} ';
    final newText = text.substring(0, atIndex) + replacement + after;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIndex + replacement.length),
    );
    setState(() => _mentionSuggestions = []);
    _focusNode.requestFocus();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    final isEdit = _isEditMode && _editingMessageId != null;
    // An edit needs text; a waiting file or voice note must not let it through.
    if (isEdit && text.isEmpty) return;
    if (text.isEmpty && _pendingFiles.isEmpty && _voiceNote == null) return;
    if (widget.channelId.isEmpty) {
      _showVoiceError('Channel not loaded yet.');
      return;
    }

    if (isEdit) {
      ref
          .read(chatHistoryProvider(widget.channelId))
          .saveEdit(_editingMessageId!, text);
      _exitEditMode();
    } else {
      ref
          .read(chatHistoryProvider(widget.channelId))
          .sendMessage(
            text,
            media: [..._pendingFiles, ?_voiceNote],
            isChannel: widget.isChannel,
          );
      widget.onSend?.call(text);
    }

    // The message is out, so the draft no longer exists.
    _draftSaveDebounce?.cancel();
    _drafts.clear(widget.channelId);

    _controller.clear();
    // Saving an edit sends nothing, so a waiting voice note or file is kept.
    if (!isEdit) {
      _previewPlayer?.stop();
      setState(() {
        _pendingFiles = [];
        _voiceNote = null;
        _isPreviewPlaying = false;
      });
    }
    _focusNode.requestFocus();
  }

  /// Puts the given message in the composer for editing, the same way the
  /// Up-arrow shortcut does. Called from the message menu's "Edit message".
  void enterEditMode(String messageId, String content) =>
      _enterEditMode(messageId, content);

  void _enterEditMode(String messageId, String content) {
    setState(() {
      _isEditMode = true;
      _editingMessageId = messageId;
      _controller.text = content;
      _controller.selection = TextSelection.collapsed(offset: content.length);
    });
    _focusNode.requestFocus();
    ref.read(chatHistoryProvider(widget.channelId)).startEditing(messageId);
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _editingMessageId = null;
    });
    _controller.clear();
    ref.read(chatHistoryProvider(widget.channelId)).cancelEditing();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final hasModifier =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      // Shift+Enter must fall through so the default newline is inserted.
      if (!hasModifier && HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      // Never send while an IME (Chinese, Japanese…) is still composing.
      if (_controller.value.composing.isValid &&
          !_controller.value.composing.isCollapsed) {
        return KeyEventResult.ignored;
      }
      // With the @mention list open, plain Enter picks the first suggestion
      // instead of sending the half-typed mention.
      if (!hasModifier && _mentionSuggestions.isNotEmpty) {
        _insertMention(_mentionSuggestions.first);
        return KeyEventResult.handled;
      }
      // Plain Enter, Ctrl+Enter and Cmd+Enter all share the send path, which
      // no-ops on an empty box. Handled either way, so no newline is added.
      _handleSend();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyB &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _insertBold();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyI &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _insertItalic();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_mentionSuggestions.isNotEmpty) {
        setState(() => _mentionSuggestions = []);
        return KeyEventResult.handled;
      }
      if (_isEditMode) {
        _exitEditMode();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowUp && _controller.text.isEmpty) {
      final history = ref.read(chatHistoryProvider(widget.channelId));
      final lastId = history.lastSentMessageId;
      final lastContent = history.lastSentMessageContent;
      if (lastId != null && lastContent != null) {
        _enterEditMode(lastId, lastContent);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _handlePaste();
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  void _wrapSelection(String before, [String? after]) {
    after ??= before;
    final text = _controller.text;
    final sel = _controller.selection;

    if (!sel.isValid) return;

    if (sel.isCollapsed) {
      final insert = '$before$after';
      final newText =
          text.substring(0, sel.start) + insert + text.substring(sel.end);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + before.length),
      );
    } else {
      final selected = text.substring(sel.start, sel.end);
      final replacement = '$before$selected$after';
      final newText =
          text.substring(0, sel.start) + replacement + text.substring(sel.end);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: sel.start + before.length,
          extentOffset: sel.start + before.length + selected.length,
        ),
      );
    }
    _focusNode.requestFocus();
  }

  void _insertBold() => _wrapSelection('**');
  void _insertItalic() => _wrapSelection('*');
  void _insertStrikethrough() => _wrapSelection('~~');
  void _insertCode() => _wrapSelection('`');

  void _insertLink() => _wrapSelection('[', '](url)');

  void _insertQuote() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid) return;
    final selected = text.substring(sel.start, sel.end);
    // A selection that ends right after a newline leaves an empty last piece.
    // Quoting it would put "> " on the first line that is not selected.
    final endsWithNewline = selected.endsWith('\n');
    final lines = selected.split('\n');
    final quoted =
        (endsWithNewline ? lines.sublist(0, lines.length - 1) : lines)
            .map((line) => '> $line')
            .join('\n');
    final insert = endsWithNewline ? '$quoted\n' : quoted;
    final newText =
        text.substring(0, sel.start) + insert + text.substring(sel.end);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + insert.length),
    );
    _focusNode.requestFocus();
  }

  /// Inserts a Markdown horizontal rule (`---`) on its own line at the cursor.
  ///
  /// The rule needs a blank line above it: `text\n---` is a setext heading,
  /// not a divider.
  void _insertDivider() {
    final text = _controller.text;
    final sel = _controller.selection;
    final pos = sel.isValid ? sel.end : text.length;
    final before = text.substring(0, pos);

    final String leading;
    if (before.isEmpty || before.endsWith('\n\n')) {
      leading = '';
    } else if (before.endsWith('\n')) {
      leading = '\n';
    } else {
      leading = '\n\n';
    }

    final insert = '$leading---\n';
    _controller.value = TextEditingValue(
      text: before + insert + text.substring(pos),
      selection: TextSelection.collapsed(offset: pos + insert.length),
    );
    _focusNode.requestFocus();
  }

  void _toggleEmojiPicker() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    final pos = sel.isValid ? sel.baseOffset : text.length;
    final newText = text.substring(0, pos) + emoji + text.substring(pos);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + emoji.length),
    );
    _focusNode.requestFocus();
  }

  bool _isDragging = false;

  Future<void> _toggleVoiceRecording() async {
    if (_isStarting) return;
    if (_isRecording) {
      await _finishVoiceRecording();
    } else if (_voiceNote == null) {
      await _startVoiceRecording();
    }
  }

  void _showVoiceError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _startVoiceRecording() async {
    _isStarting = true;
    try {
      // Nothing shows as "recording" until the microphone is allowed.
      if (!await _audioRecorder.hasPermission()) {
        _showVoiceError('Allow microphone access to record a voice message.');
        return;
      }
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}zedu-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      _activeRecordingPath = path;
      await _audioRecorder.start(const RecordConfig(), path: path);
      // Only remember the file once recording really started.
      appRecordedPaths.add(path);
      if (!mounted) {
        // dispose() is already stopping and cleaning up the recorder.
        await _deleteOwnRecording(path);
        return;
      }
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
    } catch (error) {
      _activeRecordingPath = null;
      if (mounted) setState(() => _isRecording = false);
      _showVoiceError('Could not start recording: $error');
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _finishVoiceRecording() async {
    _recordTimer?.cancel();
    try {
      final recordedPath = await _audioRecorder.stop();
      _activeRecordingPath = null;
      if (!mounted) {
        // The composer is gone, so nobody will send this recording.
        await _deleteRecording(recordedPath);
        return;
      }
      setState(() {
        _isRecording = false;
        if (recordedPath != null) {
          _voiceNote = XFile(
            recordedPath,
            name: 'voice-message-${DateTime.now().millisecondsSinceEpoch}.m4a',
            mimeType: 'audio/mp4',
          );
        }
      });
    } catch (error) {
      if (mounted) setState(() => _isRecording = false);
      _showVoiceError('Could not save the recording: $error');
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordTimer?.cancel();
    try {
      await _deleteRecording(await _audioRecorder.stop());
    } catch (_) {}
    _activeRecordingPath = null;
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _togglePreviewPlayback() async {
    final note = _voiceNote;
    if (note == null) return;
    try {
      final player = _previewPlayer ??= AudioPlayer()
        ..onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isPreviewPlaying = false);
        });
      if (_isPreviewPlaying) {
        await player.pause();
        if (mounted) setState(() => _isPreviewPlaying = false);
      } else {
        await player.play(DeviceFileSource(note.path));
        if (mounted) setState(() => _isPreviewPlaying = true);
      }
    } catch (error) {
      _showVoiceError('Could not play the recording: $error');
    }
  }

  Future<void> _removeVoiceNote() async {
    await _previewPlayer?.stop();
    await _deleteRecording(_voiceNote?.path);
    if (mounted) {
      setState(() {
        _voiceNote = null;
        _isPreviewPlaying = false;
      });
    }
  }

  /// Deletes a file this recorder is writing or has just written. The path
  /// always comes from the recorder itself, never from a file the user picked.
  Future<void> _deleteOwnRecording(String? path) async {
    if (path == null) return;
    appRecordedPaths.add(path);
    await _deleteRecording(path);
  }

  /// Deletes a recording this app made. Never used on files the user picked.
  Future<void> _deleteRecording(String? path) async {
    if (path == null || !appRecordedPaths.remove(path)) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  String _formatSeconds(int total) {
    final minutes = total ~/ 60;
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildRecordingBar(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record, color: colors.error, size: 14),
          const SizedBox(width: 6),
          Text(
            _formatSeconds(_recordSeconds),
            style: TextStyle(
              color: colors.error,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recording...',
              style: TextStyle(color: colors.textHint, fontSize: 12),
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            onPressed: _cancelVoiceRecording,
            icon: Icon(Icons.close_rounded, color: colors.textHint),
          ),
          IconButton(
            tooltip: 'Stop recording',
            visualDensity: VisualDensity.compact,
            iconSize: 22,
            onPressed: _finishVoiceRecording,
            icon: Icon(Icons.stop_circle_rounded, color: colors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePreviewBar(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 4, right: 4),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _togglePreviewPlayback,
                borderRadius: BorderRadius.circular(16),
                child: Icon(
                  _isPreviewPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatSeconds(_recordSeconds),
                style: TextStyle(color: colors.textPrimary, fontSize: 12),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _removeVoiceNote,
                borderRadius: BorderRadius.circular(16),
                child: Icon(
                  Icons.close_rounded,
                  color: colors.textHint,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> addFiles(List<XFile> newFiles) async {
    final validFiles = <XFile>[];
    for (final file in newFiles) {
      try {
        final length = await file.length();
        if (length > 20 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File ${file.name} exceeds 20MB limit.')),
            );
          }
          continue;
        }
        validFiles.add(file);
      } catch (e) {
        validFiles.add(file);
      }
    }
    setState(() {
      _pendingFiles.addAll(validFiles);
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) return;
    final picked = result.files
        .where((PlatformFile f) => f.path != null)
        .map(
          (PlatformFile f) =>
              XFile(f.path!, name: f.name, mimeType: f.extension),
        )
        .toList();
    await addFiles(picked);
  }

  void _removeFile(int index) {
    setState(
      () => _pendingFiles = List<XFile>.of(_pendingFiles)..removeAt(index),
    );
  }

  Future<void> _handlePaste() async {
    final reader = await SystemClipboard.instance?.read();
    if (reader == null || !reader.canProvide(Formats.png)) return;

    reader.getFile(Formats.png, (file) async {
      final stream = file.getStream();
      final bytesBuilder = <int>[];
      await for (final chunk in stream) {
        bytesBuilder.addAll(chunk);
      }
      final bytes = Uint8List.fromList(bytesBuilder);
      if (bytes.isNotEmpty) {
        addFiles([
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'Pasted Image.png',
          ),
        ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A user or org change replaces the store; follow it.
    ref.listen(dmDraftStoreProvider, (_, next) => _drafts = next);
    ref.listen(
      dmConversationActionsProvider.select(
        (actions) => actions.deletedIds.contains(widget.channelId),
      ),
      (_, deleted) {
        if (!deleted) return;
        _channelDeleted = true;
        _draftSaveDebounce?.cancel();
      },
    );

    final mainColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mentionSuggestions.isNotEmpty)
          MentionSuggestionList(
            suggestions: _mentionSuggestions,
            query: _mentionQuery,
            colors: colors,
            onSelect: _insertMention,
          ),

        if (_showEmojiPicker)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: DmEmojiPicker(
                onEmojiSelected: _insertEmoji,
                onClose: () => setState(() => _showEmojiPicker = false),
              ),
            ),
          ),

        if (_isEditMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            color: colors.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.edit, size: 14, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Editing message',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _exitEditMode,
                  child: Text(
                    'Cancel (Esc)',
                    style: TextStyle(color: colors.textHint, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _isEditMode ? colors.primary : colors.primary,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      ToolbarButton(
                        icon: Icons.format_bold,
                        tooltip: 'Bold (Ctrl+B)',
                        onTap: _insertBold,
                        colors: colors,
                        isActive: _isBold,
                      ),
                      ToolbarButton(
                        icon: Icons.format_italic,
                        tooltip: 'Italic (Ctrl+I)',
                        onTap: _insertItalic,
                        colors: colors,
                        isActive: _isItalic,
                      ),
                      ToolbarButton(
                        icon: Icons.strikethrough_s,
                        tooltip: 'Strikethrough',
                        onTap: _insertStrikethrough,
                        colors: colors,
                        isActive: _isStrikethrough,
                      ),
                      ToolbarButton(
                        icon: Icons.link_rounded,
                        tooltip: 'Link',
                        onTap: _insertLink,
                        colors: colors,
                      ),
                      ToolbarButton(
                        icon: Icons.code_rounded,
                        tooltip: 'Inline code',
                        onTap: _insertCode,
                        colors: colors,
                        isActive: _isCode,
                      ),
                      ToolbarButton(
                        icon: Icons.format_quote_rounded,
                        tooltip: 'Block quote',
                        onTap: _insertQuote,
                        colors: colors,
                      ),
                    ],
                  ),
                ),
                Divider(height: 12, color: colors.divider),
                if (_isRecording) _buildRecordingBar(colors),
                if (_voiceNote != null && !_isRecording)
                  _buildVoicePreviewBar(colors),
                if (_pendingFiles.isNotEmpty)
                  AttachmentPreviewBar(
                    files: _pendingFiles,
                    onRemove: _removeFile,
                    colors: colors,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Focus(
                    onKeyEvent: _handleKeyEvent,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _isEditMode
                            ? 'Editing message…'
                            : 'Message ${widget.recipientName} · '
                                  'Enter to send, Shift+Enter for a new line',
                        hintStyle: TextStyle(
                          color: colors.textHint.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      ToolbarButton(
                        icon: Icons.attach_file_rounded,
                        tooltip: 'Attach file',
                        onTap: _pickFiles,
                        colors: colors,
                        isActive: _pendingFiles.isNotEmpty,
                      ),
                      const SizedBox(width: 2),
                      ToolbarButton(
                        icon: Icons.emoji_emotions_outlined,
                        tooltip: 'Emoji',
                        onTap: _toggleEmojiPicker,
                        colors: colors,
                        isActive: _showEmojiPicker,
                      ),
                      ToolbarButton(
                        icon: Icons.alternate_email_rounded,
                        tooltip: 'Mention someone',
                        onTap: () {
                          final text = _controller.text;
                          final sel = _controller.selection;
                          final pos = sel.isValid
                              ? sel.baseOffset
                              : text.length;
                          final newText =
                              '${text.substring(0, pos)}@${text.substring(pos)}';
                          _controller.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(offset: pos + 1),
                          );
                          _focusNode.requestFocus();
                        },
                        colors: colors,
                      ),
                      ToolbarButton(
                        icon: Icons.tag,
                        tooltip: 'Channel tag',
                        onTap: () {
                          final text = _controller.text;
                          final sel = _controller.selection;
                          final pos = sel.isValid
                              ? sel.baseOffset
                              : text.length;
                          final newText =
                              '${text.substring(0, pos)}#${text.substring(pos)}';
                          _controller.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(offset: pos + 1),
                          );
                          _focusNode.requestFocus();
                        },
                        colors: colors,
                      ),
                      ToolbarButton(
                        icon: Icons.horizontal_rule_rounded,
                        tooltip: 'Divider',
                        onTap: _insertDivider,
                        colors: colors,
                      ),
                      const SizedBox(width: 4),
                      ToolbarButton(
                        icon: _isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                        tooltip: _isRecording
                            ? 'Stop recording'
                            : 'Voice message',
                        onTap: _toggleVoiceRecording,
                        colors: colors,
                        isActive: _isRecording || _voiceNote != null,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _handleSend,
                        child: Icon(
                          Icons.send_rounded,
                          color: _controller.text.trim().isEmpty
                              ? colors.textHint.withValues(alpha: 0.55)
                              : colors.primary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return DropTarget(
      onDragDone: (detail) {
        addFiles(detail.files);
        setState(() => _isDragging = false);
      },
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      child: Stack(
        children: [
          mainColumn,
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: colors.primary.withValues(alpha: 0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Drop files to attach',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
