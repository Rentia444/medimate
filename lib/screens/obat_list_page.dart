import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/obat.dart';
import '../services/obat_service.dart';
import 'obat_input_page.dart';
//import '../services/test_helpers.dart';

class ObatListPage extends StatefulWidget {
  const ObatListPage({super.key});

  @override
  State<ObatListPage> createState() => _ObatListPageState();
}

class _ObatListPageState extends State<ObatListPage> {
  late Future<List<Obat>> _obatListFuture;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadData() async {
    setState(() {
      //_hasError = false;
      _obatListFuture = _getObatListWithRetry();
    });
  }

  Future<List<Obat>> _getObatListWithRetry() async {
    try {
      return await ObatService.getObatList();
    } catch (e) {
      //print('Error loading obat list: $e');
      // Attempt to repair data
      await ObatService.repairObatData();
      return await ObatService.getObatList();
    }
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _confirmTaken(Obat obat) async {
    try {
      final success = await ObatService.consumeObatIfStockAvailable(obat.nama);
      if (mounted) {
        if (success) {
          await _refreshData(); // refresh tampilan setelah update
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stok obat tidak mencukupi!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengupdate: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _refreshData() async {  
    setState(() {
      _obatListFuture = ObatService.getObatList();
    });
  }

  Future<void> _navigateToInputPage({Obat? obat}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ObatInputPage(obat: obat),
      ),
    );
    if (mounted) _refreshData();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _confirmDelete(Obat obat) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Obat?'),
          content: Text('Apakah Anda yakin ingin menghapus ${obat.nama}? Tindakan ini tidak dapat dibatalkan.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Batal
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // Hapus
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await ObatService.deleteObat(obat.nama); 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${obat.nama} berhasil dihapus')),
          );
          _refreshData(); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus ${obat.nama}: ${e.toString()}')),
          );
        }
      }
    }
  }

  List<Obat> _filterObatList(List<Obat> obatList, String query) {
    if (query.isEmpty) return obatList;
    return obatList.where((obat) =>
      obat.nama.toLowerCase().contains(query.toLowerCase())).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF388E3C), 
        title: const Text(
          'Daftar Obat',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToInputPage(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Obat'),
        backgroundColor: const Color(0xFF66BB6A), 
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionIcon(
                  icon: Icons.chat,
                  label: 'Chatbot',
                  onTap: () => Navigator.pushNamed(context, '/chatbot'),
                ),
                _buildActionIcon(
                  icon: Icons.history,
                  label: 'Riwayat',
                  onTap: () => Navigator.pushNamed(context, '/obat-history'),
                ),
                _buildActionIcon(
                  icon: Icons.logout,
                  label: 'Logout',
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<Obat>>(
              future: _obatListFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  //_hasError = true;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Gagal memuat data obat'),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                }

                final obatList = _filterObatList(
                  snapshot.data ?? [],
                  _searchController.text,
                );

                if (obatList.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada obat tersedia'),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Cari Obat',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFE9FCEB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshData,
                        child: ListView.builder(
                          itemCount: obatList.length,
                          itemBuilder: (context, index) {
                            final obat = obatList[index];
                            return _buildObatCard(obat);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        ]
      )
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFF26A69A),
            child: Icon(icon, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildObatCard(Obat obat) {
    return Card(
      elevation: 2,
      color: const Color(0xFFE9FCEB), // light pastel green
      shadowColor: Colors.green.shade200,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFA8D5BA), width: 1.2),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        height: 130,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          title: Text(
            obat.nama,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                'Stok: ${obat.qty}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                'Dosis: ${obat.jumlahPerDosis}x${obat.dosisPerHari}/hari',
                style: const TextStyle(fontSize: 16),
              ),
              // Text(
              //   'Jadwal: ${obat.jadwal.map((t) => t.format(context)).join(', ')}',
              //   style: const TextStyle(fontSize: 16),
              // ),
              if (obat.perluBeliObat())
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Perlu beli obat!',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
            ],
          ),
           trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                icon: const Icon(Icons.medical_services, size: 30, color: Color(0xFF4CAF50)),
                onPressed: () => _confirmTaken(obat),
                tooltip: 'Konfirmasi Minum Obat',
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 30, color: Colors.teal),
                onPressed: () => _navigateToInputPage(obat: obat),
                tooltip: 'Edit Obat',
              ),
            ],
          ),
          onTap: () => _showObatDetails(context, obat),
        ),
      ),
    );
  }

  void _showObatDetails(BuildContext context, Obat obat) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                obat.nama,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Stok', obat.qty.toString()),
              _buildDetailRow('Dosis', '${obat.jumlahPerDosis}x${obat.dosisPerHari}/hari'),
              _buildDetailRow('Kebutuhan Harian', '${obat.kebutuhanPerHari} tablet/hari'),
              _buildDetailRow(
                'Tanggal Pembelian',
                DateFormat('dd/MM/yyyy').format(obat.purchaseDate),
              ),
              _buildDetailRow(
                'Perlu Beli Lagi',
                DateFormat('dd/MM/yyyy').format(obat.nextPurchaseDate),
              ),
              _buildDetailRow('Catatan', obat.usageNotes),
              const SizedBox(height: 16),
              const Text(
                'Jadwal Minum:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...obat.jadwal.map((time) => Text(time.format(context))),
              const SizedBox(height: 16),
              const Text(
                'Riwayat Penggunaan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...obat.takenDates.map((date) => 
                Text(DateFormat('dd/MM/yyyy HH:mm').format(date)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}