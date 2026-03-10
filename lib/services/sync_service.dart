import 'package:tally_connector/utils/date_utils.dart';
import 'package:tally_connector/utils/secure_storage.dart';
import '../models/data_model.dart';
import './tally_service.dart';
import './neon_sync_service.dart';
import './aws_sync_service.dart';
import '../database/database_helper.dart';
import 'package:xml/xml.dart';
import './tally_xml_parser.dart';

class SyncService {
  final TallyService _tallyService = TallyService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final AwsSyncService _awsSync = AwsSyncService.instance;

  Future syncCompany({bool neonSync = false}) async {
    try {
      // if (neonSync) {
      //   await _neonSync.initialize();
      // }

      final companyXml = await _tallyService.getCompanies();
      final companies = TallyXmlParser.parseCompanies(companyXml);
      await _db.saveCompanyBatch(companies);

      // final now = DateTime.now().millisecondsSinceEpoch;
      // final syncedCompanies = <Map<String, dynamic>>[];

      // // ✅ Loop through ALL companies
      // for (var companyElement in companyElements) {
      //   final guid =
      //       companyElement.findElements('GUID').firstOrNull?.innerText ?? '';
      //   final name =
      //       companyElement.findElements('NAME').firstOrNull?.innerText ?? '';

      //   String address = '';
      //   final addressList =
      //       companyElement.findElements('ADDRESS.LIST').firstOrNull;
      //   if (addressList != null) {
      //     final addressLines = addressList
      //         .findElements('ADDRESS')
      //         .map((e) => e.innerText)
      //         .toList();
      //     address = addressLines.join(', ');
      //   } else {
      //     address =
      //         companyElement.findElements('ADDRESS').firstOrNull?.innerText ??
      //             '';
      //   }

      //   final userId = await SecureStorage.getUserEmail();

      //   if (guid.isEmpty || name.isEmpty || userId == null) {
      //     continue;
      //   }

      //   final companyData = {
      //     'company_guid': guid,
      //     'user_id': userId,
      //     'company_name': name,
      //     'last_sync_timestamp': now,
      //     'last_synced_alter_id': 0,
      //     'create_timestamp': now,
      //     'company_address': address,
      //   };

      //   print('📊 Company: $name (GUID: $guid)');

      //   await _db.upsertCompany(companyData);
      //   print('✅ Company saved to local database');

      //   if (neonSync) {
      //     print('☁️  Uploading company info to Neon...');
      //     await _neonSync.syncCompany(companyData);
      //     print('✅ Company info uploaded to Neon');
      //   }

      //   syncedCompanies.add({
      //     'company_guid': guid,
      //     'name': name,
      //   });
      // }

      // print(
      //     '✅ Company sync complete! Synced ${syncedCompanies.length} companies');

      // return {
      //   'success': true,
      //   'company_count': syncedCompanies.length,
      //   'companies': syncedCompanies,
      //   'synced_to_local': true,
      //   'synced_to_neon': neonSync,
      // };
    } catch (e) {
      print('❌ Error syncing company: $e');
    } finally {
      // if (neonSync) {
      //   await _neonSync.close();
      // }
    }
  }

  /// Sync all master data (ledgers, groups, stock items, voucher types)
  
