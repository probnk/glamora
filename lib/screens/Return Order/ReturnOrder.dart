import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/returnRequestModel.dart';
import '../../providers/returnProvider.dart';
import '../../providers/DarkModeProvider.dart';

// ── Dynamic Colors ────────────────────────────────────────────────────────────
class _Col {
  final bool dark;
  const _Col(this.dark);

  Color get bg        => dark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC);
  Color get card      => dark ? const Color(0xFF242424) : Colors.white;
  Color get cardLight => dark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F5F9);
  Color get border    => dark ? const Color(0xFF333333) : const Color(0xFFE2E8F0);
  Color get text      => dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSub   => dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get muted     => dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get primary   => const Color(0xFF6366F1);
  Color get primaryT  => const Color(0xFF6366F1).withOpacity(0.1);
  Color get accent    => const Color(0xFFF97316);
  Color get success   => const Color(0xFF16A34A);
  Color get successT  => const Color(0xFF16A34A).withOpacity(0.1);
}

TextStyle _poppins(double size, FontWeight w, Color c) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c);

// ─────────────────────────────────────────────────────────────────────────────

class CustomerReturnScreen extends StatefulWidget {
  final dynamic order;
  const CustomerReturnScreen({super.key, required this.order});

  @override
  State<CustomerReturnScreen> createState() => _CustomerReturnScreenState();
}

class _CustomerReturnScreenState extends State<CustomerReturnScreen> {
  final Map<int, int> _selectedQty = {};
  String _reason = 'Damaged / Defective';
  final _noteCtrl = TextEditingController();

  final _reasons = [
    'Damaged / Defective',
    'Wrong item received',
    'Does not fit',
    'Changed my mind',
    'Item not as described',
    'Other',
  ];

  List get _cartItems => widget.order.cartItems as List;
  bool get _hasSelection => _selectedQty.isNotEmpty;

  int get _totalRefund {
    int total = 0;
    _selectedQty.forEach((idx, qty) {
      final item     = _cartItems[idx];
      final price    = item.price    as int;
      final discount = item.discount as int;
      final discounted = (price - (price * discount / 100)).round();
      total += discounted * qty;
    });
    return total;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!_hasSelection) {
      _snack(context, 'Select at least one item to return');
      return;
    }

    final provider = context.read<ReturnProvider>();
    final order    = widget.order;

    final List<ReturnedItemModel> returnItems = [];
    _selectedQty.forEach((idx, qty) {
      final item = _cartItems[idx];
      returnItems.add(ReturnedItemModel(
        productId: item.id    as String,
        title:     item.title as String,
        imageUrl:  (item.photoUrl as List<String>).isNotEmpty
            ? (item.photoUrl as List<String>).first
            : '',
        size:   item.size as String,
        color:  item.colorHex.value.toRadixString(16),
        pieces: qty,
        price:  item.price as int,
      ));
    });

