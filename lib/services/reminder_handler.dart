import 'package:flutter/material.dart';
import '../services/obat_service.dart';

class ReminderHandler {
  static Future<void> handleReminderTap({
    required BuildContext context,
    required String medicineName,
  }) async {
    // First show the dialog and get confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(medicineName),
        content: const Text('Apakah Anda sudah minum obat ini?'),
        actions: [
          TextButton(
            child: const Text('Lewati'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Sudah Minum'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    // Check if widget is still mounted before proceeding
    if (!context.mounted) return;

    // Process the confirmation
    if (confirmed == true) {
      try {
        await ObatService.recordDoseTaken(medicineName);
        
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$medicineName berhasil dicatat'),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencatat: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}