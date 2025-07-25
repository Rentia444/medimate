class Reminder {
  final String medicineName;
  final int hour;
  final int minute;

  Reminder({
    required this.medicineName,
    required this.hour,
    required this.minute,
  });

  Map<String, dynamic> toJson() => {
    'medicineName': medicineName,
    'hour': hour,
    'minute': minute,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    medicineName: json['medicineName'],
    hour: json['hour'],
    minute: json['minute'],
  );
}
