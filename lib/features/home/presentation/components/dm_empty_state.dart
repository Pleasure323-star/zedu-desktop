import 'package:zedu/core/core.dart';

/// Shown on the right of the DMs tab when no conversation is selected.
class DmEmptyState extends StatelessWidget {
  const DmEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 123,
                height: 123,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/svgs/dm_empty_chat.svg',
                  width: 60,
                  height: 56,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your messages',
                textAlign: TextAlign.center,
                style: context.textTheme.headlineMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Select a conversation from the list to start messaging.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: colors.sidebar.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
