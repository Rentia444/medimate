import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; // Import TableCalendar
import '../services/obat_service.dart';

class ObatHistoryPage extends StatefulWidget {
  const ObatHistoryPage({super.key});

  @override
  State<ObatHistoryPage> createState() => _ObatHistoryPageState();
}

class _ObatHistoryPageState extends State<ObatHistoryPage> {
  // === Calendar State Variables ===
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  List<dynamic> _selectedEvents = []; // Events for the currently selected day

  // === Existing State Variables ===
  late Future<List<Map<String, dynamic>>> _historyFuture;
  final DateFormat _dateFormat = DateFormat('EEEE, dd MMMM yyyy - HH:mm', 'id_ID');
  bool _showMissedDoses = false; // Toggle for missed doses

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; // Initialize selected day to today
    _loadHistory();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Function to load history and populate calendar events
  void _loadHistory() async {
    setState(() {
      _historyFuture = _showMissedDoses
          ? ObatService.getMissedDoses()
          : ObatService.getConsumptionHistory();
    });

    final historyData = await _historyFuture;
    _events = _groupEventsByDate(historyData);
    _selectedEvents = _getEventsForDay(_selectedDay!); // Update events for selected day
  }

  // Helper to group history items by date for the calendar
  Map<DateTime, List<dynamic>> _groupEventsByDate(List<Map<String, dynamic>> history) {
    Map<DateTime, List<dynamic>> data = {};
    for (var entry in history) {
      final DateTime eventDate = _showMissedDoses
          ? (entry['scheduledTime'] is DateTime ? entry['scheduledTime'] : DateTime.parse(entry['scheduledTime']))
          : (entry['date'] is DateTime ? entry['date'] : DateTime.parse(entry['date']));
      
      final DateTime kDay = DateTime.utc(eventDate.year, eventDate.month, eventDate.day);

      if (data[kDay] == null) {
        data[kDay] = [];
      }
      data[kDay]?.add(entry); // Add the full entry as an event
    }
    return data;
  }

  // Helper to get events for a specific day
  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  // Handle day selection on the calendar
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Obat'),
        actions: [
          IconButton(
            icon: Icon(_showMissedDoses ? Icons.medical_services : Icons.warning),
            onPressed: () {
              setState(() {
                _showMissedDoses = !_showMissedDoses;
                _loadHistory(); // Reload history based on new toggle state
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(_showMissedDoses
                  ? 'Tidak ada obat yang terlewat'
                  : 'Belum ada riwayat konsumsi'),
            );
          }

          // Main content with Calendar and Event List
          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay, // This function loads events for each day
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  markerDecoration: BoxDecoration(
                    color: _showMissedDoses ? Colors.orangeAccent : Colors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                onDaySelected: _onDaySelected,
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay; // Update focused day when page changes
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
              ),
              const SizedBox(height: 8.0),
              // Display events for the selected day
              Expanded(
                child: _selectedEvents.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada ${ _showMissedDoses ? "obat terlewat" : "konsumsi obat" } pada tanggal ini.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _selectedEvents.length,
                        itemBuilder: (context, index) {
                          final entry = _selectedEvents[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                _showMissedDoses ? Icons.warning : Icons.medical_services,
                                color: _showMissedDoses ? Colors.orange : Colors.green,
                              ),
                              title: Text(entry['medicine'] ?? 'Unknown Medicine'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_dateFormat.format(entry[_showMissedDoses
                                      ? 'scheduledTime'
                                      : 'date'] is DateTime
                                      ? entry[_showMissedDoses ? 'scheduledTime' : 'date']
                                      : DateTime.parse(entry[_showMissedDoses ? 'scheduledTime' : 'date']))),
                                  if (!_showMissedDoses && entry['notes']?.isNotEmpty == true)
                                    Text('Catatan: ${entry['notes']}'),
                                ],
                              ),
                              trailing: Text('${entry['dose']} dosis'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}