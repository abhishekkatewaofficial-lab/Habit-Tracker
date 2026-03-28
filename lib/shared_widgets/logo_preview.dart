import 'package:flutter/material.dart';
import 'premium_app_logo.dart';

/// A developer widget to preview the [PremiumAppLogo] across all variants.
class LogoPreviewScreen extends StatelessWidget {
  const LogoPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium Logo Preview')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogoRow('Premium Green', AppLogoStyle.premiumGreen),
              const SizedBox(height: 48),
              _buildLogoRow('Deep Blue', AppLogoStyle.deepBlue),
              const SizedBox(height: 48),
              _buildLogoRow('Monochrome', AppLogoStyle.monochrome),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoRow(String label, AppLogoStyle style) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                const Text('Mini (48)'),
                const SizedBox(height: 8),
                PremiumAppLogo(size: 48, style: style),
              ],
            ),
            Column(
              children: [
                const Text('Standard (120)'),
                const SizedBox(height: 8),
                PremiumAppLogo(size: 120, style: style),
              ],
            ),
            Column(
              children: [
                const Text('App Icon (180)'),
                const SizedBox(height: 8),
                PremiumAppLogo(size: 180, style: style),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