    Future<Map<String, int>> syncIncrementalData({
    bool neonSync = false,
  }) async {
    int groupCount = 0;
    int ledgerCount = 0;
    int stockItemCount = 0;
    int voucherTypeCount = 0;

    final company = await _db.getSelectedCompanyByGuid();
    final String? companyId = company?['company_guid'];
    final String? companyName = company?['company_name'];
    final String companyStart =
        company?['starting_from'] ?? getCurrentFyStartDate();

    if (companyName == null || companyId == null) {
      return {
        'ledgers': 0,
        'groups': 0,
        'stock_items': 0,
        'voucher_types': 0,
      };
    }

    try {
      // if (neonSync) {
      //   await _neonSync.initialize();
      // }

      await _syncGroups(companyName, companyId, company?['last_synced_groups_alter_id'] ?? 0);

      await _syncLedgers(companyName, companyId, company?['last_synced_ledgers_alter_id'] ?? 0);

      await _syncStockItems(companyName, companyId, company?['last_synced_stock_items_alter_id'] ?? 0);

      await _syncVoucherTypes(companyName, companyId, company?['last_synced_voucher_types_alter_id'] ?? 0);

      await _syncVouchers(companyName, companyId, companyStart, company?['last_synced_vouchers_alter_id'] ?? 0);

      print("all data synced");

      // // ✅ Sync Groups
      // final groupsXml = await _tallyService.getGroups(
      //     companyName, company?['last_synced_alter_id'] ?? 0);
      // await _syncGroups(groupsXml, companyId, neonSync: neonSync);

      // // ✅ Sync Ledgers
      // print('📒 Syncing ledgers...');
      // final Map<String, String> groupNameToGuid = {};
      // final db = await _db.database;
      // final allGroups = await db.query('groups'); // Fetch ALL groups from DB
      // for (var group in allGroups) {
      //   groupNameToGuid[group['group_name'] as String] =
      //       group['group_guid'] as String;
      // }
      // print('📋 Built group map with ${groupNameToGuid.length} groups');
      // final ledgersXml = await _tallyService.getLedgers(
      //     companyName, company?['last_synced_alter_id'] ?? 0);
      // await _syncLedgers(ledgersXml, companyId,
      //     groupNameToGuid: groupNameToGuid, neonSync: neonSync); // Pass map

      //     final batches = await _tallyService.getCompleteVouchersInBatches(companyName, 5457);

      // for (int i = 0; i < batches.length; i++) {
      //   print('Processing batch ${i + 1}/${batches.length}');

      //   // Parse XML to structured data
      //   final vouchers = TallyXmlParser.parseVouchers(batches[i]);

      //   print('Parsed ${vouchers.length} vouchers');

      //   // Save to database
      //   for (final voucher in vouchers) {
      //     print('Voucher: ${voucher.voucherType} - ${voucher.voucherNumber}');
      //     print('  Date: ${voucher.date}');
      //     print('  Party: ${voucher.partyLedgerName}');

      //     // Ledger Entries
      //     for (final ledger in voucher.ledgerEntries) {
      //       print('  Ledger: ${ledger.ledgerName} = ${ledger.amount}');
      //     }

      //     // Inventory Entries
      //     for (final inventory in voucher.inventoryEntries) {
      //       print('  Item: ${inventory.stockItemName} x ${inventory.actualQty} @ ${inventory.rate}');
      //     }

      //     // Save to database
      //     // await saveVoucherToDatabase(voucher);
      //   }
      // }

      // print('✅ All vouchers synced!');

      //   final stockItemsData = await _syncStockItems(stockItemsXml);
      //   stockItemCount = stockItemsData['count'];
      //   print('✅ Synced $stockItemCount stock items');

      //   // Update timestamp in company table
      //   if (companyId != null) {
      //     final maxAlterId = stockItemsData['max_alter_id'] as int? ?? 0;
      //     if (maxAlterId > 0){
      //       await _db.updateCompany(companyId, {
      //                 'last_synced_stock_items_alter_id': maxAlterId,
      //                 'sync_date': DateTime.now().millisecondsSinceEpoch,
      //               });
      //     }
      //     if (neonSync) {
      //       await _neonSync.updateSyncTimestampForEntity(
      //         companyId,
      //         'stock_items',
      //         maxAlterId,
      //       );
      //     }
      //   }

      //   // ✅ Sync Voucher Types
      //   print('📝 Syncing voucher types...');
      //   final voucherTypesXml = await _tallyService.getVoucherTypes();
      //   final voucherTypesData = await _syncVoucherTypes(voucherTypesXml);
      //   voucherTypeCount = voucherTypesData['count'];
      //   print('✅ Synced $voucherTypeCount voucher types');

      //   // Update timestamp in company table
      //   if (companyId != null) {
      //     final maxAlterId = voucherTypesData['max_alter_id'] as int? ?? 0;
      //     if (maxAlterId > 0){
      //       await _db.updateCompany(companyId, {
      //                 'last_synced_voucher_types_alter_id': maxAlterId,
      //                 'sync_date': DateTime.now().millisecondsSinceEpoch,
      //               });
      //     }
      //     if (neonSync) {
      //       await _neonSync.updateSyncTimestampForEntity(
      //         companyId,
      //         'voucher_types',
      //         maxAlterId,
      //       );
      //     }
      //   }

      //   // ✅ Upload to Neon (if enabled)
      //   if (neonSync) {
      //     print('\n☁️  Uploading master data to Neon...');

      //     await _neonSync.syncGroups(groupsData['data']['groups'],companyId!);
      //     await _neonSync.syncLedgers(ledgersData['data']['ledgers'],companyId);
      //     await _neonSync.syncStockItems(stockItemsData['data']['stock_items'],companyId);
      //     await _neonSync.syncVoucherTypes(voucherTypesData['data']['voucher_types'],companyId);

      //     print('✅ Master data uploaded to Neon');
      //   }

      return {
        'ledgers': ledgerCount,
        'groups': groupCount,
        'stock_items': stockItemCount,
        'voucher_types': voucherTypeCount,
      };
    } catch (e) {
      print('❌ Error syncing master data: $e');
      rethrow;
    } finally {
      // if (neonSync) {
      //   await _neonSync.close();
      // }
    }
  }

