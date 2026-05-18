import 'package:flutter/material.dart';

class GraficoBar extends StatelessWidget {
  final double value;
  final double maxValue;

  const GraficoBar({
    super.key,
    required this.value,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final percent = maxValue == 0
        ? 0.0
        : (value / maxValue).clamp(0.0, 1.0);

    return Container(
      width: 80,
      height: 100,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 70,
        height: (percent * 100).clamp(8, 100).toDouble(),
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          borderRadius: BorderRadius.circular(0),
        ),
      ),
    );
  }
}