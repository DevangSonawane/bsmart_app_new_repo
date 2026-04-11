import 'package:flutter/material.dart';

class GlassActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final double rotate;

  const GlassActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
    this.rotate = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Transform.rotate(
                angle: rotate,
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 0),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

