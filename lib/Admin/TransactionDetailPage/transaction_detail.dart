import 'dart:async'; // TimeoutException

import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/Models/transaction_types.dart';
import 'package:aral_project/Admin/Models/transactions_model.dart';
import 'package:aral_project/Admin/providers/transactions_repository.dart';
import 'package:aral_project/SharedComponents/app_snackbar.dart';
import 'package:aral_project/SharedComponents/direction_segmented_button.dart';
import 'package:aral_project/SharedComponents/offline_banner.dart';
import 'package:aral_project/SharedComponents/quantity_validator.dart';
import 'package:aral_project/SharedComponents/transaction_type_dropdown.dart';
import 'package:aral_project/StockKeeper/models/scan_labels.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:aral_project/connectivity/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // FilteringTextInputFormatter
// `show DateFormat` = import ONLY DateFormat from intl.
// (intl also has a class named TextDirection, which would clash with
//  Flutter's TextDirection used for right-to-left Arabic text.)
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:provider/provider.dart'; // context.read<TransactionData>()

/// STATEFUL: the fields change while the admin edits, and we show a
/// spinner while saving.
class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _locationCtrl;
  late final TextEditingController _qtyCtrl;

  late String _direction; // 'IN' or 'OUT'
  String? _type;
  late String _originalType;

  bool _isSaving = false;
  late bool _online;

  StreamSubscription<bool>? _connectionSub;

  ItemRow? _itemRow;
  bool _loadingItem = true;
  String? _locationError;

  TransactionModel get tx => widget.transaction;

  String _resolveTypeLabel(String? stored, String direction) {
    final raw = (stored ?? '').trim();
    if (raw.isNotEmpty) {
      final allTypes = <TransactionType>[
        ...kTransactionTypes,
        ...kRetiredTypes,
        kReversalType,
      ];
      for (final t in allTypes) {
        if (t.label == raw) return t.label;
      }

      final byCode = typeByCode(raw);
      if (byCode != null) return byCode.label;
    }

    final normalizedCode = normalizeType(raw, direction);
    return typeByCode(normalizedCode)?.label ?? normalizedCode;
  }

  @override
  void initState() {
    super.initState();
    _locationCtrl = TextEditingController(text: tx.locationCode);
    _qtyCtrl = TextEditingController(text: tx.quantity.toString());
    _direction = tx.direction;
    _originalType = _resolveTypeLabel(tx.type, tx.direction);
    _type = _originalType;
    _online = ConnectivityService.instance.isOnline.value;
    _loadItem();
    _listenToConnection();
  }

  void _listenToConnection() {
    unawaited(ConnectivityService.instance.checkInitialConnection());
    _connectionSub = ConnectivityService.instance.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (!mounted) return;
      final cameBack = isOnline && !_online;
      setState(() => _online = isOnline);
      if (cameBack && _itemRow == null) _loadItem();
    });
  }

  Future<void> _loadItem() async {
    if (mounted) setState(() => _loadingItem = true);
    try {
      final row = await context.read<TransactionData>().itemFor(tx);
      if (!mounted) return;
      setState(() => _itemRow = row);
    } catch (_) {
      // Offline / error -> show fallback in chips.
    } finally {
      if (mounted) setState(() => _loadingItem = false);
    }
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _qtyCtrl.dispose();
    unawaited(_connectionSub?.cancel());
    super.dispose();
  }

  bool get _hasChanges =>
      _locationCtrl.text.trim().toUpperCase() != tx.locationCode ||
      _qtyCtrl.text.trim() != tx.quantity.toString() ||
      _direction != tx.direction ||
      _type != _originalType;

  // ===================================================================
  // SAVE
  // ===================================================================
  Future<void> _save() async {
    if (!_online) return;
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _locationError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final newLocation = _locationCtrl.text.trim().toUpperCase();
    final newQty = int.parse(_qtyCtrl.text.trim());

    final provider = context.read<TransactionData>();

    setState(() => _isSaving = true);

    try {
      if (newLocation != tx.locationCode &&
          !await provider
              .locationExists(newLocation)
              .timeout(const Duration(seconds: 10))) {
        setState(() => _locationError = 'This location doesn\'t exist');
        return;
      }

      final updated = tx.copyWith(
        locationCode: newLocation,
        quantity: newQty,
        direction: _direction,
        type: _type!,
      );

      await provider
          .updateTransaction(original: tx, updated: updated)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      _showMessage('Changes saved');
      Navigator.pop(context);
    } on InsufficientStockException catch (e) {
      _showMessage(e.message, isError: true);
    } on TimeoutException {
      _showMessage('Couldn\'t save. Check your connection.', isError: true);
    } catch (_) {
      _showMessage('Couldn\'t save. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ===================================================================
  // REVERSE (A4)
  // ===================================================================
  Future<bool> _confirmReverse() async {
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
    return ok ?? false;
  }

  Future<void> _reverse() async {
    if (!_online) return;
    if (_hasChanges) {
      _showMessage('Save or cancel your changes before reversing.');
      return;
    }
    if (!await _confirmReverse()) return;
    if (!mounted) return;

    final provider = context.read<TransactionData>();
    setState(() => _isSaving = true);

    try {
      await provider
          .reverseTransaction(original: tx, reversedBy: 'Admin')
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      _showMessage('Transaction #${tx.transactionId} reversed');
      Navigator.pop(context);
    } on InsufficientStockException catch (e) {
      _showMessage(e.message, isError: true);
    } on TimeoutException {
      _showMessage('Couldn\'t reverse. Check your connection.', isError: true);
    } catch (_) {
      _showMessage('Couldn\'t reverse. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    showAppSnackBar(context, text, isError: isError);
  }

  // ===================================================================
  // LEAVING WITH UNSAVED CHANGES
  // ===================================================================
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
    return discard ?? false;
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
    final locked = tx.reversed || tx.isReversal;
    final readOnly = locked || _isSaving || !_online;

    return PopScope(
      canPop: !_hasChanges || locked,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Text('Transaction #${tx.numericId}'),
          actions: [
            if (!locked)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ReverseIconButton(
                  onPressed: (_isSaving || !_online) ? null : _reverse,
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_online && !locked)
                  const OfflineBanner(
                    message: 'Connect to the internet to edit or reverse this transaction.',
                  ),
                if (tx.reversed) const _ReversedBanner(title: 'Reversed'),
                if (tx.isReversal)
                  _ReversedBanner(
                    title: 'Reversal of #${tx.reversalOf ?? '—'}',
                  ),
                _SummaryCard(transaction: tx),
                const SizedBox(height: 20),

                // ============ SECTION 1: RECORD (read only) ============
                const _SectionTitle('RECORD · READ ONLY'),
                Row(
                  children: [
                    Expanded(
                      child: _ReadOnlyField(
                        icon: Icons.person_outline,
                        label: 'Logged by',
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
                        value: DateFormat('d MMM y, HH:mm')
                            .format(tx.timestamp.toLocal()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ============ SECTION 2: ITEM (read only) ============
                const _SectionTitle('ITEM · READ ONLY'),
                _ItemCard(
                  itemCode: tx.itemCode.isNotEmpty
                      ? tx.itemCode
                      : (_itemRow?.code ?? (_loadingItem ? '…' : '—')),
                  chips: _ItemInfoChips(
                    length: lengthText(_itemRow?.length ?? tx.length),
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
                _SectionTitle(
                  (locked || !_online) ? 'MOVEMENT' : 'MOVEMENT · EDITABLE',
                ),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DirectionSegmentedButton(
                        value: _direction,
                        onChanged: readOnly
                            ? null
                            : (newDirection) => setState(() {
                                _direction = newDirection;
                                _type = _direction == tx.direction
                                    ? _originalType
                                    : _resolveTypeLabel(null, _direction);
                              }),
                      ),
                      const SizedBox(height: 16),

                      const _FieldLabel('Quantity'),
                      TextFormField(
                        controller: _qtyCtrl,
                        readOnly: readOnly,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                          suffixText: 'pcs',
                        ),
                        validator: (v) => validateTransactionQuantity(
                          v,
                          direction: _direction,
                          availableStock: _itemRow == null
                              ? null
                              : _itemRow!.quantity +
                                    (tx.direction == 'OUT' ? tx.quantity : 0),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TransactionTypeDropdown(
                        direction: _direction,
                        value: _type,
                        enabled: !readOnly,
                        label: 'Transaction type',
                        onChanged: (label) {
                          if (label != null) {
                            setState(() => _type = label);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

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
                          if (!RegExp(r'^WH\d+-[A-Z]\d+-\d{2}$').hasMatch(s)) {
                            return 'Format: WH1-B3-02';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

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
        bottomNavigationBar: locked
            ? null
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
                        child: !_online
                            ? FilledButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.wifi_off),
                                label: const Text('Offline'),
                              )
                            : FilledButton.icon(
                                onPressed: _isSaving ? null : _save,
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
                                label: Text(
                                  _isSaving ? 'Saving…' : 'Save changes',
                                ),
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
          Row(
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
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textColorSecondary),
          const SizedBox(width: 8),
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

class _ReversedBanner extends StatelessWidget {
  const _ReversedBanner({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer,
        border: Border.all(color: AppTheme.warningBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.undo, size: 18, color: AppTheme.warningColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.warningColor,
                ),
                children: [
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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
          letterSpacing: 0.8,
          color: AppTheme.textColorSecondary,
        ),
      ),
    );
  }
}

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

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.itemCode, required this.chips});
  final String itemCode;
  final Widget chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
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

class _ReverseIconButton extends StatelessWidget {
  const _ReverseIconButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onPressed,
      tooltip: 'Reverse transaction',
      icon: const Icon(Icons.undo),
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.secondaryColor,
        backgroundColor: AppTheme.secondaryContainer,
        side: const BorderSide(color: AppTheme.secondaryColor, width: 1.5),
      ),
    );
  }
}

class _ReverseDialog extends StatelessWidget {
  const _ReverseDialog({
    required this.transaction,
    required this.stockNow,
    required this.stockAfter,
  });

  final TransactionModel transaction;
  final int? stockNow;
  final int? stockAfter;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final reversalIsIn = t.oppositeDirection == 'IN';
    final moveColor = reversalIsIn
        ? AppTheme.successColor
        : AppTheme.errorColor;
    final notEnough = stockAfter != null && stockAfter! < 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.undo, color: AppTheme.secondaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text('Reverse transaction #${t.numericId}')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This undoes the movement by adding the opposite '
            'transaction. Nothing is deleted.',
            style: TextStyle(color: AppTheme.textColorSecondary),
          ),
          if (stockNow != null && stockAfter != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
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
                  onPressed: notEnough
                      ? null
                      : () => Navigator.pop(context, true),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Yes, reverse'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
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
            valueColor: AppTheme.successColor,
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

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
