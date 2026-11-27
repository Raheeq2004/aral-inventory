import 'dart:async';

import 'package:aral_project/Admin/Models/item_row.dart';
import 'package:aral_project/Admin/Models/transaction_types.dart';
import 'package:aral_project/Admin/providers/transactions_repository.dart';
import 'package:aral_project/SharedComponents/app_snackbar.dart';
import 'package:aral_project/SharedComponents/direction_segmented_button.dart';
import 'package:aral_project/SharedComponents/offline_banner.dart';
import 'package:aral_project/SharedComponents/quantity_validator.dart';
import 'package:aral_project/SharedComponents/transaction_type_dropdown.dart';
import 'package:aral_project/StockKeeper/PendingSyncPage/pending_sync_page.dart';
import 'package:aral_project/StockKeeper/Step3Page/components/quick_add_button.dart';
import 'package:aral_project/StockKeeper/Step3Page/components/summary_info_cards.dart';
import 'package:aral_project/StockKeeper/components/step_progress_bar.dart';
import 'package:aral_project/StockKeeper/models/pending_sync_model.dart';
import 'package:aral_project/StockKeeper/models/scan_labels.dart';
import 'package:aral_project/StockKeeper/providers/scan_flow_provider.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:aral_project/connectivity/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class QuantityPage extends StatefulWidget {
  const QuantityPage({super.key});

  @override
  State<QuantityPage> createState() => _QuantityPageState();
}

