import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/returnRequestModel.dart';
import '../../providers/returnProvider.dart';
import '../../providers/DarkModeProvider.dart';

// ── Dynamic Colors ─────────────────────────────────────────────────────────
class _Col {
  final bool dark;
  const _Col(this.dark);

  Color get bg       => dark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC);
  Color get card     => dark ? const Color(0xFF242424) : Colors.white;
  Color get cardLight=> dark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F5F9);
  Color get border   => dark ? const Color(0xFF333333) : const Color(0xFFE2E8F0);
  Color get text     => dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSub  => dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get muted    => dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get primary  => const Color(0xFF6366F1);
  Color get primaryT => const Color(0xFF6366F1).withOpacity(0.12);
  Color get accent   => const Color(0xFFF97316);
  Color get success  => const Color(0xFF16A34A);
  Color get successT => const Color(0xFF16A34A).withOpacity(0.12);
  Color get warning  => const Color(0xFFD97706);
  Color get warningT => const Color(0xFFD97706).withOpacity(0.12);
  Color get error    => const Color(0xFFDC2626);
  Color get errorT   => const Color(0xFFDC2626).withOpacity(0.12);
}

TextStyle _poppins(double size, FontWeight w, Color c) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c);

// ─────────────────────────────────────────────────────────────────────────────

/// Shows an existing return request with real-time updates.
///
/// Usage — navigate instead of [CustomerReturnScreen] when a return already
/// exists for the given order:
///
/// ```dart
/// final existing = returnProvider.existingReturnForOrder(order.orderId);
/// if (existing != null) {
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => ReturnStatusScreen(returnRequest: existing),
///   ));
/// } else {
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => CustomerReturnScreen(order: order),
///   ));
/// }
/// ```
///
/// The screen watches [ReturnProvider.myReturns] so any Firestore update
/// (e.g. seller approves/rejects) is reflected instantly without a manual
/// refresh.
class ReturnStatusScreen extends StatelessWidget {
  /// The initial snapshot. The screen immediately looks up the live version
  /// from the provider, so stale data is never displayed.
  final ReturnRequest returnRequest;

  const ReturnStatusScreen({super.key, required this.returnRequest});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<DarkModeProvider>(context).isDarkMode;
    final c = _Col(isDark);

