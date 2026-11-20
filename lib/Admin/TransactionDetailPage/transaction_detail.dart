import 'dart:async'; // TimeoutException

import 'package:flutter/material.dart'; //import wedgets
import 'package:flutter/services.dart'; // FilteringTextInputFormatter
// `show DateFormat` = import ONLY DateFormat from intl.
// (intl also has a class named TextDirection, which would clash with
//  Flutter's TextDirection used for right-to-left Arabic text.)
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:provider/provider.dart'; // context.read<TransactionData>()

import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/Models/transaction_types.dart'; // the types list
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:aral_project/Theme/theme.dart';

/// STATEFUL: the fields change while the admin edits, and we show a
/// spinner while saving.
class TransactionDetailPage extends StatefulWidget {
  // The transaction to show is PASSED IN through the constructor
  // (same idea as MovieDetailsPage(movie: movie) in the course).
  const TransactionDetailPage({super.key, required this.transaction});
  //require : must give it a transaction to open it

  final TransactionModel
  transaction; //The transaction it received; it never changes

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

//The _ at the start makes it private to this file.
class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final _formKey = GlobalKey<FormState>();
  //A remote control for the form. With it we can say “check all fields now”

  // TextEditingController = holds (and lets us read/change) a field's text.
  // `late final` = created in initState (we need widget.transaction first).
  late final TextEditingController _locationCtrl;
  late final TextEditingController _qtyCtrl;

  late String _direction; // 'IN' or 'OUT' (the SegmentedButton)
  // transaction type CODE (e.g. 'issue_out').
  // String? (nullable): it becomes null = "nothing chosen" when the admin
  // switches IN ↔ OUT, so he MUST pick a type of the new direction.
  String? _type;
  late String _originalType; // the type when the page opened (normalized)

  bool _isSaving = false; // true while waiting for Firebase

  // NEW (item info): the item's row in `items`, loaded when the page opens.
  // It gives us the Arabic name, the LIVE stock and the weight.
  // null while loading, or if the item wasn't found.
  ItemRow? _itemRow;
  bool _loadingItem = true; // true until the item lookup finishes
  String? _locationError;

  // Shortcut: `widget.transaction` → the transaction passed in.
  // (`widget` gives the State access to its StatefulWidget's fields.)
  TransactionModel get tx => widget.transaction;

