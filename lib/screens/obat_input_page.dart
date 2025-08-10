import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/obat.dart';
import '../services/obat_service.dart';
import 'package:medimate_practice/services/alarm_service.dart';

class ObatInputPage extends StatefulWidget {
  final Obat? obat;

  const ObatInputPage({super.key, this.obat});

  @override
  State<ObatInputPage> createState() => _ObatInputPageState();
}

class _ObatInputPageState extends State<ObatInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _qtyController = TextEditingController();
  final _dosisController = TextEditingController();
  final _jumlahDosisController = TextEditingController();
  final _usageController = TextEditingController();
  List<TimeOfDay> _selectedTimes = [];
  DateTime? _purchaseDate;

  @override
  void initState() {
    super.initState();
    if (widget.obat != null) {
      _initializeFormWithExistingData();
    }
  }

  void _initializeFormWithExistingData() {
    final obat = widget.obat!;
    _namaController.text = obat.nama;
    _qtyController.text = obat.qty.toString();
    _dosisController.text = obat.dosisPerHari.toString();
    _jumlahDosisController.text = obat.jumlahPerDosis.toString();
    _usageController.text = obat.usageNotes;
    _selectedTimes = List.from(obat.jadwal);
    _purchaseDate = obat.purchaseDate;
  }

  Future<void> _selectTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: false, // Use AM/PM format for clarity
          ),
          child: child!,
        );
      },
    );
    if (time != null && mounted) {
      setState(() {
        _selectedTimes.add(time);
        _selectedTimes.sort((a, b) => a.hour.compareTo(b.hour));
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih Tanggal Pembelian', 
      cancelText: 'Batal',
      confirmText: 'Pilih',
      fieldLabelText: 'Tanggal Pembelian',
    );
    if (picked != null && mounted) {
      setState(() {
        _purchaseDate = picked;
      });
    }
  }

  Future<void> _saveObat() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final obat = Obat(
        nama: _namaController.text,
        qty: int.parse(_qtyController.text),
        dosisPerHari: int.parse(_dosisController.text),
        jumlahPerDosis: int.parse(_jumlahDosisController.text),
        jadwal: _selectedTimes, // List<TimeOfDay>
        purchaseDate: _purchaseDate ?? DateTime.now(),
        usageNotes: _usageController.text,
      );

      await AlarmService.requestExactAlarmPermission();

      // Save medication first
      if (widget.obat == null) {
        await ObatService.saveObat(obat);
      } else {
        await ObatService.updateObat(obat);
      }

      // 🔔 Set alarms for each scheduled time
      for (final time in obat.jadwal) {
        await AlarmService.setAlarm(obat.nama, time.hour, time.minute);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${obat.jadwal.length} alarm diatur untuk ${obat.nama}'),
        ),
      );

      final currentContext = context;
      if (!currentContext.mounted) return;

      Navigator.of(currentContext).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _removeTime(int index) {
    setState(() {
      _selectedTimes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.obat == null ? 'Tambah Obat Baru' : 'Edit Obat',
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, size: 28),
            onPressed: _saveObat,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + bottomPadding, // Extra space for keyboard
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInputField(
                  controller: _namaController,
                  label: 'Nama Obat',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama obat harus diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        controller: _qtyController,
                        label: 'Stok',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Jumlah stok harus diisi';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Masukkan angka yang valid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputField(
                        controller: _dosisController,
                        label: 'Dosis/Hari',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Dosis harus diisi';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Masukkan angka yang valid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputField(
                        controller: _jumlahDosisController,
                        label: 'Jml/Dosis',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Jumlah per dosis harus diisi';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Masukkan angka yang valid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  controller: _usageController,
                  label: 'Catatan Penggunaan',
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                _buildDateSelector(),
                const SizedBox(height: 20),
                _buildTimeScheduleSection(),
                const SizedBox(height: 20),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFFFFFFF), // putih
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA8D5BA)), 
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA8D5BA), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6CB28E), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      style: const TextStyle(fontSize: 18),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.characters,
      onChanged: (value) {
        controller.value = controller.value.copyWith(
          text: value.toUpperCase(),
          selection: TextSelection.collapsed(offset: value.length),
        );
      },
    );
  }

  Widget _buildDateSelector() {
    return Card(
      color: const Color(0xFFE9FCEB), // 🌿 hijau pastel terang, sama seperti input box
      elevation: 2,
      child: ListTile(
        title: Text(
          _purchaseDate == null
              ? 'Pilih Tanggal Pembelian'
              : 'Tanggal Pembelian: ${DateFormat('dd/MM/yyyy').format(_purchaseDate!)}',
          style: const TextStyle(fontSize: 18),
        ),
        trailing: const Icon(Icons.calendar_today, size: 28),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: () => _selectDate(context),
      ),
    );
  }

  Widget _buildTimeScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Jadwal Minum:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_selectedTimes.isEmpty)
          const Text(
            'Belum ada jadwal ditambahkan',
            style: TextStyle(fontSize: 16),
          ),
        ..._selectedTimes.map((time) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  time.format(context),
                  style: const TextStyle(fontSize: 18),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 28),
                  onPressed: () => _removeTime(_selectedTimes.indexOf(time)),
                ),
              ),
            )),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => _selectTime(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF66BB6A),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text(
            'Tambah Jadwal Minum',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF66BB6A),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _saveObat,
      child: Text(
        widget.obat == null ? 'Simpan Obat' : 'Update Obat',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _qtyController.dispose();
    _dosisController.dispose();
    _jumlahDosisController.dispose();
    _usageController.dispose();
    super.dispose();
  }
}