    final userDetails = order.userDetails;
    final success = await provider.submitReturn(
      orderId:        order.orderId         as String,
      uid:            order.uid             as String,
      customerName:   userDetails.fullName  as String,
      customerEmail:  userDetails.email     as String,
      customerPhone:  userDetails.phoneNumber as String,
      items:          returnItems,
      reason:         _reason,
      additionalNote: _noteCtrl.text.trim().isEmpty
          ? null
          : _noteCtrl.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      _showSuccessDialog(context);
    } else {
      _snack(context, provider.error ?? 'Failed to submit return');
    }
  }

  void _snack(BuildContext context, String msg) {
    final isDark = Provider.of<DarkModeProvider>(context, listen: false).isDarkMode;
    final c = _Col(isDark);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _poppins(13, FontWeight.w500, c.text)),
      backgroundColor: c.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessDialog(BuildContext context) {
    final isDark = Provider.of<DarkModeProvider>(context, listen: false).isDarkMode;
    final c = _Col(isDark);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: c.successT, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded,
                  color: c.success, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Return Submitted!',
                style: _poppins(18, FontWeight.w700, c.text)),
            const SizedBox(height: 8),
            Text(
              'Your return request has been submitted. The seller will review it shortly.',
              textAlign: TextAlign.center,
              style: _poppins(13, FontWeight.w400, c.textSub),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('Done',
                  style: _poppins(15, FontWeight.w600, Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Provider.of<DarkModeProvider>(context).isDarkMode;
    final c        = _Col(isDark);
    final provider = context.watch<ReturnProvider>();
    final order    = widget.order;

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
        title: Text('Return Items',
            style: _poppins(18, FontWeight.w600, c.text)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OrderBanner(
                    orderId:   order.orderId   as String,
                    orderDate: order.orderDate as String,
                    c: c,
                  ),
                  const SizedBox(height: 20),

                  Text('Select Items to Return',
                      style: _poppins(14, FontWeight.w600, c.text)),
                  const SizedBox(height: 10),
                  ..._cartItems.asMap().entries.map((e) {
                    final idx    = e.key;
                    final item   = e.value;
                    final maxQty = item.pieces as int;
                    final selQty = _selectedQty[idx];
                    return _ReturnItemTile(
                      item:        item,
                      maxQty:      maxQty,
                      selectedQty: selQty,
                      c:           c,
                      onToggle: () => setState(() {
                        if (_selectedQty.containsKey(idx)) {
                          _selectedQty.remove(idx);
                        } else {
                          _selectedQty[idx] = 1;
                        }
                      }),
                      onQtyChanged: (q) =>
                          setState(() => _selectedQty[idx] = q),
                    );
                  }),

                  const SizedBox(height: 20),

                  Text('Return Reason',
                      style: _poppins(14, FontWeight.w600, c.text)),
                  const SizedBox(height: 10),
                  _ReasonSelector(
                    reasons:   _reasons,
                    selected:  _reason,
                    c:         c,
                    onChanged: (v) => setState(() => _reason = v),
                  ),

                  const SizedBox(height: 20),

                  Text('Additional Note (Optional)',
                      style: _poppins(14, FontWeight.w600, c.text)),
                  const SizedBox(height: 10),
                  _NoteField(controller: _noteCtrl, c: c),

                  const SizedBox(height: 20),

                  if (_hasSelection) _RefundEstimate(amount: _totalRefund, c: c),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          _BottomBar(
            hasSelection: _hasSelection,
            isLoading:    provider.isSubmitting,
            c:            c,
            onSubmit:     () => _submit(context),
          ),
        ],
      ),
    );
  }
}

// ── Order Banner ──────────────────────────────────────────────────────────────
class _OrderBanner extends StatelessWidget {
  final String orderId, orderDate;
  final _Col c;
  const _OrderBanner(
      {required this.orderId, required this.orderDate, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.primaryT,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: c.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orderId,
                    style: _poppins(13, FontWeight.w600, c.primary)),
                Text(orderDate,
                    style: _poppins(11, FontWeight.w400, c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Return Item Tile ──────────────────────────────────────────────────────────
class _ReturnItemTile extends StatelessWidget {
  final dynamic item;
  final int maxQty;
  final int? selectedQty;
  final _Col c;
  final VoidCallback onToggle;
  final ValueChanged<int> onQtyChanged;

  const _ReturnItemTile({
    required this.item,
    required this.maxQty,
    required this.selectedQty,
    required this.c,
    required this.onToggle,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedQty != null;
    final imageUrls  = item.photoUrl as List<String>;
    final price      = item.price    as int;
    final discount   = item.discount as int;
    final finalPrice = (price - (price * discount / 100)).round();

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? c.primaryT : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? c.primary : c.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: isSelected ? c.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? c.primary : c.muted,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),

            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrls.isNotEmpty
                  ? Image.network(
                imageUrls.first,
                width: 60, height: 60, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title as String,
                      style: _poppins(13, FontWeight.w600, c.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    _tag('Size: ${item.size}', c),
                    const SizedBox(width: 6),
                    _tag('Qty: $maxQty', c),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('Rs. $finalPrice',
                        style: _poppins(13, FontWeight.w700, c.primary)),
                    if (discount > 0) ...[
                      const SizedBox(width: 6),
                      Text('Rs. $price',
                          style: _poppins(11, FontWeight.w400, c.muted)
                              .copyWith(
                              decoration: TextDecoration.lineThrough)),
                    ],
                  ]),
                ],
              ),
            ),

            // Stepper
            if (isSelected && maxQty > 1)
              _QtyStepper(
                  qty: selectedQty!, max: maxQty, c: c, onChanged: onQtyChanged),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(
        color: c.cardLight, borderRadius: BorderRadius.circular(10)),
    child: Icon(Icons.image_rounded, color: c.muted, size: 24),
  );

  Widget _tag(String text, _Col c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: c.cardLight, borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: _poppins(10, FontWeight.w400, c.textSub)),
  );
}

