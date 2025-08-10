import 'dart:convert';  // Add this import at the top
import 'package:shared_preferences/shared_preferences.dart';
import '../models/obat.dart';

class ObatService {
  static const String _key = 'obatList';

  // Get all medicines
  static Future<List<Obat>> getObatList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_key) ?? [];
      
      final List<Obat> validObat = [];
      for (final json in jsonList) {
        try {
          final decoded = jsonDecode(json) as Map<String, dynamic>;
          validObat.add(Obat.fromJson(decoded));
        } catch (e) {
          //print('Error parsing obat: $e\nJSON: $json');
          // Skip invalid entries
        }
      }
      return validObat;
    } catch (e) {
      //print('Error loading obat list: $e');
      return [];
    }
  }

  static Future<bool> consumeObatIfStockAvailable(String namaObat) async {
    final list = await getObatList();
    final index = list.indexWhere((o) => o.nama == namaObat);
    if (index == -1) return false;

    final obat = list[index];

    if (obat.qty < obat.jumlahPerDosis) {
      return false; // not enough stock
    }

    // Kurangi stok dan catat tanggal konsumsi
    obat.confirmTaken();
    list[index] = obat;

    await _saveAll(list);
    return true;
  }

  // Save medicine
  static Future<void> saveObat(Obat obat) async {
    final list = await getObatList();
    list.add(obat);
    await _saveAll(list);
  }

  // Update medicine
  static Future<void> updateObat(Obat updatedObat) async {
    final list = await getObatList();
    final index = list.indexWhere((o) => o.nama == updatedObat.nama);
    if (index != -1) list[index] = updatedObat;
    await _saveAll(list);
  }

  // Delete medicine
  static Future<void> deleteObat(String namaObat) async {
    final list = await getObatList();
    list.removeWhere((obat) => obat.nama == namaObat);
    await _saveAll(list);
  }

  // Private method to save all medicines
  static Future<void> _saveAll(List<Obat> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = list.map((obat) {
        try {
          return jsonEncode(obat.toJson());
        } catch (e) {
          //print('Error encoding obat: $e\nObat: ${obat.nama}');
          return '{}'; // Fallback empty JSON
        }
      }).toList();
      
      await prefs.setStringList(_key, jsonList);
    } catch (e) {
      //print('Error saving obat list: $e');
    }
  }

  // Clear all medicines
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> repairObatData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final jsonList = prefs.getStringList(_key) ?? [];
      final repairedList = <String>[];
      
      for (final json in jsonList) {
        // Basic repair for common malformed JSON
        String repairedJson = json
          .replaceAll(r'\', '') // Remove accidental escapes
          .replaceAll('"{', '{') // Fix double-encoded
          .replaceAll('}"', '}');
        
        // Validate JSON
        try {
          jsonDecode(repairedJson);
          repairedList.add(repairedJson);
        } catch (_) {
          // Skip invalid entries
        }
      }
      
      await prefs.setStringList(_key, repairedList);
    } catch (e) {
      //print('Repair failed: $e');
      // Last resort - clear corrupt data
      await prefs.remove(_key);
    }
  }

  // Add to obat_service.dart
  static Future<void> recordDoseTaken(String namaObat) async {
    final list = await getObatList();
    final index = list.indexWhere((o) => o.nama == namaObat);
    if (index != -1) {
      list[index].confirmTaken(); 
      await _saveAll(list);
    }
  }

  static Future<List<Map<String, dynamic>>> getConsumptionHistory() async {
    final obatList = await getObatList();
    final history = <Map<String, dynamic>>[];
    
    for (final obat in obatList) {
      for (final date in obat.takenDates) {
        history.add({
          'medicine': obat.nama,
          'date': date,
          'dose': obat.jumlahPerDosis,
          'notes': obat.usageNotes,
          'schedule': obat.jadwal, // Include schedule info
        });
      }
    }
    
    // Sort by date (newest first)
    history.sort((a, b) => b['date'].compareTo(a['date']));
    
    return history;
  }

  static Future<List<Map<String, dynamic>>> getMissedDoses() async {
    final obatList = await getObatList();
    final now = DateTime.now();
    final missed = <Map<String, dynamic>>[];
    
    for (final obat in obatList) {
      for (final schedule in obat.jadwal) {
        final scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          schedule.hour,
          schedule.minute,
        );
        
        // Check if dose was missed (no record within 30 minutes of scheduled time)
        final wasTaken = obat.takenDates.any((takenDate) =>
            takenDate.difference(scheduledTime).abs() < const Duration(minutes: 30));
        
        if (!wasTaken && scheduledTime.isBefore(now)) {
          missed.add({
            'medicine': obat.nama,
            'scheduledTime': scheduledTime,
            'dose': obat.jumlahPerDosis,
          });
        }
      }
    }
    
    return missed;
  }
}