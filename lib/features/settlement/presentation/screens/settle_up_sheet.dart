import 'package:flutter/material.dart';
import 'package:dolo/core/utils/money.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/image_compressor_helper.dart';
import '../../domain/models/settlement_bill.dart';
import '../providers/settle_up_provider.dart';
import 'receipt_view_screen.dart';

class SettleUpSheet extends ConsumerWidget {
  final String peerId;
  final String peerName;

  const SettleUpSheet({
    super.key,
    required this.peerId,
    required this.peerName,
  });

  static Future<void> show(
    BuildContext context, {
    required String peerId,
    required String peerName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SettleUpSheet(peerId: peerId, peerName: peerName),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootContext = context;
    final state = ref.watch(settleUpProvider(peerId));
    final notifier = ref.read(settleUpProvider(peerId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXL)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _SheetHeader(peerName: peerName),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Counter-debt offset banner (if any)
                    if (state.counterDebtOffset > 0)
                      _CounterDebtBanner(offset: state.counterDebtOffset),

                    // Bill checklist
                    const _SectionLabel('Outstanding bills'),
                    const SizedBox(height: 8),
                    ...state.bills.map((bill) => _BillCheckTile(
                          bill: bill,
                          onToggle: () => notifier.toggleBill(bill.id),
                        )),
                    const SizedBox(height: 20),

                    // Payment method toggle
                    const _SectionLabel('How are you paying?'),
                    const SizedBox(height: 8),
                    _PaymentMethodToggle(
                      selected: state.paymentMethod,
                      onChanged: notifier.setPaymentMethod,
                    ),
                    const SizedBox(height: 16),

                    // Wallet quick launchers (online only)
                    if (state.paymentMethod == PaymentMethod.online) ...[
                      const _SectionLabel('Pay with'),
                      const SizedBox(height: 10),
                      const _WalletLaunchersRow(),
                      const SizedBox(height: 20),
                    ],

                    // Receipt attachment
                    _AttachReceiptPill(
                      imagePath: state.receiptImagePath,
                      onAttach: () async {
                        final path = await ImageCompressorHelper.pickAndCompressImage(
                          source: ImageSource.gallery,
                        );
                        if (path != null) notifier.setReceiptImage(path);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Summary row
                    _SummaryRow(netRs: state.netPayableRs),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // CTA
              _ConfirmCTA(
                netRs: state.netPayableRs,
                onConfirm: () {
                  HapticFeedback.mediumImpact();
                  final amount = state.netPayableRs;
                  final method = state.paymentMethod == PaymentMethod.cash
                      ? 'Cash'
                      : 'Online Transfer';
                  Navigator.pop(context);
                  ReceiptViewScreen.show(
                    rootContext,
                    peerId: peerId,
                    peerName: peerName,
                    amountRs: amount,
                    paymentMethod: method,
                    isSettled: true,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final String peerName;
  const _SheetHeader({required this.peerName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.mintSquircleBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.handshake_rounded, color: AppColors.mintTextLight, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settle up',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text('with $peerName',
                  style: const TextStyle(fontSize: 13, color: AppColors.textLightMuted)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _CounterDebtBanner extends StatelessWidget {
  final int offset;
  const _CounterDebtBanner({required this.offset});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mintSquircleBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.mint.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.mint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Counter-debt offset: -Rs $offset applied automatically',
              style: const TextStyle(
                  color: AppColors.mintTextLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textLightMuted),
      ),
    );
  }
}

class _BillCheckTile extends StatelessWidget {
  final SettlementBill bill;
  final VoidCallback onToggle;
  const _BillCheckTile({required this.bill, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(
            color: bill.isSelected
                ? AppColors.mint.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: bill.isSelected ? AppColors.mint : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      bill.isSelected ? AppColors.mint : AppColors.lightBorder,
                  width: 2,
                ),
              ),
              child: bill.isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.description,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    '${bill.date.day}/${bill.date.month}/${bill.date.year}',
                    style: const TextStyle(
                        color: AppColors.textLightMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              formatRs(bill.amountRs),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: bill.isSelected
                    ? AppColors.roseTextLight
                    : AppColors.textLightMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodToggle extends StatelessWidget {
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;
  const _PaymentMethodToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MethodChip(
          icon: Icons.payments_outlined,
          label: 'Cash',
          isSelected: selected == PaymentMethod.cash,
          onTap: () => onChanged(PaymentMethod.cash),
        ),
        const SizedBox(width: 10),
        _MethodChip(
          icon: Icons.phone_iphone_rounded,
          label: 'Online',
          isSelected: selected == PaymentMethod.online,
          onTap: () => onChanged(PaymentMethod.online),
        ),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _MethodChip(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.mint : AppColors.lightPillInactive,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textLightMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected ? Colors.white : AppColors.textLightPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletLaunchersRow extends StatelessWidget {
  const _WalletLaunchersRow();

  // Each wallet keeps a recognisable colour on a neutral wallet icon.
  static const _wallets = [
    (name: 'SadaPay', color: Color(0xFF7C3AED), scheme: 'sadapay://'),
    (name: 'NayaPay', color: Color(0xFF16A34A), scheme: 'nayapay://'),
    (name: 'Easypaisa', color: Color(0xFFEA580C), scheme: 'easypaisa://'),
    (name: 'JazzCash', color: Color(0xFFDC2626), scheme: 'jazzcash://'),
  ];

  Future<void> _launch(String scheme) async {
    final uri = Uri.parse(scheme);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: _wallets
              .map((w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _WalletButton(
                        color: w.color,
                        name: w.name,
                        onTap: () => _launch(w.scheme),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        _CopyRaastRow(),
      ],
    );
  }
}

class _WalletButton extends StatelessWidget {
  final Color color;
  final String name;
  final VoidCallback onTap;
  const _WalletButton(
      {required this.color, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lightBackground,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.account_balance_wallet_rounded,
                  size: 18, color: color),
            ),
            const SizedBox(height: 4),
            Text(name,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _CopyRaastRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(const ClipboardData(text: '03001234567'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Raast ID copied!'),
              duration: Duration(seconds: 2)),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.mintSquircleBg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border:
              Border.all(color: AppColors.mint.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.copy_rounded, color: AppColors.mint, size: 18),
            SizedBox(width: 10),
            Text('Copy Raast ID to pay manually',
                style: TextStyle(
                    color: AppColors.mintTextLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _AttachReceiptPill extends StatelessWidget {
  final String? imagePath;
  final VoidCallback onAttach;
  const _AttachReceiptPill(
      {required this.imagePath, required this.onAttach});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAttach,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: AppColors.lightBorder, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              imagePath != null
                  ? Icons.check_circle_rounded
                  : Icons.attach_file_rounded,
              color: imagePath != null
                  ? AppColors.mint
                  : AppColors.textLightMuted,
            ),
            const SizedBox(width: 8),
            Text(
              imagePath != null
                  ? 'Payment screenshot attached ✓'
                  : 'Attach payment screenshot',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: imagePath != null
                    ? AppColors.mintTextLight
                    : AppColors.textLightMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int netRs;
  const _SummaryRow({required this.netRs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mintSquircleBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('You pay',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.mintTextLight)),
          ),
          Text(
            formatRs(netRs),
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.mintTextLight),
          ),
        ],
      ),
    );
  }
}

class _ConfirmCTA extends StatelessWidget {
  final int netRs;
  final VoidCallback onConfirm;
  const _ConfirmCTA({required this.netRs, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mint,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusLG)),
              elevation: 0,
            ),
            child: Text(
              'Confirm & send slip  •  ${formatRs(netRs)}',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