    // Always read the freshest copy from the stream
    final live = context
        .watch<ReturnProvider>()
        .myReturns
        .firstWhere(
          (r) => r.returnId == returnRequest.returnId,
      orElse: () => returnRequest,
    );

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.text),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Return Status', style: _poppins(18, FontWeight.w600, c.text)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusBanner(request: live, c: c),
            const SizedBox(height: 20),
            _Timeline(status: live.status, c: c),
            const SizedBox(height: 20),
            _OrderInfo(request: live, c: c),
            const SizedBox(height: 20),
            _ItemsList(items: live.items, c: c),
            if (live.sellerNote != null && live.sellerNote!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SellerNote(note: live.sellerNote!, c: c),
            ],
            if (live.reason.isNotEmpty) ...[
              const SizedBox(height: 20),
              _ReasonCard(
                reason: live.reason,
                note: live.additionalNote,
                c: c,
              ),
            ],
            if (live.status == ReturnStatus.approved ||
                live.status == ReturnStatus.completed) ...[
              const SizedBox(height: 20),
              _RefundCard(items: live.items, c: c),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Status Banner ─────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final ReturnRequest request;
  final _Col c;
  const _StatusBanner({required this.request, required this.c});

  ({Color bg, Color fg, IconData icon}) _style(ReturnStatus s) {
    switch (s) {
      case ReturnStatus.pending:
        return (bg: c.warningT, fg: c.warning, icon: Icons.hourglass_top_rounded);
      case ReturnStatus.approved:
        return (bg: c.primaryT, fg: c.primary, icon: Icons.thumb_up_rounded);
      case ReturnStatus.processing:
        return (bg: c.primaryT, fg: c.primary, icon: Icons.autorenew_rounded);
      case ReturnStatus.completed:
        return (bg: c.successT, fg: c.success, icon: Icons.check_circle_rounded);
      case ReturnStatus.rejected:
        return (bg: c.errorT,   fg: c.error,   icon: Icons.cancel_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _style(request.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: st.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: st.fg.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: st.fg.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(st.icon, color: st.fg, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.status.label,
                  style: _poppins(17, FontWeight.w700, st.fg),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(request.status),
                  style: _poppins(12, FontWeight.w400, st.fg.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(ReturnStatus s) {
    switch (s) {
      case ReturnStatus.pending:    return 'Waiting for seller review';
      case ReturnStatus.approved:   return 'Seller approved your return';
      case ReturnStatus.processing: return 'Return is being processed';
      case ReturnStatus.completed:  return 'Refund has been issued';
      case ReturnStatus.rejected:   return 'Seller rejected this request';
    }
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────
class _Timeline extends StatelessWidget {
  final ReturnStatus status;
  final _Col c;
  const _Timeline({required this.status, required this.c});

  static const _steps = [
    (ReturnStatus.pending,    'Submitted',   Icons.send_rounded),
    (ReturnStatus.approved,   'Approved',    Icons.thumb_up_rounded),
    (ReturnStatus.processing, 'Processing',  Icons.inventory_2_rounded),
    (ReturnStatus.completed,  'Completed',   Icons.check_circle_rounded),
  ];

  int get _activeIndex {
    // Rejected stays at Pending visually (step 0) but banner shows rejected
    if (status == ReturnStatus.rejected) return 0;
    return _steps.indexWhere((s) => s.$1 == status);
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Timeline', style: _poppins(14, FontWeight.w600, c.text)),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Connector line
                final stepIndex = i ~/ 2;
                final filled = stepIndex < active;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: filled ? c.primary : c.border,
                  ),
                );
              }
              final stepIndex = i ~/ 2;
              final done = stepIndex <= active;
              final step = _steps[stepIndex];
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: done ? c.primary : c.cardLight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: done ? c.primary : c.border,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      step.$3,
                      size: 18,
                      color: done ? Colors.white : c.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.$2,
                    style: _poppins(
                      10, FontWeight.w500,
                      done ? c.primary : c.muted,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Order Info ────────────────────────────────────────────────────────────────
class _OrderInfo extends StatelessWidget {
  final ReturnRequest request;
  final _Col c;
  const _OrderInfo({required this.request, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request Info', style: _poppins(14, FontWeight.w600, c.text)),
          const SizedBox(height: 14),
          _Row('Return ID',   '#${request.returnId.substring(0, 8).toUpperCase()}', c),
          _Row('Order ID',    request.orderId, c),
          _Row('Submitted',   request.submittedDate, c),
          if (request.resolvedDate != null)
            _Row('Resolved', request.resolvedDate!, c),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final _Col c;
  const _Row(this.label, this.value, this.c);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: _poppins(12, FontWeight.w400, c.textSub)),
          ),
          Expanded(
            child: Text(
              value,
              style: _poppins(12, FontWeight.w600, c.text),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Items List ────────────────────────────────────────────────────────────────
class _ItemsList extends StatelessWidget {
  final List<ReturnedItemModel> items;
  final _Col c;
  const _ItemsList({required this.items, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Returned Items (${items.length})',
              style: _poppins(14, FontWeight.w600, c.text)),
          const SizedBox(height: 12),
          ...items.map((item) => _ItemRow(item: item, c: c)),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ReturnedItemModel item;
  final _Col c;
  const _ItemRow({required this.item, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.imageUrl.isNotEmpty
                ? Image.network(item.imageUrl,
                width: 54, height: 54, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: _poppins(13, FontWeight.w600, c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  _tag('Size: ${item.size}', c),
                  const SizedBox(width: 6),
                  _tag('Qty: ${item.pieces}', c),
                ]),
              ],
            ),
          ),
          Text('Rs. ${item.price}',
              style: _poppins(13, FontWeight.w700, c.primary)),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 54, height: 54,
    decoration: BoxDecoration(
        color: c.cardLight, borderRadius: BorderRadius.circular(10)),
    child: Icon(Icons.image_rounded, color: c.muted, size: 22),
  );

  Widget _tag(String text, _Col c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: c.cardLight, borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: _poppins(10, FontWeight.w400, c.textSub)),
  );
}

// ── Seller Note ───────────────────────────────────────────────────────────────
class _SellerNote extends StatelessWidget {
  final String note;
  final _Col c;
  const _SellerNote({required this.note, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.primaryT,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.store_rounded, color: c.primary, size: 16),
            const SizedBox(width: 6),
            Text('Seller Note', style: _poppins(12, FontWeight.w600, c.primary)),
          ]),
          const SizedBox(height: 8),
          Text(note, style: _poppins(13, FontWeight.w400, c.text)),
        ],
      ),
    );
  }
}

// ── Reason Card ───────────────────────────────────────────────────────────────
class _ReasonCard extends StatelessWidget {
  final String reason;
  final String? note;
  final _Col c;
  const _ReasonCard({required this.reason, this.note, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Return Reason', style: _poppins(14, FontWeight.w600, c.text)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.cardLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(reason,
                style: _poppins(12, FontWeight.w500, c.textSub)),
          ),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Note', style: _poppins(12, FontWeight.w500, c.textSub)),
            const SizedBox(height: 4),
            Text(note!, style: _poppins(13, FontWeight.w400, c.text)),
          ],
        ],
      ),
    );
  }
}

// ── Refund Card ───────────────────────────────────────────────────────────────
class _RefundCard extends StatelessWidget {
  final List<ReturnedItemModel> items;
  final _Col c;
  const _RefundCard({required this.items, required this.c});

  int get _total => items.fold(0, (sum, i) => sum + i.price * i.pieces);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.successT,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.monetization_on_rounded, color: c.success, size: 22),
          const SizedBox(width: 10),
          Text('Refund Amount',
              style: _poppins(13, FontWeight.w500, c.success)),
          const Spacer(),
          Text('Rs. $_total',
              style: _poppins(17, FontWeight.w700, c.success)),
        ],
      ),
    );
  }
}