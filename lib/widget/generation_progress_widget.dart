import 'package:flutter/material.dart';

class GenerationProgressWidget extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const GenerationProgressWidget({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(steps.length, (index) {
          final isComplete = index < currentStep;
          final isCurrent = index == currentStep;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? Colors.green
                        : isCurrent
                        ? const Color(0xFF2196F3)
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isComplete ? Icons.check : Icons.circle,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 14,
                      color: isComplete || isCurrent
                          ? Colors.black87
                          : Colors.grey[500],
                      fontWeight: isCurrent
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class AnimatedLoadingIcon extends StatefulWidget {
  const AnimatedLoadingIcon({super.key});

  @override
  State<AnimatedLoadingIcon> createState() => _AnimatedLoadingIconState();
}

class _AnimatedLoadingIconState extends State<AnimatedLoadingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome,
          size: 80,
          color: Color(0xFF2196F3),
        ),
      ),
    );
  }
}