  Future<Map<String, int>> syncAllData({
    bool neonSync = false,
  }) async {
    int groupCount = 0;
    int ledgerCount = 0;
    int stockItemCount = 0;
    int voucherTypeCount = 0;

    final company = await _db.getSelectedCompanyByGuid();
    final String? companyId = company?['company_guid'];
    final String? companyName = company?['company_name'];
    final String companyStart =
        company?['starting_from'] ?? getCurrentFyStartDate();

    if (companyName == null || companyId == null) {
      return {
        'ledgers': 0,
        'groups': 0,
        'stock_items': 0,
        'voucher_types': 0,
      };
    }

    try {
      // if (neonSync) {
      //   await _neonSync.initialize();
      // }

      await _syncGroups(companyName, companyId, 0);

      await _syncLedgers(companyName, companyId, 0);

      await _syncStockItems(companyName, companyId, 0);

      await _syncVoucherTypes(companyName, companyId, 0);

      await _syncAllVouchers(companyName, companyId, companyStart, 0);

      print("all data synced");

      // // ✅ Sync Groups
      // final groupsXml = await _tallyService.getGroups(
      //     companyName, company?['last_synced_alter_id'] ?? 0);
      // await _syncGroups(groupsXml, companyId, neonSync: neonSync);

      // // ✅ Sync Ledgers
      // print('📒 Syncing ledgers...');
      // final Map<String, String> groupNameToGuid = {};
      // final db = await _db.database;
      // final allGroups = await db.query('groups'); // Fetch ALL groups from DB
      // for (var group in allGroups) {
      //   groupNameToGuid[group['group_name'] as String] =
      //       group['group_guid'] as String;
      // }
      // print('📋 Built group map with ${groupNameToGuid.length} groups');
      // final ledgersXml = await _tallyService.getLedgers(
      //     companyName, company?['last_synced_alter_id'] ?? 0);
      // await _syncLedgers(ledgersXml, companyId,
      //     groupNameToGuid: groupNameToGuid, neonSync: neonSync); // Pass map

      //     final batches = await _tallyService.getCompleteVouchersInBatches(companyName, 5457);

      // for (int i = 0; i < batches.length; i++) {
      //   print('Processing batch ${i + 1}/${batches.length}');

      //   // Parse XML to structured data
      //   final vouchers = TallyXmlParser.parseVouchers(batches[i]);

      //   print('Parsed ${vouchers.length} vouchers');

      //   // Save to database
      //   for (final voucher in vouchers) {
      //     print('Voucher: ${voucher.voucherType} - ${voucher.voucherNumber}');
      //     print('  Date: ${voucher.date}');
      //     print('  Party: ${voucher.partyLedgerName}');

      //     // Ledger Entries
      //     for (final ledger in voucher.ledgerEntries) {
      //       print('  Ledger: ${ledger.ledgerName} = ${ledger.amount}');
      //     }

      //     // Inventory Entries
      //     for (final inventory in voucher.inventoryEntries) {
      //       print('  Item: ${inventory.stockItemName} x ${inventory.actualQty} @ ${inventory.rate}');
      //     }

      //     // Save to database
      //     // await saveVoucherToDatabase(voucher);
      //   }
      // }

      // print('✅ All vouchers synced!');

      //   final stockItemsData = await _syncStockItems(stockItemsXml);
      //   stockItemCount = stockItemsData['count'];
      //   print('✅ Synced $stockItemCount stock items');

      //   // Update timestamp in company table
      //   if (companyId != null) {
      //     final maxAlterId = stockItemsData['max_alter_id'] as int? ?? 0;
      //     if (maxAlterId > 0){
      //       await _db.updateCompany(companyId, {
      //                 'last_synced_stock_items_alter_id': maxAlterId,
      //                 'sync_date': DateTime.now().millisecondsSinceEpoch,
      //               });
      //     }
      //     if (neonSync) {
      //       await _neonSync.updateSyncTimestampForEntity(
      //         companyId,
      //         'stock_items',
      //         maxAlterId,
      //       );
      //     }
      //   }

      //   // ✅ Sync Voucher Types
      //   print('📝 Syncing voucher types...');
      //   final voucherTypesXml = await _tallyService.getVoucherTypes();
      //   final voucherTypesData = await _syncVoucherTypes(voucherTypesXml);
      //   voucherTypeCount = voucherTypesData['count'];
      //   print('✅ Synced $voucherTypeCount voucher types');

      //   // Update timestamp in company table
      //   if (companyId != null) {
      //     final maxAlterId = voucherTypesData['max_alter_id'] as int? ?? 0;
      //     if (maxAlterId > 0){
      //       await _db.updateCompany(companyId, {
      //                 'last_synced_voucher_types_alter_id': maxAlterId,
      //                 'sync_date': DateTime.now().millisecondsSinceEpoch,
      //               });
      //     }
      //     if (neonSync) {
      //       await _neonSync.updateSyncTimestampForEntity(
      //         companyId,
      //         'voucher_types',
      //         maxAlterId,
      //       );
      //     }
      //   }

      //   // ✅ Upload to Neon (if enabled)
      //   if (neonSync) {
      //     print('\n☁️  Uploading master data to Neon...');

      //     await _neonSync.syncGroups(groupsData['data']['groups'],companyId!);
      //     await _neonSync.syncLedgers(ledgersData['data']['ledgers'],companyId);
      //     await _neonSync.syncStockItems(stockItemsData['data']['stock_items'],companyId);
      //     await _neonSync.syncVoucherTypes(voucherTypesData['data']['voucher_types'],companyId);

      //     print('✅ Master data uploaded to Neon');
      //   }

      return {
        'ledgers': ledgerCount,
        'groups': groupCount,
        'stock_items': stockItemCount,
        'voucher_types': voucherTypeCount,
      };
    } catch (e) {
      print('❌ Error syncing master data: $e');
      rethrow;
    } finally {
      // if (neonSync) {
      //   await _neonSync.close();
      // }
    }
  }

