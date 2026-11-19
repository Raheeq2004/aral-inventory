import 'package:aral_project/StockKeeper/Step3Page/components/progress_section.dart';
import 'package:aral_project/StockKeeper/Step3Page/components/quick_add_button.dart';
import 'package:aral_project/StockKeeper/Step3Page/components/summary_info_cards.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuantityPage extends StatefulWidget {
  const QuantityPage({super.key});

  @override
  State<QuantityPage> createState() => _QuantityPageState();
}

class _QuantityPageState extends State<QuantityPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _selectedOperation = 'IN';
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(int delta) {
    final int current = int.tryParse(_quantityController.text) ?? 0;
    final int updated = current + delta;
    if (updated >= 1) {
      setState(() {
        _quantityController.text = updated.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isInOperation = _selectedOperation == 'IN';

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Fills all available vertical space above the bottom bar
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
                          // 1. Top Progress Row
                          const StepProgressBar(currentStep: 3),
                          SizedBox(height: 16),
                          // 2. Product Summary Card
                          const SummaryInfoCard(
                            icon: Icons.qr_code_2_rounded,
                            categoryLabel: 'PRODUCT',
                            title: 'Aluminum Profile 6063-T5',
                            subtitle: 'ITM-AL-6063 · 6 m · Silver anodized',
                          ),
                          const SizedBox(height: 12),

                          // 3. Location Summary Card
                          const SummaryInfoCard(
                            icon: Icons.location_on_outlined,
                            categoryLabel: 'LOCATION',
                            title: 'Warehouse 1 · Rack B3 · Shelf 2',
                            subtitle: 'LOC-WH1-B3-S2',
                          ),
                          const SizedBox(height: 16),
                          // 4. Operation Section
                          const Text(
                            'Operation',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColorPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              style: ButtonStyle(
                                minimumSize: WidgetStateProperty.all(
                                  const Size.fromHeight(52),
                                ),
                                shape: WidgetStateProperty.all(
                                  const StadiumBorder(),
                                ),
                                backgroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(
                                        WidgetState.selected,
                                      )) {
                                        return isInOperation
                                            ? AppTheme.successColor.withValues(
                                                alpha: 0.16,
                                              )
                                            : AppTheme.errorColor.withValues(
                                                alpha: 0.14,
                                              );
                                      }
                                      return AppTheme.surfaceColor;
                                    }),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(
                                        WidgetState.selected,
                                      )) {
                                        return isInOperation
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor;
                                      }
                                      return AppTheme.textColorPrimary;
                                    }),
                                side: WidgetStateProperty.all(
                                  const BorderSide(color: AppTheme.borderColor),
                                ),
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: 'IN',
                                  icon: Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'IN · Store',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                ButtonSegment(
                                  value: 'OUT',
                                  icon: Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'OUT · Withdraw',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              selected: {_selectedOperation},
                              onSelectionChanged: (Set<String> newSelection) {
                                setState(() {
                                  _selectedOperation = newSelection.first;
                                });
                              },
                            ),
                          ),
                          SizedBox(height: 16),
                          // 5. Quantity Section
                          const Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColorPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Stepper Row (- [ 20 pieces ] +)
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
                                  onPressed: () => _updateQuantity(-1),
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
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter quantity';
                                    }
                                    final intValue = int.tryParse(value);
                                    if (intValue == null || intValue <= 0) {
                                      return 'Must be > 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryColor,
                                ),
                                child: IconButton(
                                  onPressed: () => _updateQuantity(1),
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

                          // 6. Quick Add Row
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
                              QuickAddButton(
                                label: '+10',
                                onTap: () => _updateQuantity(10),
                              ),
                              QuickAddButton(
                                label: '+50',
                                onTap: () => _updateQuantity(50),
                              ),
                              QuickAddButton(
                                label: '+100',
                                onTap: () => _updateQuantity(100),
                              ),
                              QuickAddButton(
                                label: '+150',
                                onTap: () => _updateQuantity(150),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 7. Available Stock Row
                          const Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: AppTheme.textColorSecondary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Available at this location: 12 pcs',
                                style: TextStyle(
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

          // 8. Pinned Bottom Submit Bar
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
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // Submit transaction
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text(
                    'Submit transaction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