// ── Qty Stepper ───────────────────────────────────────────────────────────────
class _QtyStepper extends StatelessWidget {
  final int qty, max;
  final _Col c;
  final ValueChanged<int> onChanged;

  const _QtyStepper(
      {required this.qty,
        required this.max,
        required this.c,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove, qty > 1 ? () => onChanged(qty - 1) : null),
        SizedBox(
          width: 28,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: _poppins(13, FontWeight.w600, c.text)),
        ),
        _btn(Icons.add, qty < max ? () => onChanged(qty + 1) : null),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: onTap != null ? c.primary : c.cardLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon,
          size: 14,
          color: onTap != null ? Colors.white : c.muted),
    ),
  );
}

// ── Reason Selector ───────────────────────────────────────────────────────────
class _ReasonSelector extends StatelessWidget {
  final List<String> reasons;
  final String selected;
  final _Col c;
  final ValueChanged<String> onChanged;

  const _ReasonSelector(
      {required this.reasons,
        required this.selected,
        required this.c,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: reasons.map((r) {
        final isSel = r == selected;
        return GestureDetector(
          onTap: () => onChanged(r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color:  isSel ? c.primary : c.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSel ? c.primary : c.border),
            ),
            child: Text(r,
                style: _poppins(12, FontWeight.w500,
                    isSel ? Colors.white : c.textSub)),
          ),
        );
      }).toList(),
    );
  }
}

// ── Note Field ────────────────────────────────────────────────────────────────
class _NoteField extends StatelessWidget {
  final TextEditingController controller;
  final _Col c;
  const _NoteField({required this.controller, required this.c});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 3,
      style: _poppins(13, FontWeight.w400, c.text),
      decoration: InputDecoration(
        hintText: 'Describe the issue...',
        hintStyle: _poppins(13, FontWeight.w400, c.muted),
        filled: true,
        fillColor: c.card,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.primary, width: 1.5)),
      ),
    );
  }
}

// ── Refund Estimate ───────────────────────────────────────────────────────────
class _RefundEstimate extends StatelessWidget {
  final int amount;
  final _Col c;
  const _RefundEstimate({required this.amount, required this.c});

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
          Icon(Icons.monetization_on_rounded, color: c.success, size: 20),
          const SizedBox(width: 10),
          Text('Estimated Refund',
              style: _poppins(13, FontWeight.w500, c.success)),
          const Spacer(),
          Text('Rs. $amount',
              style: _poppins(16, FontWeight.w700, c.success)),
        ],
      ),
    );
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final bool hasSelection, isLoading;
  final _Col c;
  final VoidCallback onSubmit;

  const _BottomBar({
    required this.hasSelection,
    required this.isLoading,
    required this.c,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: hasSelection ? c.primary : c.cardLight,
            foregroundColor: hasSelection ? Colors.white : c.muted,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: hasSelection && !isLoading ? onSubmit : null,
          child: isLoading
              ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Text('Submit Return Request',
              style: _poppins(15, FontWeight.w600,
                  hasSelection ? Colors.white : c.muted)),
        ),
      ),
    );
  }
}