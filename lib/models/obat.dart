import 'package:flutter/material.dart';

class Obat {
  String nama;
  int qty;
  int dosisPerHari;
  int jumlahPerDosis;
  List<TimeOfDay> jadwal;
  DateTime purchaseDate;
  DateTime nextPurchaseDate;
  List<DateTime> takenDates;
  String usageNotes;

  Obat({
    required this.nama,
    required this.qty,
    required this.dosisPerHari,
    required this.jumlahPerDosis,
    required this.jadwal,
    required this.purchaseDate,
    required this.usageNotes,
    List<DateTime>? takenDates,
  }) :
    takenDates = takenDates ??[],
    nextPurchaseDate = purchaseDate.add(const Duration(days: 30));
  
  Map<String, dynamic> toJson() => {
    'nama': nama,
    'qty': qty,
    'dosisPerHari': dosisPerHari,
    'jumlahPerDosis': jumlahPerDosis,
    'jadwal': jadwal.map((t) => '${t.hour}:${t.minute}').toList(),
    'purchaseDate': purchaseDate.toIso8601String(),
    'nextPurchaseDate': nextPurchaseDate.toIso8601String(),
    'takenDates': takenDates.map((d) => d.toIso8601String()).toList(),
    'usageNotes': usageNotes,
  };

  factory Obat.fromJson(Map<String, dynamic> json) {
    final jadwalList = (json['jadwal'] as List)
        .map((e) {
          final parts = (e as String).split(':');
          return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        })
        .toList();

    return Obat(
      nama: json['nama'],
      qty: json['qty'],
      dosisPerHari: json['dosisPerHari'],
      jumlahPerDosis: json['jumlahPerDosis'],
      jadwal: jadwalList,
      purchaseDate: DateTime.parse(json['purchaseDate']),
      usageNotes: json['usageNotes'],
      takenDates: (json['takenDates'] as List).map((d) => DateTime.parse(d)).toList(),
    );
  }

  int get kebutuhanPerHari => dosisPerHari * jumlahPerDosis;

  bool perluBeliObat() {
    final hariTersisa = (qty / kebutuhanPerHari).floor();
    return hariTersisa <= 5;
  }

  void confirmTaken() {
    qty -= jumlahPerDosis;
    takenDates.add(DateTime.now());
    if (perluBeliObat()) {
      nextPurchaseDate = DateTime.now().add(const Duration(days: 5));
    }
  }
}