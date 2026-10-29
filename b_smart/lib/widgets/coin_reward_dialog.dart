import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Future<void> showCoinRewardDialog(BuildContext context,
        {required int amount,
        required String title,
        required String message}) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFFFA3F5E),
              child: Icon(LucideIcons.coins, color: Colors.white, size: 34)),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Text('+$amount coins',
              style: const TextStyle(
                  color: Color(0xFFFA3F5E),
                  fontWeight: FontWeight.bold,
                  fontSize: 28)),
        ]),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Awesome!'))
        ],
      ),
    );
