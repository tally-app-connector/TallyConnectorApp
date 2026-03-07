export '../../services/aws_sync_service.dart';

// Extension to provide schema helpers used by mobile screens.
// The actual AwsSyncService is in lib/services/aws_sync_service.dart.
// These are no-op stubs so screens compile without direct DB schema ops.
import '../../services/aws_sync_service.dart';

extension AwsSyncServiceMobileExt on AwsSyncService {
  String getSchemaName(String companyGuid) {
    return 'company_${companyGuid.replaceAll('-', '_')}';
  }

  Future<void> createViewsIfNeeded(String schema) async {
    // No-op on mobile — views are created server-side
  }
}
