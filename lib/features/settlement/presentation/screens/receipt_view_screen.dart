import 'package:flutter/material.dart';

import 'package:dolo/core/constants/app_colors.dart';
import 'package:dolo/core/constants/app_dimensions.dart';
import 'package:dolo/core/constants/app_typography.dart';

import '../widgets/tactile_ticket_receipt.dart';

class ReceiptViewScreen extends StatelessWidget {
  final String peerId;
  final String peerName;
  final int amountRs; // whole rupees int only
  final String paymentMethod; // 'Cash' or 'Online Transfer'
  final bool isSettled;

  const ReceiptViewScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.amountRs,
    required this.paymentMethod,
    this.isSettled = true,
  });

  static void show(
    BuildContext context, {
    required String peerId,
    required String peerName,
    required int amountRs,
    required String paymentMethod,
    bool isSettled = true,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptViewScreen(
          peerId: peerId,
          peerName: peerName,
          amountRs: amountRs,
          paymentMethod: paymentMethod,
          isSettled: isSettled,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cockpitHeight = constraints.maxHeight * 0.35;
        final sheetTop = cockpitHeight; // sheet starts where cockpit ends

        return Scaffold(
          backgroundColor: surfaceColor,
          body: Stack(
            children: [
              // ── Top 35%: cockpit gradient ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: cockpitHeight + AppDimensions.surfaceSheetRadius,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? const [
                              AppColors.darkCockpitGradientStart,
                              AppColors.darkCockpitGradientEnd,
                            ]
                          : const [
                              AppColors.cockpitGradientStart,
                              AppColors.cockpitGradientEnd,
                            ],
                    ),
                  ),
                ),
              ),

              // ── Bottom 65%: surface sheet ──
              Positioned(
                top: sheetTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.surfaceSheetRadius),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(20, 24, 20, 16),
                            child: TactileTicketReceipt(
                              title: 'Settlement via $paymentMethod',
                              amountRs: amountRs,
                              paidBy: 'You',
                              recipient: peerName,
                              isSettled: isSettled,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: SizedBox(
                            width: double.infinity,
                            height: AppDimensions.ctaHeight,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mint,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.ctaRadius),
                                ),
                              ),
                              child: Text(
                                'Done',
                                style: AppTypography.cardTitle
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Header over the cockpit ──
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Settlement Receipt',
                          textAlign: TextAlign.center,
                          style: AppTypography.cardTitle
                              .copyWith(color: Colors.white),
                        ),
                      ),
                      // Mirrors the close button so the title stays centered.
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
