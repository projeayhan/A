import 'package:flutter/material.dart';

class PhoneFrame extends StatelessWidget {
  final Widget child;
  final double width;

  const PhoneFrame({
    super.key,
    required this.child,
    this.width = 280,
  });

  double get height => width * 2.05;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
          color: const Color(0xFF2D2D44),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 60,
            spreadRadius: 10,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.03),
        child: Column(
          children: [
            // Notch / Dynamic Island
            SizedBox(height: width * 0.03),
            Center(
              child: Container(
                width: width * 0.28,
                height: width * 0.06,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D1A),
                  borderRadius: BorderRadius.circular(width * 0.03),
                ),
              ),
            ),
            SizedBox(height: width * 0.02),
            // Screen
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(width * 0.08),
                child: child,
              ),
            ),
            SizedBox(height: width * 0.02),
            // Home indicator
            Center(
              child: Container(
                width: width * 0.3,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: width * 0.02),
          ],
        ),
      ),
    );
  }
}