class _QuantityPageState extends State<QuantityPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _selectedOperation = 'IN';
  late String _selectedType = _defaultLabelFor(_selectedOperation);
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  bool _isSubmitting = false;
  bool _submitLock = false;
  late bool _online;
  StreamSubscription<bool>? _connectionSub;

  String _defaultLabelFor(String direction) {
    final code = defaultTypeFor(direction);
    return typeByCode(code)?.label ?? code;
  }

  @override
  void initState() {
    super.initState();
    _online = ConnectivityService.instance.isOnline.value;
    unawaited(ConnectivityService.instance.checkInitialConnection());
    _connectionSub = ConnectivityService.instance.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (!mounted) return;
      setState(() => _online = isOnline);
      context.read<PendingSyncController>().setOnline(isOnline);
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    unawaited(_connectionSub?.cancel());
    super.dispose();
  }

  void _updateQuantity(int delta, {int? maxStock}) {
    final int current = int.tryParse(_quantityController.text) ?? 0;
    int updated = current + delta;
    if (updated < 1) updated = 1;
    if (_selectedOperation == 'OUT' &&
        _online &&
        maxStock != null &&
        updated > maxStock) {
      updated = maxStock > 0 ? maxStock : 1;
    }
    setState(() {
      _quantityController.text = updated.toString();
    });
  }

  Future<void> _submit(ItemRow? item, String? location) async {
    if (_isSubmitting || _submitLock) return;
    _submitLock = true;

    if (item == null || location == null) {
      _submitLock = false;
      showAppSnackBar(
        context,
        'Missing product or location. Scan again.',
        isError: true,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _submitLock = false;
      return;
    }

    final int qty = int.parse(_quantityController.text.trim());

    if (_selectedOperation == 'OUT' && _online && qty > item.quantity) {
      _submitLock = false;
      showAppSnackBar(
        context,
        'Not enough stock (${item.quantity} pcs available).',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_online) {
        await context
            .read<TransactionData>()
            .createTransaction(
              item: item,
              locationCode: location,
              direction: _selectedOperation,
              quantity: qty,
              stockKeeperId: 'StockKeeper',
              type: _selectedType,
            )
            .timeout(const Duration(seconds: 20));

        if (!mounted) return;
        showAppSnackBar(context, 'Transaction saved');
      } else {
        context.read<PendingSyncController>().add(
          PendingTransaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            itemName: '${item.code} (${lengthText(item.length)})',
            direction: _selectedOperation,
            quantity: qty,
            location: location,
            savedAt: DateTime.now(),
          ),
        );
        if (!mounted) return;
        showSavedOfflineSnack(context);
      }

      context.read<ScanFlowProvider>().reset();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on InsufficientStockException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } on TimeoutException {
      if (mounted) {
        showAppSnackBar(
          context,
          'Connection timed out. Check your internet and try again.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not save transaction. Try again.',
          isError: true,
        );
      }
    } finally {
      _submitLock = false;
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ScanFlowProvider>().session;
    final item = session.item;
    final location = session.locationCode;
    final int? availableStock = item?.quantity;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 14.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 28.0,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const StepProgressBar(currentStep: 3),
                          const SizedBox(height: 16),

                          if (!_online)
                            const OfflineBanner(
                              message: 'Transaction will be saved on this phone and synced when back online.',
                            ),

                          SummaryInfoCard(
                            icon: Icons.qr_code_2_rounded,
                            categoryLabel: 'PRODUCT',
                            title: item?.code ?? '—',
                            subtitle: item == null ? '' : productSubtitle(item),
                          ),
                          const SizedBox(height: 12),

                          SummaryInfoCard(
                            icon: Icons.location_on_outlined,
                            categoryLabel: 'LOCATION',
                            title: location == null
                                ? '—'
                                : locationTitle(location),
                            subtitle: location ?? '',
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Operation',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColorPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DirectionSegmentedButton(
                            value: _selectedOperation,
                            onChanged: (_isSubmitting || _submitLock)
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedOperation = val;
                                      _selectedType = _defaultLabelFor(val);
                                    });
                                    _formKey.currentState?.validate();
                                  },
                          ),
                          const SizedBox(height: 16),

                          TransactionTypeDropdown(
                            direction: _selectedOperation,
                            value: _selectedType,
                            enabled: !(_isSubmitting || _submitLock),
                            onChanged: (label) {
                              if (label != null) {
                                setState(() => _selectedType = label);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColorPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.borderColor,
                                  ),
                                  color: AppTheme.surfaceColor,
                                ),
                                child: IconButton(
                                  onPressed: (_isSubmitting || _submitLock)
                                      ? null
                                      : () => _updateQuantity(
                                          -1,
                                          maxStock: availableStock,
                                        ),
                                  icon: const Icon(Icons.remove),
                                  color: AppTheme.textColorPrimary,
                                  iconSize: 22,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 56,
                                    height: 56,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextFormField(
                                  controller: _quantityController,
                                  readOnly: _isSubmitting || _submitLock,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColorPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppTheme.surfaceColor,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                    suffixText: 'pieces',
                                    suffixStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.normal,
                                      color: AppTheme.textColorSecondary,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: AppTheme.secondaryColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      validateTransactionQuantity(
                                        value,
                                        direction: _selectedOperation,
                                        availableStock: availableStock,
                                        enforceStockLimit: _online,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryColor,
                                ),
                                child: IconButton(
                                  onPressed: (_isSubmitting || _submitLock)
                                      ? null
                                      : () => _updateQuantity(
                                          1,
                                          maxStock: availableStock,
                                        ),
                                  icon: const Icon(Icons.add),
                                  color: Colors.white,
                                  iconSize: 22,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 56,
                                    height: 56,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const Text(
                                'Quick add:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textColorSecondary,
                                ),
                              ),
                              for (final step in [10, 50, 100, 150])
                                QuickAddButton(
                                  label: '+$step',
                                  onTap: () => _updateQuantity(
                                    step,
                                    maxStock: availableStock,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: AppTheme.textColorSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'In stock: ${item?.quantity ?? 0} pcs',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textColorSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                top: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: (_isSubmitting || _submitLock)
                      ? null
                      : () => _submit(item, location),
                  icon: (_isSubmitting || _submitLock)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(
                    (_isSubmitting || _submitLock)
                        ? 'Submitting…'
                        : 'Submit transaction',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
