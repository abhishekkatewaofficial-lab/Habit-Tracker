import 'package:flutter/material.dart';

/// Returns true when the device is likely an iPad (shortest side ≥ 600 pt).
bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

/// The maximum content width used on iPad to keep a premium, non-stretched look.
const double kTabletMaxWidth = 600.0;

/// Wraps [child] in a centered, max-width constraint on iPad.
/// On iPhone the child passes through unchanged.
class AdaptiveBody extends StatelessWidget {
  final Widget child;

  /// Extra horizontal padding applied only on tablet to add breathing room.
  final double tabletHorizontalPadding;

  const AdaptiveBody({
    super.key,
    required this.child,
    this.tabletHorizontalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    if (!isTablet) return child;

    return Container(
      width: double.infinity,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: tabletHorizontalPadding > 0
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: tabletHorizontalPadding),
                  child: child,
                )
              : child,
        ),
      ),
    );
  }
}

/// Convenience wrapper for [SingleChildScrollView] content that should be
/// adaptive — centers and constrains on iPad, no-op on iPhone.
class AdaptiveScrollBody extends StatelessWidget {
  final Widget child;

  const AdaptiveScrollBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    if (!isTablet) return child;

    return Container(
      width: double.infinity,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: child,
      ),
    );
  }
}
