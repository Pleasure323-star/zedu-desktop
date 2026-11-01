import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class CreditPackagesGrid extends StatelessWidget {
  const CreditPackagesGrid({
    super.key,
    required this.packages,
    required this.currentPlanSlug,
    required this.onPurchase,
    this.purchasingPackageId,
  });

  final List<CreditPackage> packages;
  final String? currentPlanSlug;
  final void Function(CreditPackage package) onPurchase;
  final String? purchasingPackageId;

  Color _getColorForPackage(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('free')) return const Color(0xFFD1D5DB);
    if (lower.contains('pro plus')) return const Color(0xFFF59E0B);
    if (lower.contains('pro')) return const Color(0xFF22C55E);
    if (lower.contains('business')) return const Color(0xFF8B5CF6);
    if (lower.contains('enterprise')) return const Color(0xFF0EA5E9);
    return const Color(0xFF8B5CF6);
  }

  List<CreditPackage> get _displayPackages {
    final defaultPackages = [
      const CreditPackage(
        id: 'free',
        name: 'Free',
        description: 'Perfect for individuals',
        price: 0,
        credits: 0,
        benefits: [
          'Create your own AI Co Workers',
          'Unlimited AI Co Workers',
          'AI Credits purchasable',
          '1 hour maximum call duration',
          'Up to 5 buzz participants',
          'Up to 5 active calls per workspace',
        ],
        planSlug: 'free',
      ),
      const CreditPackage(
        id: 'pro',
        name: 'Pro',
        description: 'Ideal for growing learners',
        price: 20,
        credits: 5000,
        benefits: [
          'Create your own AI Co Workers',
          'Unlimited AI Co Workers',
          'AI Credits purchasable',
          '1 hour maximum call duration',
          'Up to 50 buzz participants',
          'Up to 50 active calls per workspace',
          'Advanced controls for administrator only',
        ],
        planSlug: 'pro',
      ),
      const CreditPackage(
        id: 'business',
        name: 'Business',
        description: 'Designed for organizations',
        price: 50,
        credits: 15000,
        benefits: [
          'Create your own AI Co Workers',
          'Unlimited AI Co Workers',
          'AI Credits purchasable',
          'Unlimited call duration',
          'Up to 1500 buzz participants',
          'Up to 1500 active calls per workspace',
          'Call records and transcript available',
          'Advanced controls for administrator only',
        ],
        planSlug: 'business',
      ),
      const CreditPackage(
        id: 'pro_plus',
        name: 'Pro Plus',
        description: 'Built for advanced learning teams',
        price: 100,
        credits: 35000,
        benefits: [
          'Create your own AI Co Workers',
          'Unlimited AI Co Workers',
          'AI Credits purchasable',
          '1 hour maximum call duration',
          'Up to 500 buzz participants',
          'Up to 500 active calls per workspace',
          'Advanced controls for administrator only',
          'Call records available',
        ],
        planSlug: 'pro_plus',
      ),
      const CreditPackage(
        id: 'enterprise',
        name: 'Enterprise',
        description: 'Tailored for large institutions',
        price: 0,
        credits: 100000,
        benefits: [
          'Create your own AI Co Workers',
          'Unlimited AI Co Workers',
          'AI Credits purchasable',
          'Unlimited call duration',
          'Unlimited buzz participants',
          'Up to 1000 active calls per workspace',
          'Call records and transcript available',
          'Advanced controls for every user',
        ],
        planSlug: 'enterprise',
      ),
    ];

    return defaultPackages.map((uiPkg) {
      // Find matching package from API to get the correct real ID for purchases
      final apiMatch = packages.where((p) {
        final slug = p.planSlug?.toLowerCase() ?? p.name.toLowerCase();
        if (uiPkg.name == 'Pro Plus') {
          return slug.contains('pro_plus') ||
              slug.contains('pro plus') ||
              slug.contains('pro-plus');
        }
        if (uiPkg.name == 'Pro') {
          return slug.contains('pro') && !slug.contains('plus');
        }
        if (uiPkg.name == 'Business') {
          return slug.contains('business');
        }
        if (uiPkg.name == 'Enterprise') {
          return slug.contains('enterprise');
        }
        return false;
      }).firstOrNull;

      return CreditPackage(
        id: apiMatch?.id ?? uiPkg.id,
        name: uiPkg.name,
        description: uiPkg.description,
        price: uiPkg.price,
        credits: uiPkg.credits,
        benefits: uiPkg.benefits,
        planSlug: uiPkg.planSlug,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _displayPackages;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        mainAxisExtent: 520, // Increased to fit the longest benefits list
      ),
      itemBuilder: (context, index) {
        final package = items[index];
        return CreditPackageCard(
          package: package,
          accentColor: _getColorForPackage(package.name),
          isCurrentPlan: _isCurrentPlan(package),
          isLoading: purchasingPackageId == package.id,
          onPurchase: package.isFree ? null : () => onPurchase(package),
        );
      },
    );
  }

  bool _isCurrentPlan(CreditPackage package) {
    final slug = package.planSlug;
    if (slug == null || currentPlanSlug == null) {
      return package.isFree &&
          (currentPlanSlug == null || currentPlanSlug == 'free');
    }
    return slug == currentPlanSlug;
  }
}
