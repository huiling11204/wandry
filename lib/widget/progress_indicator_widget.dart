import 'package:flutter/material.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const ProgressIndicatorWidget({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isEven) {
          // Dot
          final step = (index ~/ 2) + 1;
          return _ProgressDot(
            step: step,
            isActive: step <= currentStep,
          );
        } else {
          // Line
          final step = (index ~/ 2) + 1;
          return _ProgressLine(
            isActive: step < currentStep,
          );
        }
      }),
    );
  }
}

class _ProgressDot extends StatelessWidget {
  final int step;
  final bool isActive;

  const _ProgressDot({
    required this.step,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF4A90E2) : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final bool isActive;

  const _ProgressLine({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? const Color(0xFF4A90E2) : Colors.grey[300],
      ),
    );
  }
}