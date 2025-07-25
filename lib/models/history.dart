class MedicationHistory {
  final String medicineName;
  final DateTime takenTime;
  final int dosage;
  final bool wasTaken;

  MedicationHistory({
    required this.medicineName,
    required this.takenTime,
    required this.dosage,
    this.wasTaken = true,
  });

  // Add these methods to your model
  factory MedicationHistory.fromJson(Map<String, dynamic> json) {
    return MedicationHistory(
      medicineName: json['medicineName'],
      takenTime: DateTime.parse(json['takenTime']),
      dosage: json['dosage'],
      wasTaken: json['wasTaken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicineName': medicineName,
      'takenTime': takenTime.toIso8601String(),
      'dosage': dosage,
      'wasTaken': wasTaken,
    };
  }
}