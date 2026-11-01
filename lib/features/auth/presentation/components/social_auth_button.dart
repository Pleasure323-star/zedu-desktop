import 'package:zedu/core/core.dart';

class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final button = AppButton.outlined(
      label: label,
      onPressed: onPressed,
      loading: loading,
      leading: SvgPicture.asset(icon, width: 16, height: 16),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: context.colors.borderOutline, width: 1),
        foregroundColor: context.colors.textPrimary,
        textStyle: context.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
    if (!loading) return button;

    // The spinner replaces the label while loading; keep it for screen readers.
    return MergeSemantics(
      child: Semantics(label: '$label, loading', child: button),
    );
  }
}