  // Future _syncGroups(String xml, String companyId,
  //     {bool neonSync = false}) async {
  //   final document = XmlDocument.parse(xml);
  //   final groups = document.findAllElements('GROUP');

  //   final List<Map<String, dynamic>> groupsList = [];

  //   print('\n📁 [_syncGroups] Processing ${groups.length} groups...');

  //   for (var group in groups) {
  //     try {
  //       final name = group.findElements('NAME').firstOrNull?.innerText ?? '';
  //       if (name.isEmpty) continue;
  //       final alterId = _parseAmountValueInt(
  //           group.findElements('ALTERID').firstOrNull?.innerText ?? '');

  //       final groupData = {
  //         'group_guid': group.findElements('GUID').firstOrNull?.innerText ?? '',
  //         'group_name': name,
  //         'group_parent_name':
  //             cleanTallyValue(group.findElements('PARENT').firstOrNull?.innerText ?? ''),
  //         'group_alias':
  //             group.findElements('ALIAS').firstOrNull?.innerText ?? '',
  //         'alter_id': alterId,
  //       };

  //       // await _db.insertGroup(groupData);

  //       await _db.upsert(
  //         table: 'groups',
  //         data: groupData,
  //         uniqueColumn: 'group_guid',
  //       );

  //       groupsList.add(groupData);
  //     } catch (e) {
  //       print('Error inserting group: $e');
  //     }
  //   }

