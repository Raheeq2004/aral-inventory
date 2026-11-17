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
  late String _type; // transaction type CODE (e.g. 'issue_out')
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

  /// Loads this transaction's item row (code + length) from Firebase.
  /// `async` → runs in the background; the page shows "…" meanwhile.
  Future<void> _loadItem() async {
    try {
      // context.read is allowed here: it reads the provider once,
      // without listening for changes.
      final row = await context.read<TransactionData>().findItem(
        tx.itemCode,
        tx.length,
      );
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
        type: _type, // the chosen type code
      );

      // 5) Save through the provider (transaction + stock, atomic).
      //    .timeout: don't wait forever if there's no internet.
      await provider
          .updateTransaction(
            original: tx,
            updated: updated,
            editedBy:
                'Admin', // TODO: use the logged-in admin's name (after Login)
          )
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

  /// The confirmation dialog. Returns true if the admin taps "Reverse".
  /// showDialog returns a Future that completes with the value given to
  /// Navigator.pop(context, value).
  Future<bool> _confirmReverse() async {
    // The reversal's sign: an IN of 20 is undone by −20, an OUT by +20.
    final sign = tx.direction == 'IN' ? '−' : '+';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.undo),
        title: const Text('Reverse this transaction?'),
        content: Text(
          'An opposite transaction ($sign${tx.quantity} pcs) will be added '
          'to undo #${tx.transactionId}. The original stays in the logs.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.undo),
            label: const Text('Reverse'),
          ),
        ],
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
          title: Text('Transaction #${tx.transactionId ?? ''}'),
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

                // ============ SECTION 1: ITEM (read only) ============
                // Grey card + lock icon → "information, you can't change it".
                const _SectionTitle('ITEM · READ ONLY'),
                _ItemCard(
                  itemCode: tx.itemCode,
                  // Length · In stock · Total weight (live stock from items)
                  chips: _ItemInfoChips(
                    length: _formatLength(tx.length),
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

                // ============ SECTION 2: MOVEMENT (editable) ============
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
                                // The type must belong to the new direction.
                                // If it doesn't, pick the default type for it.
                                if (!typesFor(_direction)
                                    .any((t) => t.code == _type)) {
                                  _type = defaultTypeFor(_direction);
                                }
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
                          initialValue: _type, // the selected type code
                          isExpanded: true, // long Arabic labels don't overflow
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
                                    if (isRetiredType(_type))
                                      typeByCode(_type)!,
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

                // "Last edited by …" line, only if it was edited before.
                // (Who logged it is already in the summary card at the top.)
                if (tx.editedBy != null && tx.editedAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Last edited by ${tx.editedBy} · '
                    '${DateFormat('d MMM y, HH:mm').format(tx.editedAt!.toLocal())}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],

                // ============ SECTION 3: ACTIONS (reverse) ============
                // Only when the transaction CAN be reversed (not locked).
                // `...[ ]` (spread) adds several widgets at once.
                if (!locked) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('ACTIONS'),
                  _ReverseCard(
                    // null = disabled while saving/reversing
                    onPressed: _isSaving ? null : _reverse,
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

/// The green (IN) / red (OUT) card at the top: "IN • +20 pieces".
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isIn = t.direction == 'IN';
    final color = isIn ? AppTheme.successColor : AppTheme.errorColor;
    final date = DateFormat('d MMM y, HH:mm').format(t.timestamp.toLocal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.direction} • ${isIn ? '+' : '−'}${t.quantity} pieces',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                // The type in Arabic (e.g. استلام مشتريات), from transaction_types.dart
                Text(
                  typeLabel(t.type, t.direction),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  'Logged by ${t.stockKeeperId} • $date',
                  style: Theme.of(context).textTheme.bodySmall,
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

/// The peach "Reverse this transaction" card at the end of the page.
class _ReverseCard extends StatelessWidget {
  const _ReverseCard({required this.onPressed});

  /// What happens on tap. null → the button is disabled (greyed out).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5), // soft peach
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reverse this transaction',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Adds an opposite entry to undo it. The original stays in the log.',
            style: TextStyle(fontSize: 13, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(height: 12),
          // OutlinedButton in orange: visible, but not as strong as Save.
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.undo),
            label: const Text('Reverse'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.secondary, // burnt orange text + icon
              side: BorderSide(color: scheme.secondary, width: 1.5),
              backgroundColor: AppTheme.surfaceColor,
            ),
          ),
        ],
      ),
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
        Expanded(child: _InfoChip(label: 'Length', value: length)),
        const SizedBox(width: 8),
        Expanded(
          child: _InfoChip(
            label: 'In stock',
            value: stock,
            valueColor: AppTheme.successColor, // green → easy to spot
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _InfoChip(label: 'Total weight', value: weight)),
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