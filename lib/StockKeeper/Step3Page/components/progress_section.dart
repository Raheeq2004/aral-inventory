import 'package:aral_project/Theme/theme.dart';
import 'package:flutter/material.dart';

class StepProgressBar extends StatelessWidget {
  final int currentStep; // 1 = Product, 2 = Location, 3 = Quantity

  const StepProgressBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStepItem(stepNumber: 1, title: 'Product'),
        _buildConnectorLine(isActive: currentStep > 1),
        _buildStepItem(stepNumber: 2, title: 'Location'),
        _buildConnectorLine(isActive: currentStep > 2),
        _buildStepItem(stepNumber: 3, title: 'Quantity'),
      ],
    );
  }

  Widget _buildStepItem({required int stepNumber, required String title}) {
    final bool isCompleted = stepNumber < currentStep;
    final bool isCurrent = stepNumber == currentStep;

    Color circleColor;
    if (isCompleted) {
      circleColor = AppTheme.successColor;
    } else if (isCurrent) {
      circleColor = AppTheme.primaryColor;
    } else {
      circleColor = AppTheme.borderColor;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  stepNumber.toString(),
                  style: TextStyle(
                    color: isCurrent
                        ? Colors.white
                        : AppTheme.textColorSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isCurrent
                ? AppTheme.primaryColor
                : AppTheme.textColorSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectorLine({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isActive ? AppTheme.successColor : AppTheme.borderColor,
      ),
    );
  }
}