  //   if (neonSync) {
  //     await _neonSync.syncGroups(groupsList, companyId);
  //   }

  //   final maxAlterId = groupsList
  //       .map((g) => g['alter_id'] as int? ?? 0)
  //       .fold(0, (max, id) => id > max ? id : max);

  //   if (maxAlterId > 0) {
  //     await _db.updateCompany(companyId, {
  //       'last_synced_alter_id': maxAlterId,
  //       'last_sync_timestamp': DateTime.now().millisecondsSinceEpoch,
  //     });

  //     if (neonSync) {
  //       await _neonSync.updateCompany(
  //           companyId, "last_synced_alter_id", maxAlterId);
  //     }
  //   }
  // }

  // Future _syncLedgers(String xml, String companyId,
  //     {Map<String, String>? groupNameToGuid, bool neonSync = false}) async {
  //   print('\n📊 [_syncLedgers] Processing ledgers...');

  //   final document = XmlDocument.parse(xml);
  //   final ledgers = document.findAllElements('LEDGER');

  //   final List<Map<String, dynamic>> ledgersList = [];

  //   for (var ledger in ledgers) {
  //     try {
  //       final name = ledger.findElements('NAME').firstOrNull?.innerText ?? '';
  //       if (name.isEmpty) continue;

  //       final parent = cleanTallyValue(ledger.findElements('PARENT').firstOrNull?.innerText ?? '');

  //       final openingBalanceText =
  //           ledger.findElements('OPENINGBALANCE').firstOrNull?.innerText ?? '0';
  //       final closingBalanceText =
  //           ledger.findElements('CLOSINGBALANCE').firstOrNull?.innerText ?? '0';

  //       double openingBalance = _parseBalanceSimple(openingBalanceText);
  //       double closingBalance = _parseBalanceSimple(closingBalanceText);
  //       String address = '';
  //       final addressList = ledger.findElements('ADDRESS.LIST').firstOrNull;
  //       if (addressList != null) {
  //         final addressLines = addressList
  //             .findElements('ADDRESS')
  //             .map((e) => e.innerText)
  //             .toList();
  //         address = addressLines.join(', ');
  //       } else {
  //         address = ledger.findElements('ADDRESS').firstOrNull?.innerText ?? '';
  //       }

  //       final gstin =
  //           ledger.findElements('PARTYGSTIN').firstOrNull?.innerText ??
  //               ledger.findElements('GSTIN').firstOrNull?.innerText ??
  //               '';

  //       final pan =
  //           ledger.findElements('INCOMETAXNUMBER').firstOrNull?.innerText ??
  //               ledger.findElements('PAN').firstOrNull?.innerText ??
  //               '';

  //       final creditLimitText =
  //           ledger.findElements('CREDITLIMIT').firstOrNull?.innerText ?? '0';
  //       final creditLimit = double.tryParse(
  //               creditLimitText.replaceAll(RegExp(r'[^\d.-]'), '')) ??
  //           0.0;

