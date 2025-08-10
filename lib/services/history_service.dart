import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/history.dart';

class HistoryService {
  static const _historyKey = 'medication_history';

  static Future<List<MedicationHistory>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    
    return historyJson.map((jsonString) {
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return MedicationHistory.fromJson(jsonMap);
    }).toList();
  }

  static Future<void> addHistory(MedicationHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    final currentHistory = await getHistory();
    final updatedHistory = [...currentHistory, history];
    
    await prefs.setStringList(
      _historyKey,
      updatedHistory.map((history) => json.encode(history.toJson())).toList(),
    );
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}