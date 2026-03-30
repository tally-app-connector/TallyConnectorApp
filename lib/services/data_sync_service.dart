import 'cloud_to_local_sync_service.dart';
import '../database/database_helper.dart';

class DataSyncService {
  static final DataSyncService instance = DataSyncService._init();
  DataSyncService._init();

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  Future<void> syncCompany(
    String companyGuid, {
    void Function(String tableName, double progress)? onProgress,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await CloudToLocalSyncService.instance.fullSync(db, companyGuid);
      _lastSyncTime = DateTime.now();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, int>> getLocalRowCounts(String companyGuid) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final tables = [
        'vouchers',
        'ledgers',
        'stock_items',
        'groups',
        'cost_centres',
        'currencies',
        'units',
      ];
      final counts = <String, int>{};
      for (final table in tables) {
        try {
          final result = await db.rawQuery(
            'SELECT COUNT(*) as cnt FROM $table WHERE company_guid = ?',
            [companyGuid],
          );
          counts[table] = (result.first['cnt'] as int?) ?? 0;
        } catch (_) {
          counts[table] = 0;
        }
      }
      return counts;
    } catch (_) {
      return {};
    }
  }
}