  //       final creditDaysText =
  //           ledger.findElements('CREDITDAYS').firstOrNull?.innerText ??
  //               ledger.findElements('CREDITPERIOD').firstOrNull?.innerText ??
  //               '0';
  //       final creditDays =
  //           int.tryParse(creditDaysText.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  //       final isDebitLedger =
  //           ledger.findElements('ISDEBITLEDGER').firstOrNull?.innerText ?? '';
  //       final isDebitGroup =
  //           ledger.findElements('ISDEBITGROUP').firstOrNull?.innerText ?? '';
  //       final gstRegistrationType =
  //           ledger.findElements('GSTREGISTRATIONTYPE').firstOrNull?.innerText ??
  //               '';
  //       final alterId = _parseAmountValueInt(
  //           ledger.findElements('ALTERID').firstOrNull?.innerText ?? '');
  //       final ledgerData = {
  //         'ledger_guid':
  //             ledger.findElements('GUID').firstOrNull?.innerText ?? '',
  //         'ledger_name': name,
  //         'parent_name': parent,
  //         'parent_guid': groupNameToGuid?[parent] ?? '',
  //         'opening_balance': openingBalance,
  //         'closing_balance': closingBalance,
  //         'ledger_gstin': gstin,
  //         'credit_limit': creditLimit,
  //         'credit_days': creditDays,
  //         'is_debit_ledger': isDebitLedger,
  //         'is_debit_group': isDebitGroup,
  //         'gst_registration_type': gstRegistrationType,
  //         'alter_id': alterId,
  //         'ledger_pan': pan,
  //         'ledger_address': address
  //       };

  //       // await _db.insertLedger(ledgerData);
  //       await _db.upsert(
  //         table: 'ledgers',
  //         data: ledgerData,
  //         uniqueColumn: 'ledger_guid',
  //       );
  //       ledgersList.add(ledgerData);
  //     } catch (e) {
  //       print('❌ Error inserting ledger: $e');
  //     }
  //   }

  //   if (neonSync) {
  //     await _neonSync.syncLedgers(ledgersList, companyId);
  //   }

  //   final maxAlterId = ledgersList
  //       .map((l) => l['alter_id'] as int? ?? 0)
  //       .fold(0, (max, id) => id > max ? id : max);

  //   if (maxAlterId > 0) {
  //     await _db.updateCompany(companyId, {
  //       'last_synced_alter_id': maxAlterId,
  //       'last_sync_timestamp': DateTime.now().millisecondsSinceEpoch,
  //     });

  //     if (neonSync) {
  //       await _neonSync.updateCompany(
  //           companyId, "last_synced_alter_id", maxAlterId);
  //     }
  //   }
  // }

  Future _syncStockItems(
      String companyName, String companyId, int lastAlterId) async {
    final xml = await _tallyService.getAllStockItems(companyName, lastAlterId);
    final allClosingData = await _tallyService.getStockClosingBalances(companyName);
    
    final stockItems = TallyXmlParser.parseStockItems(xml);
    // final stockItemMonthWiseClosingData = closingBalanceXmlArray.map((monthXml) => TallyXmlParser.parseStockItemClosingBalances(monthXml));
  // ✅ Flatten all months into one big list
  

    if (stockItems.isNotEmpty) {
      await _db.saveStockItemBatch(stockItems, allClosingData, companyId);

      // Get max alterId from synced vouchers
      final maxAlterId =
          stockItems.map((s) => s.alterid).reduce((a, b) => a > b ? a : b);

      if (maxAlterId > 0) {
        await _db.updateSyncTracking(companyId,
            lastSyncedStockItemsAlterId: maxAlterId);
      }
    }
  }

  Future _syncGroups(
      String companyName, String companyId, int lastAlterId) async {
    final xml = await _tallyService.getAllGroups(companyName, lastAlterId);
    final groups = TallyXmlParser.parseGroups(xml, companyId);

    // await populateGroupRelationships(groups);

    if (groups.isNotEmpty) {
      await _db.processNewGroups(groups, companyId);

      // Get max alterId from synced vouchers
      final maxAlterId =
          groups.map((g) => g.alterId).reduce((a, b) => a > b ? a : b);

      if (maxAlterId > 0) {
        await _db.updateSyncTracking(companyId,
            lastSyncedGroupsAlterId: maxAlterId);
      }
    }
  }

