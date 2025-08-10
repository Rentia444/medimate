import 'history_service.dart';
import 'obat_service.dart';

class TestHelper {
  static Future<void> fullReset() async {
    await HistoryService.clearHistory();
    await ObatService.clearAll();
  }
}