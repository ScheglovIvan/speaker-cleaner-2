import 'package:apphud/apphud.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../apphud_config.dart';

/// The single source of subscription pricing for the whole app.
///
/// Every price the UI prints — on the paywall (0001), the premium lock screens
/// and the onboarding offer — comes from the SAME Apphud placement product the
/// purchase goes through. Nothing here is ever a literal: until the store
/// answers, screens omit the price instead of printing a fixed one (a paywall
/// showing the store price while another screen shows a stale hardcoded one is
/// a review-rejection trigger and a refund magnet).
///
/// The readers below all go through `dynamic`: the `apphud` package does not
/// export its model classes, and the store product hangs off the wrapper as
/// `skProduct` (iOS) or `productDetails` (Android). A shape difference degrades
/// to an empty string rather than crashing.

/// The underlying store product for [product], or `null` when absent.
dynamic storeProductOf(dynamic product) {
  final dynamic p = product;
  try {
    final dynamic sk = p.skProduct;
    if (sk != null) return sk;
  } catch (_) {
    // Not an iOS product wrapper.
  }
  try {
    final dynamic details = p.productDetails;
    if (details != null) return details;
  } catch (_) {
    // No store product attached.
  }
  return null;
}

/// Whether the store product carries an introductory (free-trial) offer.
bool hasIntroductoryOffer(dynamic product) {
  final dynamic sp = storeProductOf(product);
  if (sp == null) return false;
  for (final read in <dynamic Function()>[
    () => sp.introductoryPrice,
    () => sp.introductoryOfferDetails,
    () => sp.subscriptionOfferDetails,
    () => sp.freeTrialPeriod,
  ]) {
    try {
      final dynamic value = read();
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      if (value is List && value.isEmpty) continue;
      return true;
    } catch (_) {
      // Try the next field name.
    }
  }
  return false;
}

/// The product identifier as the store reports it (empty when unavailable).
String productIdOf(dynamic product) {
  final dynamic p = product;
  for (final read in <String Function()>[
    () => '${p.productId}',
    () => '${p.id}',
  ]) {
    try {
      final value = read();
      if (value.isNotEmpty && value != 'null') return value;
    } catch (_) {
      // Try the next field name.
    }
  }
  return '';
}

/// Localized price exactly as the store reports it (never composed by hand
/// beyond prefixing the store's own currency symbol). Empty when unknown.
String priceStringOf(dynamic product) {
  final dynamic sp = storeProductOf(product);
  if (sp == null) return '';
  for (final read in <String Function()>[
    () => '${sp.localizedPrice}',
    () => '${sp.priceString}',
    () => '${sp.formattedPrice}',
  ]) {
    try {
      final value = read();
      if (value.isNotEmpty && value != 'null') return value;
    } catch (_) {
      // Try the next field name.
    }
  }
  try {
    final amount = '${sp.price}';
    if (amount.isNotEmpty && amount != 'null') {
      var symbol = '';
      try {
        symbol = '${sp.priceLocale.currencySymbol}';
      } catch (_) {
        symbol = '';
      }
      if (symbol == 'null') symbol = '';
      return '$symbol$amount';
    }
  } catch (_) {
    // No price on this wrapper.
  }
  return '';
}

/// (unit, numberOfUnits) of the subscription period, lowercased.
(String, int) subscriptionPeriodOf(dynamic product) {
  final dynamic sp = storeProductOf(product);
  if (sp == null) return ('', 1);
  var unit = '';
  var count = 1;
  try {
    final dynamic period = sp.subscriptionPeriod;
    if (period != null) {
      unit = '${period.unit}'.toLowerCase();
      final dynamic units = period.numberOfUnits;
      if (units is int) count = units;
    }
  } catch (_) {
    // Not a subscription (or a different wrapper shape).
  }
  return (unit, count < 1 ? 1 : count);
}