  // -------------------------------------------------------------------
  // initState: runs ONCE when the page opens → fill the fields.
  // -------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _locationCtrl = TextEditingController(text: tx.locationCode);
    _qtyCtrl = TextEditingController(text: tx.quantity.toString());
    _direction = tx.direction;
    // normalizeType: turns old values like "Purchase Receipt" into a code
    // ('purchase_receipt') that matches the direction.
    _originalType = normalizeType(tx.type, tx.direction);
    _type = _originalType;
    _loadItem(); // start loading the item info (doesn't block the page)
  }

  /// Loads this transaction's item row from Firebase.
  /// NEW DB: directly by itemId → items/<itemId − 1> (no search).
  /// `async` → runs in the background; the page shows "…" meanwhile.
  Future<void> _loadItem() async {
    try {
      // context.read is allowed here: it reads the provider once,
      // without listening for changes.
      final row = await context.read<TransactionData>().itemFor(tx);
      if (!mounted) return; // the page was closed while we were waiting
      setState(() => _itemRow = row);
    } catch (_) {
      // No internet / error → we just show "—" in the chips.
    } finally {
      if (mounted) setState(() => _loadingItem = false);
    }
  }

  // dispose: free the controllers when the page closes (avoid memory leaks).
  // Rule: our things first, super.dispose() LAST.
  @override
  void dispose() {
    _locationCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  /// Did the admin change anything? (compare the fields with the original)
  bool get _hasChanges =>
      _locationCtrl.text.trim().toUpperCase() != tx.locationCode ||
      _qtyCtrl.text.trim() != tx.quantity.toString() ||
      _direction != tx.direction ||
      _type != _originalType;

  // ===================================================================
  // SAVE
  // ===================================================================
  Future<void> _save() async {
    // 1) Nothing changed → just close.
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    // 2) Local checks (format, numbers) → validator functions below.
    setState(() {
      _locationError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final newLocation = _locationCtrl.text.trim().toUpperCase();
    final newQty = int.parse(_qtyCtrl.text.trim()); // safe: validated above

    // context.read = get the provider WITHOUT listening (it's an action).
    final provider = context.read<TransactionData>();

    setState(() => _isSaving = true); // show spinner on the button

    try {
      // 3) Firebase checks — only for what CHANGED.
      // The PRODUCT can't be changed any more (locked field), so we only
      // check the location here.
      if (newLocation != tx.locationCode &&
          !await provider.locationExists(newLocation)) {
        setState(() => _locationError = 'This location doesn\'t exist');
        return;
      }

      // 4) Build the updated transaction (copyWith = updated copy).
      final updated = tx.copyWith(
        locationCode: newLocation,
        quantity: newQty,
        direction: _direction,
        // `!` = "not null here": the validator above already blocked
        // saving while no type was chosen.
        type: _type!, // the chosen type code
      );

      // 5) Save through the provider (transaction + stock, atomic).
      //    .timeout: don't wait forever if there's no internet.
      await provider
          .updateTransaction(original: tx, updated: updated)
          .timeout(const Duration(seconds: 10));

      // `mounted` = is this page still on screen? (the user may have left
      // during the await). Using context after leaving would crash.
      if (!mounted) return;
      _showMessage('Changes saved');
      Navigator.pop(context); // back to the list (already updated)
    } on InsufficientStockException catch (e) {
      // NO NEGATIVE STOCK: the save was blocked, nothing was written.
      _showMessage(e.message, isError: true);
    } on TimeoutException {
      _showMessage(
        'No connection. The change will be sent when you\'re back online.',
      );
    } catch (e) {
      _showMessage('Couldn\'t save. Try again.', isError: true);
    } finally {
      // finally ALWAYS runs (success, error, or return) → stop the spinner.
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===================================================================
  // REVERSE (A4)
  // ===================================================================

  /// The reverse popup (design B). Returns true if the admin confirms.
  /// showDialog returns a Future that completes with the value given to
  /// Navigator.pop(context, value).
  Future<bool> _confirmReverse() async {
    // Stock before → after, so the admin SEES what will change.
    // The reversal does the opposite of the original:
    //   original OUT 11 (−11) → reversal IN 11 (+11)
    // `?.` = only if the item was loaded (else null → no preview).
    final stockNow = _itemRow?.quantity;
    final stockAfter = stockNow == null ? null : stockNow - tx.stockEffect;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ReverseDialog(
        transaction: tx,
        stockNow: stockNow,
        stockAfter: stockAfter,
      ),
    );
    return ok ?? false; // tapped outside → don't reverse
  }

  Future<void> _reverse() async {
    // Unsaved edits? Reverse uses the SAVED values, so ask to save first.
    if (_hasChanges) {
      _showMessage('Save or cancel your changes before reversing.');
      return;
    }
    if (!await _confirmReverse()) return; // admin tapped Cancel
    if (!mounted) return;

    final provider = context.read<TransactionData>();
    setState(() => _isSaving = true); // disables the buttons

    try {
      await provider
          .reverseTransaction(
            original: tx,
            reversedBy: 'Admin', // TODO: the logged-in admin (after Login)
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      _showMessage('Transaction #${tx.transactionId} reversed');
      Navigator.pop(context); // back to the list (already updated)
    } on InsufficientStockException catch (e) {
      // NO NEGATIVE STOCK: the reversal was blocked, nothing was written.
      _showMessage(e.message, isError: true);
    } on TimeoutException {
      _showMessage(
        'No connection. The reversal will be sent when you\'re back online.',
      );
    } catch (e) {
      _showMessage('Couldn\'t reverse. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    // ScaffoldMessenger shows a SnackBar (small message at the bottom).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppTheme.errorColor : null,
      ),
    );
  }

  // ===================================================================
  // LEAVING WITH UNSAVED CHANGES
  // ===================================================================
  /// Shows "Discard changes?" and returns true if the admin confirms.
  /// showDialog returns a Future: it completes with the value passed to
  /// Navigator.pop(context, value) inside the dialog.
  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits to this transaction will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false; // null (tapped outside) → don't discard
  }

  Future<void> _cancel() async {
    if (!_hasChanges || await _confirmDiscard()) {
      if (mounted) Navigator.pop(context);
    }
  }

  // ===================================================================
  // UI
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = _direction == 'IN';
    // locked = reversed, or this row IS a reversal → nothing can be edited
    final locked = tx.reversed || tx.isReversal;
    final readOnly = locked || _isSaving;

    // PopScope controls the phone's BACK button/gesture:
    // canPop: false when there are unsaved changes → we ask first.
    return PopScope(
      canPop: !_hasChanges || locked,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // already closed, nothing to do
        if (await _confirmDiscard() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Text('Transaction #${tx.numericId}'),
          // `actions` = widgets on the RIGHT side of the app bar.
          // The reverse icon shows only if the transaction can be reversed.
          actions: [
            if (!locked)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ReverseIconButton(
                  // null = disabled while saving / reversing
                  onPressed: _isSaving ? null : _reverse,
                ),
              ),
          ],
        ),

        // The form scrolls, so the keyboard never hides a field.
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            // Re-check fields as the user types (after the first attempt).
            autovalidateMode: AutovalidateMode.onUserInteraction,
            // onChanged on the Form: rebuild so _hasChanges is up to date
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cream banner for locked transactions.
                // We pass only the short TITLE; the widget adds " · read only".
                if (tx.reversed) const _ReversedBanner(title: 'Reversed'),
                if (tx.isReversal)
                  _ReversedBanner(
                    title: 'Reversal of #${tx.reversalOf ?? '—'}',
                  ),
                _SummaryCard(transaction: tx),
                const SizedBox(height: 20),

                // ============ SECTION 1: RECORD (read only) ============
                // Who logged it + when, side by side (two equal halves).
                const _SectionTitle('RECORD · READ ONLY'),
                Row(
                  children: [
                    Expanded(
                      child: _ReadOnlyField(
                        icon: Icons.person_outline,
                        label: 'Logged by',
                        // isEmpty → show a dash instead of a blank box
                        value: tx.stockKeeperId.isEmpty
                            ? '—'
                            : tx.stockKeeperId,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ReadOnlyField(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        // toLocal(): Firebase saves UTC → show Amman time
                        value: DateFormat(
                          'd MMM y, HH:mm',
                        ).format(tx.timestamp.toLocal()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ============ SECTION 2: ITEM (read only) ============
                // Grey card + lock icon → "information, you can't change it".
                const _SectionTitle('ITEM · READ ONLY'),
                _ItemCard(
                  // The code comes from the items table (via itemId).
                  // If the list didn't fill it, use the row we just loaded.
                  itemCode: tx.itemCode.isNotEmpty
                      ? tx.itemCode
                      : (_itemRow?.code ?? (_loadingItem ? '…' : '—')),
                  // Length · In stock · Total weight (live stock from items)
                  chips: _ItemInfoChips(
                    length: _formatLength(_itemRow?.length ?? tx.length),
                    stock: _loadingItem
                        ? '…'
                        : (_itemRow == null
                              ? '—'
                              : '${_itemRow!.quantity} pcs'),
                    weight: _loadingItem
                        ? '…'
                        : (_itemRow == null
                              ? '—'
                              : '${NumberFormat('#,##0.#').format(_itemRow!.totalWeightKg)} kg'),
                  ),
                ),
                const SizedBox(height: 20),

                // ============ SECTION 3: MOVEMENT (editable) ============
                // White card: ONLY the fields the admin can change.
                _SectionTitle(locked ? 'MOVEMENT' : 'MOVEMENT · EDITABLE'),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------------- IN / OUT ----------------
                      // SegmentedButton<String>: a row of options, one selected.
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'IN',
                            icon: Icon(Icons.arrow_downward),
                            label: Text('IN · Store'),
                          ),
                          ButtonSegment(
                            value: 'OUT',
                            icon: Icon(Icons.arrow_upward),
                            label: Text('OUT · Withdraw'),
                          ),
                        ],
                        selected: {_direction}, // a Set with the selected value
                        // null onSelectionChanged = disabled (when read-only)
                        onSelectionChanged: readOnly
                            ? null
                            : (s) => setState(() {
                                _direction = s.first;
                                // Back to the ORIGINAL direction → give back
                                // the original type (nothing to choose).
                                // Otherwise → EMPTY the type (null), so the
                                // admin must choose one; Save shows an error
                                // until he does (design A).
                                _type = _direction == tx.direction
                                    ? _originalType
                                    : null;
                              }),
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: isIn
                              ? AppTheme.successColor.withValues(alpha: 0.15)
                              : AppTheme.errorColor.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---------------- Quantity ----------------
                      const _FieldLabel('Quantity'),
                      TextFormField(
                        controller: _qtyCtrl,
                        readOnly: readOnly,
                        keyboardType: TextInputType.number, // number keyboard
                        // Only digits can be typed (no letters, dots or minus).
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                          suffixText: 'pcs',
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n <= 0) {
                            return 'Enter a number above 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ---------------- Transaction type ----------------
                      const _FieldLabel('Transaction type'),
                      // Directionality(rtl) = lay this field out right-to-left,
                      // so the Arabic text and the arrow sit on the right sides.
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: DropdownButtonFormField<String>(
                          // key: when the direction (or type) changes, Flutter
                          // rebuilds this field so it shows the new list/value.
                          key: ValueKey('$_direction-$_type'),
                          initialValue: _type, // the code, or null = empty
                          isExpanded: true, // long Arabic labels don't overflow
                          // hint = grey text shown while nothing is chosen
                          hint: const Text('اختر نوع الحركة'),
                          // Runs when Save calls _formKey...validate():
                          // empty → red border + this message, no save.
                          validator: (v) =>
                              v == null ? 'Choose a type for $_direction' : null,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          // value = the CODE (saved), child = the Arabic LABEL.
                          // A reversal / retired type is added so the current
                          // value is always in the list.
                          items:
                              [
                                    ...typesFor(_direction),
                                    if (_type == kReversalType.code)
                                      kReversalType,
                                    // `_type != null &&` first: isRetiredType
                                    // needs a real code, not null.
                                    if (_type != null && isRetiredType(_type!))
                                      typeByCode(_type!)!,
                                  ]
                                  .map(
                                    (t) => DropdownMenuItem<String>(
                                      value: t.code,
                                      child: Text(t.label),
                                    ),
                                  )
                                  .toList(),
                          // null onChanged = disabled (read-only / saving)
                          onChanged: (readOnly || _type == kReversalType.code)
                              ? null
                              : (code) {
                                  if (code != null) {
                                    setState(() => _type = code);
                                  }
                                },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---------------- Location ----------------
                      const _FieldLabel('Location'),
                      TextFormField(
                        controller: _locationCtrl,
                        readOnly: readOnly,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          hintText: 'WH1-B3-02',
                          errorText: _locationError,
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim().toUpperCase();
                          // RegExp: WH<digits>-<letter><digits>-<2 digits>
                          if (!RegExp(r'^WH\d+-[A-Z]\d+-\d{2}$').hasMatch(s)) {
                            return 'Format: WH1-B3-02';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                // "Last edited …" line, only if it was edited before.
                // (Only the admin edits, so we show WHEN, not who.)
                // `...[ ]` (spread) adds several widgets at once.
                if (tx.editedAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Last edited · '
                    '${DateFormat('d MMM y, HH:mm').format(tx.editedAt!.toLocal())}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),

        // ---------------- Bottom buttons (stay fixed) ----------------
        bottomNavigationBar: locked
            ? null // locked → nothing to save
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _cancel,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          // ternary: spinner while saving, ✓ otherwise
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(_isSaving ? 'Saving…' : 'Save changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// =====================================================================
// Small private widgets (extracted to keep build() readable)
// =====================================================================

/// The green (IN) / red (OUT) card at the top (design B):
///        ↑ OUT · WITHDRAW
///            −11 pcs
/// Only the movement — who/when is in RECORD, the type is in MOVEMENT.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIn = t.direction == 'IN';
    final color = isIn ? AppTheme.successColor : AppTheme.errorColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Small line: arrow + "OUT · WITHDRAW"
          Row(
            // min = the Row is only as wide as its children → centred
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                isIn ? 'IN · STORE' : 'OUT · WITHDRAW',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Big number. Text.rich → "−11" big + " pcs" smaller, one line.
          Text.rich(
            TextSpan(
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
              children: [
                TextSpan(
                  text: '${isIn ? '+' : '−'}${t.quantity}',
                  style: const TextStyle(fontSize: 32),
                ),
                const TextSpan(text: ' pcs', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A grey read-only box: icon + small label + value (RECORD section).
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // same grey as the item card
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textColorSecondary),
          const SizedBox(width: 8),
          // Expanded: the text takes the rest of the width; a long name
          // ends with "…" (ellipsis) instead of overflowing.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textColorSecondary,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColorPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small grey label above each field ("Product", "Location", …).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// Small cream banner at the top of a locked transaction (A4).
/// Shows: ↶  **Reversed** · read only
class _ReversedBanner extends StatelessWidget {
  const _ReversedBanner({required this.title});

  final String title; // the bold part, e.g. 'Reversed'

  @override
  Widget build(BuildContext context) {
    // textTheme = the text styles from our design system (bodyMedium, etc.)
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      // symmetric = same left/right (12) and same top/bottom (10)
      // → a slimmer box than before (it was 12 on all sides).
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer, // soft cream
        border: Border.all(color: AppTheme.warningBorder), // thin line
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // A smaller icon (default is 24) so it doesn't shout.
          const Icon(Icons.undo, size: 18, color: AppTheme.warningColor),
          const SizedBox(width: 8),
          Expanded(
            // Text.rich = ONE text with several styles inside it.
            // Each TextSpan is a piece of the sentence.
            child: Text.rich(
              TextSpan(
                // base style for all pieces: bodyMedium in dark amber
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.warningColor,
                ),
                children: [
                  // piece 1: the title in semi-bold
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  // piece 2: normal weight
                  const TextSpan(text: ' · read only'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small grey title above a section: "ITEM · READ ONLY", "ACTIONS"…
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8, // a bit of space between letters → "label" look
          color: AppTheme.textColorSecondary,
        ),
      ),
    );
  }
}

/// A white rounded card with a thin border (the editable section).
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: child,
    );
  }
}

/// The GREY read-only card: item code + lock icon, then the 3 chips.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.itemCode, required this.chips});
  final String itemCode;
  final Widget chips; // the Length · In stock · Total weight row

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // light grey = "read only"
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, color: AppTheme.textColorSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  itemCode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColorPrimary,
                  ),
                ),
              ),
              // lock = "can't be changed"
              const Icon(
                Icons.lock_outline,
                size: 18,
                color: AppTheme.textColorSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          chips,
        ],
      ),
    );
  }
}

/// The round orange "reverse" icon in the app bar (top right).
class _ReverseIconButton extends StatelessWidget {
  const _ReverseIconButton({required this.onPressed});

  /// What happens on tap. null → disabled (greyed out).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // IconButton.outlined = an icon with a round border around it.
    // tooltip = the hint shown on long-press (phone) or hover (browser).
    return IconButton.outlined(
      onPressed: onPressed,
      tooltip: 'Reverse transaction',
      icon: const Icon(Icons.undo),
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.secondaryColor, // burnt orange
        backgroundColor: AppTheme.secondaryContainer, // light peach
        side: const BorderSide(color: AppTheme.secondaryColor, width: 1.5),
      ),
    );
  }
}

/// The reverse popup (design B): what it does + stock now → after.
/// Returns true (Navigator.pop(context, true)) when the admin confirms.
class _ReverseDialog extends StatelessWidget {
  const _ReverseDialog({
    required this.transaction,
    required this.stockNow,
    required this.stockAfter,
  });

  final TransactionModel transaction;
  final int? stockNow; // null → the item couldn't be loaded (no preview)
  final int? stockAfter;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    // The reversal goes the OTHER way: OUT 11 is undone by IN +11.
    final reversalIsIn = t.oppositeDirection == 'IN';
    final moveColor = reversalIsIn
        ? AppTheme.successColor
        : AppTheme.errorColor;
    // Not enough stock to undo an IN → we block it here already
    // (the provider blocks it too: InsufficientStockException).
    final notEnough = stockAfter != null && stockAfter! < 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // ---- title: icon + "Reverse transaction #1" ----
      title: Row(
        children: [
          const Icon(Icons.undo, color: AppTheme.secondaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text('Reverse transaction #${t.numericId}')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min, // only as tall as its content
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This undoes the movement by adding the opposite '
            'transaction. Nothing is deleted.',
            style: TextStyle(color: AppTheme.textColorSecondary),
          ),
          // The preview only if we know the stock.
          if (stockNow != null && stockAfter != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                // spaceBetween: first item left, last right, middle centred
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StockNumber(label: 'Stock now', value: stockNow!),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${t.oppositeDirection} '
                        '${reversalIsIn ? '+' : '−'}${t.quantity}',
                        style: TextStyle(
                          color: moveColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16, color: moveColor),
                    ],
                  ),
                  _StockNumber(
                    label: 'After',
                    value: stockAfter!,
                    color: notEnough ? AppTheme.errorColor : moveColor,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Warning line: why it's blocked, or that it will be locked.
          Row(
            children: [
              Icon(
                notEnough ? Icons.error_outline : Icons.lock_outline,
                size: 16,
                color: notEnough
                    ? AppTheme.errorColor
                    : AppTheme.secondaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  notEnough
                      ? 'Not enough stock to reverse this.'
                      : 'Transaction #${t.numericId} will be locked after this.',
                  style: TextStyle(
                    fontSize: 12,
                    color: notEnough
                        ? AppTheme.errorColor
                        : AppTheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          // The buttons are INSIDE the content (not in `actions`):
          // a Row with Expanded inside AlertDialog.actions gets an
          // unlimited width and crashes ("unbounded width").
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  // null = disabled when there isn't enough stock
                  onPressed: notEnough
                      ? null
                      : () => Navigator.pop(context, true),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Yes, reverse'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor, // orange
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Stock now / 114" — small label with a big number under it.
class _StockNumber extends StatelessWidget {
  const _StockNumber({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textColorSecondary,
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color ?? AppTheme.textColorPrimary,
          ),
        ),
      ],
    );
  }
}

/// Shows a length nicely: 6.3 → "6.3", 6.0 → "6", 0 (missing) → "—".
/// toStringAsFixed(0) = the number with no decimals.
String _formatLength(double length) {
  if (length <= 0) return '—'; // old transactions may have no length
  if (length == length.roundToDouble()) return '${length.toStringAsFixed(0)} m';
  return '$length m';
}

/// One row of 3 equal chips: Length · In stock · Total weight.
class _ItemInfoChips extends StatelessWidget {
  const _ItemInfoChips({
    required this.length,
    required this.stock,
    required this.weight,
  });

  final String length;
  final String stock;
  final String weight;

  @override
  Widget build(BuildContext context) {
    // Row + Expanded: each chip gets an EQUAL third of the width,
    // so the three always sit side by side (never wrap to a new line).
    return Row(
      children: [
        Expanded(
          child: _InfoChip(label: 'Length', value: length),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InfoChip(
            label: 'In stock',
            value: stock,
            valueColor: AppTheme.successColor, // green → easy to spot
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InfoChip(label: 'Total weight', value: weight),
        ),
      ],
    );
  }
}

/// A small box: grey label on top, bold value below.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor; // optional: null → normal text color

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textColorSecondary,
            ),
          ),
          const SizedBox(height: 2),
          // FittedBox(scaleDown): if the value is too long for the chip
          // (e.g. "12,345.6 kg"), the text shrinks a little instead of
          // overflowing or cutting off.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textColorPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}