  Future _syncLedgers(
      String companyName, String companyId, int lastAlterId) async {
    final xml = await _tallyService.getAllLedgers(companyName, lastAlterId);
    final ledgers = TallyXmlParser.parseLedgers(xml);

    if (ledgers.isNotEmpty) {
      await _db.saveLedgerBatch(ledgers, companyId);

      // Get max alterId from synced vouchers
      final maxAlterId =
          ledgers.map((l) => l.alterid).reduce((a, b) => a > b ? a : b);

      if (maxAlterId > 0) {
        await _db.updateSyncTracking(companyId,
            lastSyncedLedgersAlterId: maxAlterId);
      }
    }
  }

  Future _syncVouchers(String companyName, String companyId, String companyStartDate, int lastAlterId) async {
    final xml = await _tallyService.getNewVouchers(companyName, lastAlterId);
    final vouchers = TallyXmlParser.parseVouchers(xml);

    if (vouchers.isNotEmpty){
      await _db.saveVoucherBatch(vouchers, companyId);

      final maxAlterId = vouchers.map((v) => v.alterId).reduce((a, b) => a > b ? a : b);
      if (maxAlterId > lastAlterId) {
        await _db.updateSyncTracking(
          companyId,
          lastSyncedVouchersAlterId: maxAlterId,
        );
      }
    }

    // await detectAndDeleteMissingVouchers(companyName, companyId);

  }

    Future _syncVoucherTypes(String companyName, String companyId, int lastAlterId) async {
    final xml = await _tallyService.getVoucherTypes(companyName, lastAlterId);
    final voucherTypes = TallyXmlParser.parseVoucherTypes(xml, companyId);

    // await populateGroupRelationships(groups);

    if (voucherTypes.isNotEmpty) {
      await _db.processNewVoucherTypes(voucherTypes, companyId);

      // Get max alterId from synced vouchers
      final maxAlterId =
          voucherTypes.map((g) => g.alterId).reduce((a, b) => a > b ? a : b);

      if (maxAlterId > 0) {
        await _db.updateSyncTracking(companyId,
            lastSyncedVoucherTypesAlterId: maxAlterId);
      }
    }
  }


