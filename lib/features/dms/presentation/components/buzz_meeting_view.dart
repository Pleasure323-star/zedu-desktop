import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class BuzzMeetingView extends ConsumerStatefulWidget {
  const BuzzMeetingView({super.key});

  @override
  ConsumerState<BuzzMeetingView> createState() => _BuzzMeetingViewState();
}

class _BuzzMeetingViewState extends ConsumerState<BuzzMeetingView> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isHandRaised = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeCall = ref.watch(activeCallProvider);

    if (activeCall.state.status != CallStatus.active) {
      return const SizedBox.shrink();
    }

    final bool isFullPage = activeCall.state.isFullPage;
    final remoteName = activeCall.state.remoteUserName ?? 'Unknown';

    if (!isFullPage) {
      return Positioned(
        top: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buzz Call',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '2 participants',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textHint,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.open_in_full, size: 16),
                        tooltip: 'Open full page',
                        color: colors.textHint,
                        onPressed: () {
                          ref
                              .read(activeCallProvider.notifier)
                              .setFullPage(true);
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildVideoFeed(
                          Colors.green.shade900,
                          'You',
                          null,
                          80,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildVideoFeed(
                          Colors.grey.shade800,
                          remoteName,
                          activeCall.state.remoteAvatarUrl,
                          80,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        tooltip: _isMuted ? 'Unmute' : 'Mute',
                        color: _isMuted
                            ? Colors.red
                            : colors.primary.withValues(alpha: 0.2),
                        onTap: () => setState(() => _isMuted = !_isMuted),
                        small: true,
                      ),
                      const SizedBox(width: 8),
                      _buildControlButton(
                        icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                        tooltip: _isVideoOff
                            ? 'Turn camera on'
                            : 'Turn camera off',
                        color: _isVideoOff
                            ? Colors.red
                            : colors.primary.withValues(alpha: 0.2),
                        onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                        small: true,
                      ),
                      const SizedBox(width: 8),
                      _buildControlButton(
                        icon: Icons.back_hand,
                        tooltip: _isHandRaised ? 'Lower hand' : 'Raise hand',
                        color: _isHandRaised
                            ? Colors.amber
                            : colors.primary.withValues(alpha: 0.2),
                        onTap: () =>
                            setState(() => _isHandRaised = !_isHandRaised),
                        small: true,
                      ),
                      const SizedBox(width: 8),
                      _buildControlButton(
                        icon: Icons.call_end,
                        tooltip: 'Leave call',
                        color: Colors.red,
                        onTap: () {
                          ref.read(activeCallProvider.notifier).endCall();
                        },
                        small: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: colors.background,
      child: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Text(
                  'Buzz Meeting',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.people_outline, size: 16, color: colors.textHint),
                const SizedBox(width: 4),
                Text(
                  '2 participants',
                  style: TextStyle(fontSize: 13, color: colors.textHint),
                ),
                const Spacer(),
                Text(
                  'Full page',
                  style: TextStyle(fontSize: 13, color: colors.textPrimary),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: true,
                  onChanged: (val) {
                    ref.read(activeCallProvider.notifier).setFullPage(false);
                  },
                  activeThumbColor: colors.primary,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: _buildVideoFeed(
                      const Color(0xFF4A2B1D),
                      remoteName,
                      activeCall.state.remoteAvatarUrl,
                      double.infinity,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildVideoFeed(
                      const Color(0xFF1E3A2F),
                      'You',
                      null,
                      double.infinity,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Controls
          Container(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  tooltip: _isMuted ? 'Unmute' : 'Mute',
                  color: _isMuted
                      ? Colors.red
                      : colors.primary.withValues(alpha: 0.2),
                  onTap: () => setState(() => _isMuted = !_isMuted),
                  small: false,
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  icon: Icons.screen_share_outlined,
                  tooltip: 'Share screen',
                  color: colors.primary.withValues(alpha: 0.2),
                  onTap: () => AppToastService.show(
                    context,
                    type: AppToastType.info,
                    message: 'Screen sharing is not available yet.',
                  ),
                  small: false,
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                  tooltip: _isVideoOff ? 'Turn camera on' : 'Turn camera off',
                  color: _isVideoOff
                      ? Colors.red
                      : colors.primary.withValues(alpha: 0.2),
                  onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                  small: false,
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  icon: Icons.back_hand,
                  tooltip: _isHandRaised ? 'Lower hand' : 'Raise hand',
                  color: _isHandRaised
                      ? Colors.amber
                      : colors.primary.withValues(alpha: 0.2),
                  onTap: () => setState(() => _isHandRaised = !_isHandRaised),
                  small: false,
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  icon: Icons.call_end,
                  tooltip: 'Leave call',
                  color: Colors.red,
                  onTap: () {
                    ref.read(activeCallProvider.notifier).endCall();
                  },
                  small: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoFeed(
    Color bgColor,
    String name,
    String? avatarUrl,
    double height,
  ) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF6458F5),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Icon(Icons.person, size: 24, color: Colors.white)
                  : null,
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
    required bool small,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(small ? 6 : 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: small ? 18 : 24),
        ),
      ),
    );
  }
}
