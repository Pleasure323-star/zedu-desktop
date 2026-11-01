import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class BuyCreditsView extends ConsumerStatefulWidget {
  const BuyCreditsView({super.key});

  @override
  ConsumerState<BuyCreditsView> createState() => _BuyCreditsViewState();
}

class _BuyCreditsViewState extends ConsumerState<BuyCreditsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCredits());
  }

  void _loadCredits() {
    final orgId = ref.read(authNotifierProvider).user?.currentOrg;
    if (orgId != null && orgId.isNotEmpty) {
      ref.read(creditsNotifierProvider.notifier).load(orgId: orgId);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CreditsState>(creditsNotifierProvider, (previous, next) {
      if (next.successMessage != null &&
          previous?.successMessage != next.successMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          AppToastService.show(
            context,
            type: AppToastType.success,
            message: next.successMessage!,
          );
        });
      }
      if (next.error != null && previous?.error != next.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          AppToastService.show(
            context,
            type: AppToastType.error,
            message: next.error!,
          );
        });
      }
    });

    final state = ref.watch(creditsNotifierProvider);
    final authUser = ref.watch(authNotifierProvider).user;
    final balance = ref.watch(orgCreditBalanceProvider);

    return ProfileSettingsShell(
      selectedSection: UserProfileSection.billing,
      onSectionSelected: (section) {
        ref.read(userProfileNotifierProvider.notifier).selectSection(section);
        context.go(AppRouter.profile);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 40, 48),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileSectionHeader(
                  title: 'Billing & Plans',
                  subtitle:
                      'Purchase AI credits for your organization. All plans include AI-powered platform features.',
                  trailing: _BalanceChip(balance: balance),
                ),
                const SizedBox(height: 12),
                Text(
                  'All Plans',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 24),
                if (state.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.packages.isEmpty)
                  Text(
                    state.error ?? 'No AI credit packages available.',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.error,
                    ),
                  )
                else
                  CreditPackagesGrid(
                    packages: state.packages,
                    currentPlanSlug: authUser?.subscriptionPlanId,
                    purchasingPackageId: state.purchasingPackageId,
                    onPurchase: (package) => _onPurchase(context, package),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onPurchase(BuildContext context, CreditPackage package) async {
    if (package.name.toLowerCase() == 'enterprise') {
      AppToastService.show(
        context,
        type: AppToastType.success,
        message: 'Contacting Sales... We will reach out to you shortly!',
      );
      return;
    }

    final user = ref.read(authNotifierProvider).user;
    if (user == null) return;

    final checkout = await ref
        .read(creditsNotifierProvider.notifier)
        .purchasePackage(package: package, email: user.email);

    if (!context.mounted || checkout == null) return;

    final uri = Uri.tryParse(checkout.checkoutSessionUrl);
    if (uri == null) {
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: 'Invalid checkout URL returned by server.',
      );
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched && context.mounted) {
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: 'Could not open payment page automatically.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToastService.show(
          context,
          type: AppToastType.error,
          message: 'Error launching payment page: $e',
        );
      }
    }
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            '$balance AI credits',
            style: context.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