  Future _syncAllVouchers(String companyName, String companyId,
      String companyStartDate, int lastAlterId) async {
    final startDate = DateTime.parse(companyStartDate);
    

    final now = DateTime.now();

    // Generate financial year ranges
    List<Map<String, String>> fyRanges = [];

    // Determine first FY start: April 1 of that year, or previous year if before April
    int fyStartYear =
        startDate.month >= 4 ? startDate.year : startDate.year - 1;

    while (true) {
      final fyStart = DateTime(fyStartYear, 4, 1);
      final fyEnd = DateTime(fyStartYear + 1, 3, 31);

      // Skip if this FY ends before company start
      if (fyEnd.isBefore(startDate)) {
        fyStartYear++;
        continue;
      }

      // Effective start: use company start date if it falls within this FY
      final effectiveStart = fyStart;
      // Effective end: use today if current FY hasn't ended
      final effectiveEnd = fyEnd;

      final startStr = _formatDate(effectiveStart);
      final endStr = _formatDate(effectiveEnd);

      fyRanges.add({'start': startStr, 'end': endStr});

      if (fyEnd.isAfter(now) || fyEnd.isAtSameMomentAs(now)) break;
      fyStartYear++;
    }

    // Sync vouchers for each financial year
    for (final fy in fyRanges) {

      final results = await _tallyService
          .getAllVouchersBatched(companyName, fy['start']!, fy['end']!,
              onProgress: (fetched, total) {
        print('Fetched $fetched / $total'); // or update your UI
      });

      final vouchers =
          results.expand((xml) => TallyXmlParser.parseVouchers(xml)).toList();

      if (vouchers.isNotEmpty) {
        await _db.saveVoucherBatch(vouchers, companyId);

        final maxAlterId =
            vouchers.map((v) => v.alterId).reduce((a, b) => a > b ? a : b);
        if (maxAlterId > lastAlterId) {
          lastAlterId = maxAlterId;
          await _db.updateSyncTracking(
            companyId,
            lastSyncedVouchersAlterId: maxAlterId,
          );
        }
      }

      // for (final xml in results){
      //     final vouchers = TallyXmlParser.parseVouchers(xml);
      //     if (vouchers.isNotEmpty) {
      //       await _db.saveVoucherBatch(vouchers, companyId);

      //       final maxAlterId = vouchers.map((v) => v.alterId).reduce((a, b) => a > b ? a : b);
      //       if (maxAlterId > lastAlterId) {
      //         lastAlterId = maxAlterId;
      //         await _db.updateSyncTracking(
      //           companyId,
      //           lastSyncedVouchersAlterId: maxAlterId,
      //         );
      //       }
      //     }
      // }
    }

    // await detectAndDeleteMissingVouchers(companyName, companyId);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> detectAndDeleteMissingVouchers() async {
    print('🔍 Checking for deleted vouchers...');

    final company = await _db.getSelectedCompanyByGuid();
    final String? companyId = company?['company_guid'];
    final String? companyName = company?['company_name'];
    final String companyStart =
        company?['starting_from'] ?? getCurrentFyStartDate();
    final String currentYearEndDate = getCurrentFyEndDate();

        
    final startDate = DateTime.parse(companyStart);
    final endDate = DateTime.parse(currentYearEndDate);

if (companyName == null || companyId == null) {
      return ;
    }
    try {
      // Step 1: Get all GUIDs from Tally
      final tallyXml = await _tallyService.getAllVouchersGuid(companyName, _formatDate(startDate), _formatDate(endDate));
      final tallyGuids = TallyXmlParser.parseVoucherGuids(tallyXml);

      if (tallyGuids.isEmpty) {
        print('⚠️ No GUIDs found in Tally response');
        return;
      }

      print('📊 Tally has ${tallyGuids.length} vouchers');

      // Step 2: Get all GUIDs from database
      final dbVouchers = await _db.getAllVoucherGuids(companyId);

      print('📊 Database has ${dbVouchers.length} vouchers');

      // Step 3: Find vouchers in DB but NOT in Tally
      final deletedGuids = <String>[];

      for (var dbVoucher in dbVouchers) {
        final guid = dbVoucher['voucher_guid']?.toString() ?? '';
        if (guid.isNotEmpty && !tallyGuids.contains(guid)) {
          deletedGuids.add(guid);
          print(
              '🗑️ Will delete: ${dbVoucher['voucher_number']} (GUID: $guid)');
        }
      }

      if (deletedGuids.isEmpty) {
        print('✅ No deleted vouchers found');
        return;
      }

      print('🗑️ Found ${deletedGuids.length} deleted vouchers');

      // Step 4: Delete them from database
      await _db.deleteVouchersByGuids(deletedGuids, companyId);

      print('✅ Cleanup complete! Removed ${deletedGuids.length} vouchers');
    } catch (e) {
      print('❌ Error in delete detection: $e');
      rethrow;
    }
  }


  String cleanTallyValue(String value) {
    return value
        .replaceAll('&#4;', '') // Remove &#4;
        .trim(); // Remove leading/trailing spaces
  }

  // Function to populate childIds using parent name
// Future<void> populateGroupRelationships(List<Group> groups) async {
//   // Create a map: name -> group for quick lookup
//     Map<String, Group> nameToGroupMap = {for (var g in groups) g.name: g};

//     // Step 1: Populate parentId for each group
//     for (var group in groups) {
//       if (group.parent != null) {
//         var parentGroup = nameToGroupMap[group.parent];
//         if (parentGroup != null) {
//           group.parentGuid = parentGroup.groupGuid;
//           group.parent = parentGroup.reservedName ?? parentGroup.name;
//         }
//       }
//     }

//     // Step 2: Populate childIds for each group
//     Set<String> getAllDescendants(String groupName) {
//       Set<String> descendants = {};

//       // Find direct children (where parent name matches this group's name)
//       List<Group> directChildren = groups.where((g) => g.parent == groupName).toList();

//       for (var child in directChildren) {
//         // Add direct child ID
//         descendants.add(child.groupGuid);

//         // Add all descendants of this child (recursive using child's name)
//         descendants.addAll(getAllDescendants(child.name));
//       }

//       return descendants;
//     }

//     for (var group in groups) {
//       group.childGuids = getAllDescendants(group.name);
//     }
//   }
}