/// Human-readable billing period ("Weekly", "Monthly", …) from the store.
String periodLabelOf(dynamic product) {
  final (unit, count) = subscriptionPeriodOf(product);
  if (unit.contains('week') || (unit.contains('day') && count == 7)) {
    return count <= 1 || unit.contains('day') ? 'Weekly' : 'Every $count weeks';
  }
  if (unit.contains('month')) {
    return count <= 1 ? 'Monthly' : 'Every $count months';
  }
  if (unit.contains('year') || unit.contains('annual')) {
    return count <= 1 ? 'Yearly' : 'Every $count years';
  }
  if (unit.contains('day')) {
    return count <= 1 ? 'Daily' : 'Every $count days';
  }

  // Not a subscription (or period unavailable) — fall back to the store title.
  final dynamic sp = storeProductOf(product);
  try {
    final title = '${sp?.localizedTitle}';
    if (title.isNotEmpty && title != 'null') return title;
  } catch (_) {
    // Fall through.
  }
  try {
    final name = '${(product as dynamic).name}';
    if (name.isNotEmpty && name != 'null') return name;
  } catch (_) {
    // Fall through.
  }
  return 'Pro membership';
}

/// The " / week" suffix for a single-unit subscription period ('' otherwise).
String periodSuffixOf(dynamic product) {
  final (unit, count) = subscriptionPeriodOf(product);
  if (count > 1) return '';
  if (unit.contains('week')) return ' / week';
  if (unit.contains('month')) return ' / month';
  if (unit.contains('year')) return ' / year';
  return '';
}

/// The full price line — "$6.99 / week" — or `''` when the store price is not
/// known. Identical on every screen because every screen calls this.
String priceWithPeriodOf(dynamic product) {
  final price = priceStringOf(product);
  if (price.isEmpty) return '';
  return '$price${periodSuffixOf(product)}';
}

/// Loads (once) the headline product of the configured Apphud placement and
/// publishes its price so non-paywall screens can print the real number.
class StorePricing {
  StorePricing._();

  static final StorePricing instance = StorePricing._();

  /// The live price line ("$6.99 / week"), or `null` while the store has not
  /// answered. `null` means "omit the price" — never a hardcoded fallback.
  final ValueNotifier<String?> price = ValueNotifier<String?>(null);

  bool _loading = false;

  /// Fetch the placement's headline product price if it is not known yet.
  /// A failure leaves the price `null` and allows a later retry.
  Future<void> ensureLoaded() async {
    if (price.value != null || _loading) return;
    _loading = true;
    try {
      final product = await _headlineProduct();
      if (product != null) adopt(product);
    } catch (_) {
      // Offline / SDK unavailable (e.g. the web preview) — stay silent and
      // let the screens omit the price.
    } finally {
      _loading = false;
    }
  }

  /// Publish the price of a product the paywall already resolved, so the
  /// paywall and every other screen quote exactly the same figure.
  void adopt(dynamic product) {
    final label = priceWithPeriodOf(product);
    if (label.isNotEmpty && label != price.value) price.value = label;
  }

  Future<dynamic> _headlineProduct() async {
    final placements = await Apphud.placements();
    dynamic match;
    for (final placement in placements) {
      if ('${(placement as dynamic).identifier}' == ApphudConfig.placement) {
        match = placement;
        break;
      }
    }
    // Fall back to whatever the dashboard returns if the id was renamed.
    if (match == null && placements.isNotEmpty) match = placements.first;
    final dynamic paywall = match?.paywall;
    if (paywall == null) return null;
    final dynamic list = paywall.products;
    if (list is! List || list.isEmpty) return null;
    final products = List<dynamic>.from(list);
    final idx = products
        .indexWhere((p) => productIdOf(p) == ApphudConfig.weeklyProductId);
    return products[idx >= 0 ? idx : 0];
  }
}

/// Rebuilds [builder] with the live store price, kicking off the load on mount.
///
/// `price` is `null` until the store answers — callers MUST render a line
/// without a price in that case rather than substituting a literal.
class StorePriceBuilder extends StatefulWidget {
  const StorePriceBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, String? price) builder;

  @override
  State<StorePriceBuilder> createState() => _StorePriceBuilderState();
}

class _StorePriceBuilderState extends State<StorePriceBuilder> {
  @override
  void initState() {
    super.initState();
    // Idempotent: returns immediately once the price is known.
    StorePricing.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorePricing.instance.price,
      builder: (context, price, _) => widget.builder(context, price),
    );
  }
}
