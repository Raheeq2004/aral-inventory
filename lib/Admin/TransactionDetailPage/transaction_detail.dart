
import 'dart:async'; // TimeoutException
import 'package:flutter/material.dart';//import wedgets
import 'package:flutter/services.dart'; // FilteringTextInputFormatter
// `show DateFormat` = import ONLY DateFormat from intl.
// (intl also has a class named TextDirection, which would clash with
//  Flutter's TextDirection used for right-to-left Arabic text.)
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';// context.read<TransactionData>()
 
import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:aral_project/Theme/theme.dart';
 
/// STATEFUL: the fields change while the admin edits, and we show a
/// spinner while saving.
class TransactionDetailPage extends StatefulWidget {
  // The transaction to show is PASSED IN through the constructor
  // (same idea as MovieDetailsPage(movie: movie) in the course). 
  const TransactionDetailPage({super.key, required this.transaction});
 //require : must give it a transaction to open it

  final TransactionModel transaction;//The transaction it received; it never changes
 
  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}
 
 //The _ at the start makes it private to this file.
class _TransactionDetailPageState extends State<TransactionDetailPage> {

  final _formKey = GlobalKey<FormState>();
  //A remote control for the form. With it we can say “check all fields now”
 
  // TextEditingController = holds (and lets us read/change) a field's text.
  // `late final` = created in initState (we need widget.transaction first).
  late final TextEditingController _itemCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _qtyCtrl;
 
  late String _direction; // 'IN' or 'OUT' (the SegmentedButton)
  late String _itemName; // shown under the product field
 
  bool _isSaving = false; // true while waiting for Firebase
  String? _itemError; // error text from the Firebase checks
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
    _itemCtrl = TextEditingController(text: tx.itemCode);
    _locationCtrl = TextEditingController(text: tx.locationCode);
    _qtyCtrl = TextEditingController(text: tx.quantity.toString());
    _direction = tx.direction;
    _itemName = tx.itemName;
  }
 
  // dispose: free the controllers when the page closes (avoid memory leaks).
  // Rule: our things first, super.dispose() LAST.
  @override
  void dispose() {
    _itemCtrl.dispose();
    _locationCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }
 
  /// Did the admin change anything? (compare the fields with the original)
  bool get _hasChanges =>
      _itemCtrl.text.trim() != tx.itemCode ||
      _locationCtrl.text.trim().toUpperCase() != tx.locationCode ||
      _qtyCtrl.text.trim() != tx.quantity.toString() ||
      _direction != tx.direction;
 
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
      _itemError = null;
      _locationError = null;
    });
    if (!_formKey.currentState!.validate()) return;
 
    final newItem = _itemCtrl.text.trim();
    final newLocation = _locationCtrl.text.trim().toUpperCase();
    final newQty = int.parse(_qtyCtrl.text.trim()); // safe: validated above
 
    // context.read = get the provider WITHOUT listening (it's an action).
    final provider = context.read<TransactionData>();
 
    setState(() => _isSaving = true); // show spinner on the button
 
    try {
      // 3) Firebase checks — only for what CHANGED.
      String newItemName = _itemName;
      if (newItem != tx.itemCode) {
        final item = await provider.findItem(newItem);
        if (item == null) {
          setState(() => _itemError = 'No product with this code');
          return; // `finally` below still runs and stops the spinner
        }
        newItemName = (item['name'] ?? newItem).toString();
      }
      if (newLocation != tx.locationCode &&
          !await provider.locationExists(newLocation)) {
        setState(() => _locationError = 'This location doesn\'t exist');
        return;
      }
 
      // 4) Build the updated transaction (copyWith = updated copy).
      final updated = tx.copyWith(
        itemCode: newItem,
        itemName: newItemName,
        locationCode: newLocation,
        quantity: newQty,
        direction: _direction,
      );
 
      // 5) Save through the provider (transaction + stock, atomic).
      //    .timeout: don't wait forever if there's no internet.
      await provider
          .updateTransaction(
            original: tx,
            updated: updated,
            editedBy: 'Admin', // TODO: use the logged-in admin's name (after Login)
          )
          .timeout(const Duration(seconds: 10));
 
      // `mounted` = is this page still on screen? (the user may have left
      // during the await). Using context after leaving would crash.
      if (!mounted) return;
      _showMessage('Changes saved');
      Navigator.pop(context); // back to the list (already updated)
    } on TimeoutException {
      _showMessage('No connection. The change will be sent when you\'re back online.');
    } catch (e) {
      _showMessage('Couldn\'t save. Try again.', isError: true);
    } finally {
      // finally ALWAYS runs (success, error, or return) → stop the spinner.
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
    final readOnly = tx.reversed || _isSaving; // reversed → can't edit
 
    // PopScope controls the phone's BACK button/gesture:
    // canPop: false when there are unsaved changes → we ask first.
    return PopScope(
      canPop: !_hasChanges || tx.reversed,
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
          actions: [
            // ↩ Reverse (A4). TODO: open the reverse dialog in A4.
            IconButton(
              tooltip: 'Reverse transaction',
              icon: const Icon(Icons.undo),
              onPressed: null, // null = disabled until A4 is built
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
                if (tx.reversed) _ReversedBanner(),
                _SummaryCard(transaction: tx),
                const SizedBox(height: 20),
 
                // ---------------- Product ----------------
                const _FieldLabel('Product'),
                TextFormField(
                  controller: _itemCtrl,
                  readOnly: readOnly,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.qr_code_2),
                    hintText: 'Item code',
                    errorText: _itemError, // from the Firebase check
                  ),
                  // validator: returns an error text, or null if OK.
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter the item code' : null,
                ),
                const SizedBox(height: 6),
                // Arabic names → right-to-left so mixed text reads correctly.
                Text(
                  _itemName,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium,
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
                    // RegExp = a text pattern: WH<digit>-<letter><digit>-<2 digits>
                    if (!RegExp(r'^WH\d+-[A-Z]\d+-\d{2}$').hasMatch(s)) {
                      return 'Format: WH1-B3-02';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
 
                // ---------------- Quantity ----------------
                const _FieldLabel('Quantity'),
                TextFormField(
                  controller: _qtyCtrl,
                  readOnly: readOnly,
                  keyboardType: TextInputType.number, // number keyboard
                  // Only digits can be typed (no letters, dots or minus).
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    suffixText: 'pcs',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter a number above 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
 
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
                      : (s) => setState(() => _direction = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: isIn
                        ? AppTheme.successColor.withValues(alpha: 0.15)
                        : AppTheme.errorColor.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 16),
 
                // ---------------- Worker (read-only) ----------------
                // Who scanned it never changes → it's the audit trail.
                const _FieldLabel('Worker'),
                TextFormField(
                  initialValue: tx.workerId,
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
 
                // "Edited by …" line, only if it was edited before.
                if (tx.editedBy != null && tx.editedAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last edited by ${tx.editedBy} · '
                    '${DateFormat('d MMM y, HH:mm').format(tx.editedAt!.toLocal())}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
 
        // ---------------- Bottom buttons (stay fixed) ----------------
        bottomNavigationBar: tx.reversed
            ? null // reversed → nothing to save
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Logged by ${t.workerId} • $date',
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
 
/// Shown at the top when the transaction was reversed (A4): read-only.
class _ReversedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.undo, color: AppTheme.warningColor),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This transaction was reversed. It can no longer be edited.',
              style: TextStyle(color: AppTheme.warningColor),
            ),
          ),
        ],
      ),
    );
  }
}
 