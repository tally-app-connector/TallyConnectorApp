import 'dart:convert';

// models/company.dart

class Company {
  final String guid;
  final int masterId;
  final int alterId;
  final String name;
  final String? reservedName;

  // Dates
  final String startingFrom;
  final String endingAt;
  final String? booksFrom;
  final String? booksBeginningFrom;
  final String? gstApplicableDate;

  // Contact Details
  final String? email;
  final String? phoneNumber;
  final String? faxNumber;
  final String? website;

  // Address
  final String? address;
  final String? city;
  final String? pincode;
  final String? state;
  final String? country;

  // Tax Details
  final String? incomeTaxNumber;
  final String? pan;
  final String? gsttin;

  // Currency
  final String? currencyName;
  final String? baseCurrencyName;

  // Accounting Features
  final bool maintainAccounts;
  final bool maintainBillWise;
  final bool enableCostCentres;
  final bool enableInterestCalc;

  // Inventory Features
  final bool maintainInventory;
  final bool integrateInventory;
  final bool multiPriceLevel;
  final bool enableBatches;
  final bool maintainExpiryDate;
  final bool enableJobOrderProcessing;
  final bool enableCostTracking;
  final bool enableJobCosting;
  final bool useDiscountColumn;
  final bool useSeparateActualBilledQty;

  // Tax Features
  final bool isGstApplicable;
  final bool setAlterCompanyGstRate;
  final bool isTdsApplicable;
  final bool isTcsApplicable;
  final bool isVatApplicable;
  final bool isExciseApplicable;
  final bool isServiceTaxApplicable;

  // Online Access Features
  final bool enableBrowserReports;
  final bool enableTallyNet;

  // Payroll Features
  final bool isPayrollEnabled;
  final bool enablePayrollStatutory;

  // Other Features
  final bool enablePaymentLinkQr;
  final bool enableMultiAddress;
  final bool markModifiedVouchers;

  // Status
  final bool isDeleted;
  final bool isAudited;
  final bool isSecurityEnabled;
  final bool isBookInUse;

  // Sync tracking
  final int lastSyncedGroupsAlterId;
  final int lastSyncedLedgersAlterId;
  final int lastSyncedStockItemsAlterId;
  final int lastSyncedVouchersAlterId;
  final int lastSyncedVoucherTypeAlterId;

  // Metadata
  final bool isSelected;
  final String createdAt;
  final String updatedAt;

  Company({
    required this.guid,
    required this.masterId,
    required this.alterId,
    required this.name,
    this.reservedName,
    required this.startingFrom,
    required this.endingAt,
    this.booksFrom,
    this.booksBeginningFrom,
    this.gstApplicableDate,
    this.email,
    this.phoneNumber,
    this.faxNumber,
    this.website,
    this.address,
    this.city,
    this.pincode,
    this.state,
    this.country,
    this.incomeTaxNumber,
    this.pan,
    this.gsttin,
    this.currencyName,
    this.baseCurrencyName,
    // Accounting Features
    this.maintainAccounts = false,
    this.maintainBillWise = false,
    this.enableCostCentres = false,
    this.enableInterestCalc = false,
    // Inventory Features
    this.maintainInventory = false,
    this.integrateInventory = false,
    this.multiPriceLevel = false,
    this.enableBatches = false,
    this.maintainExpiryDate = false,
    this.enableJobOrderProcessing = false,
    this.enableCostTracking = false,
    this.enableJobCosting = false,
    this.useDiscountColumn = false,
    this.useSeparateActualBilledQty = false,
    // Tax Features
    this.isGstApplicable = false,
    this.setAlterCompanyGstRate = false,
    this.isTdsApplicable = false,
    this.isTcsApplicable = false,
    this.isVatApplicable = false,
    this.isExciseApplicable = false,
    this.isServiceTaxApplicable = false,
    // Online Access Features
    this.enableBrowserReports = false,
    this.enableTallyNet = false,
    // Payroll Features
    this.isPayrollEnabled = false,
    this.enablePayrollStatutory = false,
    // Other Features
    this.enablePaymentLinkQr = false,
    this.enableMultiAddress = false,
    this.markModifiedVouchers = false,
    // Status
    this.isDeleted = false,
    this.isAudited = false,
    this.isSecurityEnabled = false,
    this.isBookInUse = false,
    // Sync tracking
    this.lastSyncedGroupsAlterId = 0,
    this.lastSyncedLedgersAlterId = 0,
    this.lastSyncedStockItemsAlterId = 0,
    this.lastSyncedVouchersAlterId = 0,
    this.lastSyncedVoucherTypeAlterId = 0,
    this.isSelected = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'company_guid': guid,
      'master_id': masterId,
      'alter_id': alterId,
      'company_name': name,
      'reserved_name': reservedName,
      'starting_from': startingFrom,
      'ending_at': endingAt,
      'books_from': booksFrom,
      'books_beginning_from': booksBeginningFrom,
      'gst_applicable_date': gstApplicableDate,
      'email': email,
      'phone_number': phoneNumber,
      'fax_number': faxNumber,
      'website': website,
      'address': address,
      'city': city,
      'pincode': pincode,
      'state': state,
      'country': country,
      'income_tax_number': incomeTaxNumber,
      'pan': pan,
      'gsttin': gsttin,
      'currency_name': currencyName,
      'base_currency_name': baseCurrencyName,
      // Accounting Features
      'maintain_accounts': maintainAccounts ? 1 : 0,
      'maintain_bill_wise': maintainBillWise ? 1 : 0,
      'enable_cost_centres': enableCostCentres ? 1 : 0,
      'enable_interest_calc': enableInterestCalc ? 1 : 0,
      // Inventory Features
      'maintain_inventory': maintainInventory ? 1 : 0,
      'integrate_inventory': integrateInventory ? 1 : 0,
      'multi_price_level': multiPriceLevel ? 1 : 0,
      'enable_batches': enableBatches ? 1 : 0,
      'maintain_expiry_date': maintainExpiryDate ? 1 : 0,
      'enable_job_order_processing': enableJobOrderProcessing ? 1 : 0,
      'enable_cost_tracking': enableCostTracking ? 1 : 0,
      'enable_job_costing': enableJobCosting ? 1 : 0,
      'use_discount_column': useDiscountColumn ? 1 : 0,
      'use_separate_actual_billed_qty': useSeparateActualBilledQty ? 1 : 0,
      // Tax Features
      'is_gst_applicable': isGstApplicable ? 1 : 0,
      'set_alter_company_gst_rate': setAlterCompanyGstRate ? 1 : 0,
      'is_tds_applicable': isTdsApplicable ? 1 : 0,
      'is_tcs_applicable': isTcsApplicable ? 1 : 0,
      'is_vat_applicable': isVatApplicable ? 1 : 0,
      'is_excise_applicable': isExciseApplicable ? 1 : 0,
      'is_service_tax_applicable': isServiceTaxApplicable ? 1 : 0,
      // Online Access Features
      'enable_browser_reports': enableBrowserReports ? 1 : 0,
      'enable_tally_net': enableTallyNet ? 1 : 0,
      // Payroll Features
      'is_payroll_enabled': isPayrollEnabled ? 1 : 0,
      'enable_payroll_statutory': enablePayrollStatutory ? 1 : 0,
      // Other Features
      'enable_payment_link_qr': enablePaymentLinkQr ? 1 : 0,
      'enable_multi_address': enableMultiAddress ? 1 : 0,
      'mark_modified_vouchers': markModifiedVouchers ? 1 : 0,
      // Status
      'is_deleted': isDeleted ? 1 : 0,
      'is_audited': isAudited ? 1 : 0,
      'is_security_enabled': isSecurityEnabled ? 1 : 0,
      'is_book_in_use': isBookInUse ? 1 : 0,
      // Sync tracking
      'last_synced_groups_alter_id': lastSyncedGroupsAlterId,
      'last_synced_ledgers_alter_id': lastSyncedLedgersAlterId,
      'last_synced_stock_items_alter_id': lastSyncedStockItemsAlterId,
      'last_synced_vouchers_alter_id': lastSyncedVouchersAlterId,
      'last_synced_voucher_types_alter_id': lastSyncedVoucherTypeAlterId,
      'is_selected': isSelected ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // Create from Map (database)
  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      guid: map['company_guid'] ?? '',
      masterId: map['master_id'] ?? 0,
      alterId: map['alter_id'] ?? 0,
      name: map['company_name'] ?? '',
      reservedName: map['reserved_name'],
      startingFrom: map['starting_from'] ?? '',
      endingAt: map['ending_at'] ?? '',
      booksFrom: map['books_from'],
      booksBeginningFrom: map['books_beginning_from'],
      gstApplicableDate: map['gst_applicable_date'],
      email: map['email'],
      phoneNumber: map['phone_number'],
      faxNumber: map['fax_number'],
      website: map['website'],
      address: map['address'],
      city: map['city'],
      pincode: map['pincode'],
      state: map['state'],
      country: map['country'],
      incomeTaxNumber: map['income_tax_number'],
      pan: map['pan'],
      gsttin: map['gsttin'],
      currencyName: map['currency_name'],
      baseCurrencyName: map['base_currency_name'],
      // Accounting Features
      maintainAccounts: map['maintain_accounts'] == 1,
      maintainBillWise: map['maintain_bill_wise'] == 1,
      enableCostCentres: map['enable_cost_centres'] == 1,
      enableInterestCalc: map['enable_interest_calc'] == 1,
      // Inventory Features
      maintainInventory: map['maintain_inventory'] == 1,
      integrateInventory: map['integrate_inventory'] == 1,
      multiPriceLevel: map['multi_price_level'] == 1,
      enableBatches: map['enable_batches'] == 1,
      maintainExpiryDate: map['maintain_expiry_date'] == 1,
      enableJobOrderProcessing: map['enable_job_order_processing'] == 1,
      enableCostTracking: map['enable_cost_tracking'] == 1,
      enableJobCosting: map['enable_job_costing'] == 1,
      useDiscountColumn: map['use_discount_column'] == 1,
      useSeparateActualBilledQty: map['use_separate_actual_billed_qty'] == 1,
      // Tax Features
      isGstApplicable: map['is_gst_applicable'] == 1,
      setAlterCompanyGstRate: map['set_alter_company_gst_rate'] == 1,
      isTdsApplicable: map['is_tds_applicable'] == 1,
      isTcsApplicable: map['is_tcs_applicable'] == 1,
      isVatApplicable: map['is_vat_applicable'] == 1,
      isExciseApplicable: map['is_excise_applicable'] == 1,
      isServiceTaxApplicable: map['is_service_tax_applicable'] == 1,
      // Online Access Features
      enableBrowserReports: map['enable_browser_reports'] == 1,
      enableTallyNet: map['enable_tally_net'] == 1,
      // Payroll Features
      isPayrollEnabled: map['is_payroll_enabled'] == 1,
      enablePayrollStatutory: map['enable_payroll_statutory'] == 1,
      // Other Features
      enablePaymentLinkQr: map['enable_payment_link_qr'] == 1,
      enableMultiAddress: map['enable_multi_address'] == 1,
      markModifiedVouchers: map['mark_modified_vouchers'] == 1,
      // Status
      isDeleted: map['is_deleted'] == 1,
      isAudited: map['is_audited'] == 1,
      isSecurityEnabled: map['is_security_enabled'] == 1,
      isBookInUse: map['is_book_in_use'] == 1,
      // Sync tracking
      lastSyncedGroupsAlterId: map['last_synced_groups_alter_id'] ?? 0,
      lastSyncedLedgersAlterId: map['last_synced_ledgers_alter_id'] ?? 0,
      lastSyncedStockItemsAlterId: map['last_synced_stock_items_alter_id'] ?? 0,
      lastSyncedVouchersAlterId: map['last_synced_vouchers_alter_id'] ?? 0,
      lastSyncedVoucherTypeAlterId: map['last_synced_voucher_types_alter_id'] ?? 0,
      isSelected: map['is_selected'] == 1,
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

// models/stock_item_from_voucher.dart

class StockItemFromVoucher {
  final String name;
  final String? hsnCode;
  final String? hsnDescription;
  final String? gstTypeOfSupply;
  final String? gstTaxability;
  final String? gstSourceType;
  final String? gstItemSource;
  final String? hsnSourceType;
  final String? hsnItemSource;
  final double rate;
  final double amount;
  final double actualQty;
  final double billedQty;
  final List<GSTRateDetail> gstRates;
  final List<BatchInfo> batchInfo;

  StockItemFromVoucher({
    required this.name,
    this.hsnCode,
    this.hsnDescription,
    this.gstTypeOfSupply,
    this.gstTaxability,
    this.gstSourceType,
    this.gstItemSource,
    this.hsnSourceType,
    this.hsnItemSource,
    required this.rate,
    required this.amount,
    required this.actualQty,
    required this.billedQty,
    required this.gstRates,
    required this.batchInfo,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'hsn_code': hsnCode,
        'hsn_description': hsnDescription,
        'gst_type_of_supply': gstTypeOfSupply,
        'gst_taxability': gstTaxability,
        'gst_source_type': gstSourceType,
        'gst_item_source': gstItemSource,
        'hsn_source_type': hsnSourceType,
        'hsn_item_source': hsnItemSource,
        'rate': rate,
        'amount': amount,
        'actual_qty': actualQty,
        'billed_qty': billedQty,
        'gst_rates': gstRates.map((r) => r.toJson()).toList(),
        'batch_info': batchInfo.map((b) => b.toJson()).toList(),
      };
}

class GSTRateDetail {
  final String dutyHead; // CGST, SGST, IGST, Cess, State Cess
  final String? valuationType; // Based on Value, Not Applicable
  final double rate; // 2.50, 5, etc.
  final double ratePerUnit;

  GSTRateDetail({
    required this.dutyHead,
    this.valuationType,
    required this.rate,
    required this.ratePerUnit,
  });

  Map<String, dynamic> toJson() => {
        'duty_head': dutyHead,
        'valuation_type': valuationType,
        'rate': rate,
        'rate_per_unit': ratePerUnit,
      };
}

class BatchInfo {
  final String godownName;
  final String? batchName;
  final String? destinationGodownName;
  final int batchId;
  final double amount;
  final double actualQty;
  final double billedQty;
  final double batchRate;
  final double batchDiscount;

  BatchInfo({
    required this.godownName,
    this.batchName,
    this.destinationGodownName,
    required this.batchId,
    required this.amount,
    required this.actualQty,
    required this.billedQty,
    required this.batchRate,
    required this.batchDiscount,
  });

  Map<String, dynamic> toJson() => {
        'godown_name': godownName,
        'batch_name': batchName,
        'destination_godown_name': destinationGodownName,
        'batch_id': batchId,
        'amount': amount,
        'actual_qty': actualQty,
        'billed_qty': billedQty,
        'batch_rate': batchRate,
        'batch_discount': batchDiscount,
      };
}

// models/stock_item.dart

class StockItem {
  final String guid;
  final String name;
  final int alterid;
  final String? parent;
  final String? category;
  final String? description;
  final String? narration;

  // Units
  final String? baseUnits;
  final String? additionalUnits;
  final double denominator;
  final double conversion;

  // GST
  final String? gstApplicable;
  final String? gstTypeOfSupply;

  // Costing
  final String? costingMethod;
  final String? valuationMethod;

  // Opening balances
  final double openingBalance;
  final double openingValue;
  final double openingRate;

  // Flags
  final bool isCostCentresOn;
  final bool isBatchwiseOn;
  final bool isPerishableOn;
  final bool isDeleted;
  final bool ignoreNegativeStock;

  // Collections
  final List<String> mailingNames;
  final List<HSNDetail> hsnDetails;
  final List<GSTDetail> gstDetails;
  final List<MRPDetail> mrpDetails;
  final List<StockBatchAllocation> batchAllocations;

  StockItem({
    required this.guid,
    required this.name,
    this.alterid = 0,
    this.parent,
    this.category,
    this.description,
    this.narration,
    this.baseUnits,
    this.additionalUnits,
    this.denominator = 0,
    this.conversion = 0,
    this.gstApplicable,
    this.gstTypeOfSupply,
    this.costingMethod,
    this.valuationMethod,
    this.openingBalance = 0,
    this.openingValue = 0,
    this.openingRate = 0,
    this.isCostCentresOn = false,
    this.isBatchwiseOn = false,
    this.isPerishableOn = false,
    this.isDeleted = false,
    this.ignoreNegativeStock = false,
    this.mailingNames = const [],
    this.hsnDetails = const [],
    this.gstDetails = const [],
    this.mrpDetails = const [],
    this.batchAllocations = const [],
  });

  Map<String, dynamic> toJson() => {
        'guid': guid,
        'name': name,
        'alter_id': alterid,
        'parent': parent,
        'category': category,
        'description': description,
        'narration': narration,
        'base_units': baseUnits,
        'additional_units': additionalUnits,
        'denominator': denominator,
        'conversion': conversion,
        'gst_applicable': gstApplicable,
        'gst_type_of_supply': gstTypeOfSupply,
        'costing_method': costingMethod,
        'valuation_method': valuationMethod,
        'opening_balance': openingBalance,
        'opening_value': openingValue,
        'opening_rate': openingRate,
        'is_cost_centres_on': isCostCentresOn,
        'is_batchwise_on': isBatchwiseOn,
        'is_perishable_on': isPerishableOn,
        'is_deleted': isDeleted,
        'ignore_negative_stock': ignoreNegativeStock,
        'mailing_names': mailingNames,
        'hsn_details': hsnDetails.map((h) => h.toJson()).toList(),
        'gst_details': gstDetails.map((g) => g.toJson()).toList(),
        'mrp_details': mrpDetails.map((m) => m.toJson()).toList(),
        'batch_allocations': batchAllocations.map((b) => b.toJson()).toList(),
      };
}

class HSNDetail {
  final String? applicableFrom;
  final String? hsnCode;
  final String? hsnDescription;
  final String? sourceOfDetails;

  HSNDetail({
    this.applicableFrom,
    this.hsnCode,
    this.hsnDescription,
    this.sourceOfDetails,
  });

  Map<String, dynamic> toJson() => {
        'applicable_from': applicableFrom,
        'hsn_code': hsnCode,
        'hsn_description': hsnDescription,
        'source_of_details': sourceOfDetails,
      };
}

class GSTDetail {
  final String? applicableFrom;
  final String? taxability;
  final bool isReverseChargeApplicable;
  final bool isNonGstGoods;
  final bool gstIneligibleItc;
  final List<StatewiseGSTDetail> statewiseDetails;

  GSTDetail({
    this.applicableFrom,
    this.taxability,
    this.isReverseChargeApplicable = false,
    this.isNonGstGoods = false,
    this.gstIneligibleItc = false,
    this.statewiseDetails = const [],
  });

  Map<String, dynamic> toJson() => {
        'applicable_from': applicableFrom,
        'taxability': taxability,
        'is_reverse_charge_applicable': isReverseChargeApplicable,
        'is_non_gst_goods': isNonGstGoods,
        'gst_ineligible_itc': gstIneligibleItc,
        'statewise_details': statewiseDetails.map((s) => s.toJson()).toList(),
      };
}

class StatewiseGSTDetail {
  final String stateName;
  final List<GSTRateDetail> rateDetails;

  StatewiseGSTDetail({
    required this.stateName,
    this.rateDetails = const [],
  });

  Map<String, dynamic> toJson() => {
        'state_name': stateName,
        'rate_details': rateDetails.map((r) => r.toJson()).toList(),
      };
}

// class GSTRateDetail {
//   final String dutyHead; // CGST, SGST, IGST, Cess, State Cess
//   final String? valuationType;
//   final double rate;
//   final double ratePerUnit;

//   GSTRateDetail({
//     required this.dutyHead,
//     this.valuationType,
//     this.rate = 0,
//     this.ratePerUnit = 0,
//   });

//   Map<String, dynamic> toJson() => {
//     'duty_head': dutyHead,
//     'valuation_type': valuationType,
//     'rate': rate,
//     'rate_per_unit': ratePerUnit,
//   };
// }

class MRPDetail {
  final String? fromDate;
  final List<MRPRateDetail> mrpRates;

  MRPDetail({
    this.fromDate,
    this.mrpRates = const [],
  });

  Map<String, dynamic> toJson() => {
        'from_date': fromDate,
        'mrp_rates': mrpRates.map((m) => m.toJson()).toList(),
      };
}

class MRPRateDetail {
  final String stateName;
  final double mrpRate;

  MRPRateDetail({
    required this.stateName,
    this.mrpRate = 0,
  });

  Map<String, dynamic> toJson() => {
        'state_name': stateName,
        'mrp_rate': mrpRate,
      };
}

class StockBatchAllocation {
  final String godownName;
  final String? batchName;
  final String? mfdOn;
  final double openingBalance;
  final double openingValue;
  final double openingRate;

  StockBatchAllocation({
    required this.godownName,
    this.batchName,
    this.mfdOn,
    this.openingBalance = 0,
    this.openingValue = 0,
    this.openingRate = 0,
  });

  Map<String, dynamic> toJson() => {
        'godown_name': godownName,
        'batch_name': batchName,
        'mfd_on': mfdOn,
        'opening_balance': openingBalance,
        'opening_value': openingValue,
        'opening_rate': openingRate,
      };
}

class Group {
  final String groupGuid;
  final String companyGuid;
  final String name;
  final String? reservedName;
  final int alterId;
  String? parent; // Only store GUID, not name
  String? parentGuid; // Only store GUID, not name
  final String? narration;
  final int isBillwiseOn;
  final int isAddable;
  final int isDeleted;
  final int isSubledger;
  final int isRevenue;
  final int affectsGrossProfit;
  final int isDeemedPositive;
  final int trackNegativeBalances;
  final int isCondensed;
  final String? addlAllocType;
  final String? gstApplicable;
  final String? tdsApplicable;
  final String? tcsApplicable;
  final int sortPosition;
  final List<String>? languageNames;
  final String? createdAt;
  final String? updatedAt;

  Group({
    required this.groupGuid,
    required this.companyGuid,
    required this.name,
    this.reservedName,
    this.alterId = 0,
    this.parent,
    this.parentGuid,
    this.narration,
    this.isBillwiseOn = 0,
    this.isAddable = 0,
    this.isDeleted = 0,
    this.isSubledger = 0,
    this.isRevenue = 0,
    this.affectsGrossProfit = 0,
    this.isDeemedPositive = 0,
    this.trackNegativeBalances = 0,
    this.isCondensed = 0,
    this.addlAllocType,
    this.gstApplicable,
    this.tdsApplicable,
    this.tcsApplicable,
    this.sortPosition = 0,
    this.languageNames,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'group_guid': groupGuid,
      'company_guid': companyGuid,
      'name': name,
      'reserved_name': reservedName,
      'alter_id': alterId,
      'parent_guid': parentGuid,
      'narration': narration,
      'is_billwise_on': isBillwiseOn,
      'is_addable': isAddable,
      'is_deleted': isDeleted,
      'is_subledger': isSubledger,
      'is_revenue': isRevenue,
      'affects_gross_profit': affectsGrossProfit,
      'is_deemed_positive': isDeemedPositive,
      'track_negative_balances': trackNegativeBalances,
      'is_condensed': isCondensed,
      'addl_alloc_type': addlAllocType,
      'gst_applicable': gstApplicable,
      'tds_applicable': tdsApplicable,
      'tcs_applicable': tcsApplicable,
      'sort_position': sortPosition,
      'language_names': languageNames != null
          ? jsonEncode(languageNames) // Convert List to JSON string
          : null,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      groupGuid: map['group_guid'],
      companyGuid: map['company_guid'],
      name: map['name'],
      reservedName: map['reserved_name'],
      alterId: map['alter_id'] ?? 0,
      parentGuid: map['parent_guid'],
      narration: map['narration'],
      isBillwiseOn: map['is_billwise_on'],
      isAddable: map['is_addable'],
      isDeleted: map['is_deleted'],
      isSubledger: map['is_subledger'],
      isRevenue: map['is_revenue'],
      affectsGrossProfit: map['affects_gross_profit'],
      isDeemedPositive: map['is_deemed_positive'],
      trackNegativeBalances: map['track_negative_balances'],
      isCondensed: map['is_condensed'],
      addlAllocType: map['addl_alloc_type'],
      gstApplicable: map['gst_applicable'],
      tdsApplicable: map['tds_applicable'],
      tcsApplicable: map['tcs_applicable'],
      sortPosition: map['sort_position'] ?? 0,
      languageNames: map['language_names'] != null
          ? List<String>.from(jsonDecode(map['language_names']))
          : null,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
// models/ledger.dart

class Ledger {
  final String guid;
  final String name;
  final int alterid;
  final String? parent;
  final String? parentGuid;
  final String? narration;

  // Basic details
  final String? currencyName;
  final String? email;
  final String? website;
  final String? description; // ✅ Added
  final String? incomeTaxNumber;
  final String? partyGstin;

  // State/Country info
  final String? priorStateName; // ✅ Added
  final String? countryOfResidence; // ✅ Added

  // Balances
  final double openingBalance;
  final List<ClosingBalance> closingBalances; // ✅ Added
  final double creditLimit; // ✅ Added

  // Boolean flags
  final bool isBillwiseOn;
  final bool isCostCentresOn;
  final bool isInterestOn;
  final bool isDeleted;
  final bool isCostTrackingOn;
  final bool isCreditDaysChkOn; // ✅ Added
  final bool affectsStock;
  final bool isGstApplicable;
  final bool isTdsApplicable;
  final bool isTcsApplicable;

  // Tax details
  final String? taxClassificationName;
  final String? taxType;
  final String? gstType;
  final String? gstNatureOfSupply; // ✅ Added

  // Credit period
  final String? billCreditPeriod; // ✅ Added

  // Banking details
  final String? ifscCode;
  final String? swiftCode;
  final String? bankAccountHolderName;

  // Contact details
  final String? ledgerPhone;
  final String? ledgerMobile;
  final String? ledgerContact;
  final String? ledgerCountryIsdCode; // ✅ Added

  // Sort position
  final int sortPosition;

  // Mailing details (latest)
  final String? mailingName;
  final String? mailingState;
  final String? mailingPincode;
  final String? mailingCountry;
  final List<String> mailingAddress; // ✅ Added - multiple address lines

  // GST Registration details (latest)
  final String? gstRegistrationType; // ✅ Added
  final String? gstApplicableFrom; // ✅ Added
  final String? gstPlaceOfSupply; // ✅ Added
  final String? gstin; // ✅ Added

  // Collections
  final List<String> languageNames;
  final List<ContactDetail> contacts; // ✅ Added
  final List<MailingDetail> mailingDetails; // ✅ Added
  final List<GSTRegistrationDetail> gstRegistrations; // ✅ Added

  Ledger({
    required this.guid,
    required this.name,
    this.alterid = 0,
    this.parent,
    this.parentGuid,
    this.narration,
    this.currencyName,
    this.email,
    this.website,
    this.description,
    this.incomeTaxNumber,
    this.partyGstin,
    this.priorStateName,
    this.countryOfResidence,
    this.openingBalance = 0,
    this.closingBalances = const [],
    this.creditLimit = 0,
    this.isBillwiseOn = false,
    this.isCostCentresOn = false,
    this.isInterestOn = false,
    this.isDeleted = false,
    this.isCostTrackingOn = false,
    this.isCreditDaysChkOn = false,
    this.affectsStock = false,
    this.isGstApplicable = false,
    this.isTdsApplicable = false,
    this.isTcsApplicable = false,
    this.taxClassificationName,
    this.taxType,
    this.gstType,
    this.gstNatureOfSupply,
    this.billCreditPeriod,
    this.ifscCode,
    this.swiftCode,
    this.bankAccountHolderName,
    this.ledgerPhone,
    this.ledgerMobile,
    this.ledgerContact,
    this.ledgerCountryIsdCode,
    this.sortPosition = 0,
    this.mailingName,
    this.mailingState,
    this.mailingPincode,
    this.mailingCountry,
    this.mailingAddress = const [],
    this.gstRegistrationType,
    this.gstApplicableFrom,
    this.gstPlaceOfSupply,
    this.gstin,
    this.languageNames = const [],
    this.contacts = const [],
    this.mailingDetails = const [],
    this.gstRegistrations = const [],
  });

  Map<String, dynamic> toJson() => {
        'guid': guid,
        'name': name,
        'alter_id': alterid,
        'parent': parent,
        'parent_guid': parentGuid,
        'narration': narration,
        'currency_name': currencyName,
        'email': email,
        'website': website,
        'description': description,
        'income_tax_number': incomeTaxNumber,
        'party_gstin': partyGstin,
        'prior_state_name': priorStateName,
        'country_of_residence': countryOfResidence,
        'opening_balance': openingBalance,
        'closing_balances': closingBalances.map((c) => c.toJson()).toList(),
        'credit_limit': creditLimit,
        'is_billwise_on': isBillwiseOn,
        'is_cost_centres_on': isCostCentresOn,
        'is_interest_on': isInterestOn,
        'is_deleted': isDeleted,
        'is_cost_tracking_on': isCostTrackingOn,
        'is_credit_days_chk_on': isCreditDaysChkOn,
        'affects_stock': affectsStock,
        'is_gst_applicable': isGstApplicable,
        'is_tds_applicable': isTdsApplicable,
        'is_tcs_applicable': isTcsApplicable,
        'tax_classification_name': taxClassificationName,
        'tax_type': taxType,
        'gst_type': gstType,
        'gst_nature_of_supply': gstNatureOfSupply,
        'bill_credit_period': billCreditPeriod,
        'ifsc_code': ifscCode,
        'swift_code': swiftCode,
        'bank_account_holder_name': bankAccountHolderName,
        'ledger_phone': ledgerPhone,
        'ledger_mobile': ledgerMobile,
        'ledger_contact': ledgerContact,
        'ledger_country_isd_code': ledgerCountryIsdCode,
        'sort_position': sortPosition,
        'mailing_name': mailingName,
        'mailing_state': mailingState,
        'mailing_pincode': mailingPincode,
        'mailing_country': mailingCountry,
        'mailing_address': mailingAddress,
        'gst_registration_type': gstRegistrationType,
        'gst_applicable_from': gstApplicableFrom,
        'gst_place_of_supply': gstPlaceOfSupply,
        'gstin': gstin,
        'language_names': languageNames,
        'contacts': contacts.map((c) => c.toJson()).toList(),
        'mailing_details': mailingDetails.map((m) => m.toJson()).toList(),
        'gst_registrations': gstRegistrations.map((g) => g.toJson()).toList(),
      };
}

// ✅ Contact Detail Model
class ContactDetail {
  final String name;
  final String phoneNumber;
  final String? countryIsdCode;
  final bool isDefaultWhatsappNum;

  ContactDetail({
    required this.name,
    required this.phoneNumber,
    this.countryIsdCode,
    this.isDefaultWhatsappNum = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone_number': phoneNumber,
        'country_isd_code': countryIsdCode,
        'is_default_whatsapp_num': isDefaultWhatsappNum,
      };
}

class ClosingBalance {
  final String date;
  final double amount;

  ClosingBalance({
    required this.date,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'amount': amount,
      };
}

// ✅ Mailing Detail Model
class MailingDetail {
  final String applicableFrom;
  final String? mailingName;
  final String? state;
  final String? country;
  final String? pincode;
  final List<String> address;

  MailingDetail({
    required this.applicableFrom,
    this.mailingName,
    this.state,
    this.country,
    this.pincode,
    this.address = const [],
  });

  Map<String, dynamic> toJson() => {
        'applicable_from': applicableFrom,
        'mailing_name': mailingName,
        'state': state,
        'country': country,
        'pincode': pincode,
        'address': address,
      };
}

// ✅ GST Registration Detail Model
class GSTRegistrationDetail {
  final String applicableFrom;
  final String? gstRegistrationType;
  final String? placeOfSupply;
  final String? gstin;
  final String? transporterId;
  final bool isOthTerritoryAssessee;
  final bool considerPurchaseForExport;
  final bool isTransporter;

  GSTRegistrationDetail({
    required this.applicableFrom,
    this.gstRegistrationType,
    this.placeOfSupply,
    this.gstin,
    this.transporterId,
    this.isOthTerritoryAssessee = false,
    this.considerPurchaseForExport = false,
    this.isTransporter = false,
  });

  Map<String, dynamic> toJson() => {
        'applicable_from': applicableFrom,
        'gst_registration_type': gstRegistrationType,
        'place_of_supply': placeOfSupply,
        'gstin': gstin,
        'transporter_id': transporterId,
        'is_oth_territory_assessee': isOthTerritoryAssessee,
        'consider_purchase_for_export': considerPurchaseForExport,
        'is_transporter': isTransporter,
      };
}

class VoucherType {
  final String name;
  final String companyGuid;
  final String? reservedName;
  final String guid;
  final String parent;
  final String? parentGuid;
  final int alterId;
  final int masterId;
  
  // Behavior flags
  final bool isDeemedPositive;
  final bool affectsStock;
  final bool isOptional;
  final bool isActive;
  final bool isDeleted;
  
  // Numbering
  final String numberingMethod; // "Automatic", "Manual", "Auto Retain"
  final bool preventDuplicates;
  
  // Current prefix/suffix (no history)
  final String? currentPrefix;
  final String? currentSuffix;
  
  // Restart rule
  final String? restartPeriod; // "Yearly", "Monthly", "Daily", "Never"
  
  // Tax & Invoice
  final bool isTaxInvoice;
  final bool printAfterSave;

  VoucherType({
    required this.name,
    required this.companyGuid,
    this.reservedName,
    required this.guid,
    required this.parent,
    this.parentGuid,
    required this.alterId,
    required this.masterId,
    required this.isDeemedPositive,
    required this.affectsStock,
    required this.isOptional,
    required this.isActive,
    required this.isDeleted,
    required this.numberingMethod,
    required this.preventDuplicates,
    this.currentPrefix,
    this.currentSuffix,
    this.restartPeriod,
    required this.isTaxInvoice,
    required this.printAfterSave,
  });

  // Helper to get current voucher number format
  String getCurrentFormat({int number = 1}) {
    final prefix = currentPrefix ?? '';
    final suffix = currentSuffix ?? '';
    return '$prefix$number$suffix';
  }

  // Convert from database map
  factory VoucherType.fromMap(Map<String, dynamic> map) {
  return VoucherType(
    name: map['name'] as String,
    companyGuid: map['company_guid'] as String,
    reservedName: map['reserved_name'] as String? ?? '',
    guid: map['guid'] as String,
    parent: map['parent'] as String? ?? '',
    parentGuid: map['parent_guid'] as String? ?? '',
    alterId: map['alter_id'] as int,
    masterId: map['master_id'] as int,
    isDeemedPositive: (map['is_deemed_positive'] as int) == 1,
    affectsStock: (map['affects_stock'] as int) == 1,
    isOptional: (map['is_optional'] as int) == 1,
    isActive: (map['is_active'] as int) == 1,
    isDeleted: (map['is_deleted'] as int) == 1,
    numberingMethod: map['numbering_method'] as String? ?? 'None',
    preventDuplicates: (map['prevent_duplicates'] as int) == 1,
    currentPrefix: map['current_prefix'] as String?,
    currentSuffix: map['current_suffix'] as String?,
    restartPeriod: map['restart_period'] as String?,
    isTaxInvoice: (map['is_tax_invoice'] as int) == 1,
    printAfterSave: (map['print_after_save'] as int) == 1,
  );
}

  // Convert to database map
  Map<String, dynamic> toMap(String companyGuid) {
    return {
      'company_guid': companyGuid,
      'name': name,
      'reserved_name': reservedName,
      'guid': guid,
      'parent_guid': parentGuid,
      'alter_id': alterId,
      'master_id': masterId,
      'is_deemed_positive': isDeemedPositive ? 1 : 0,
      'affects_stock': affectsStock ? 1 : 0,
      'is_optional': isOptional ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'numbering_method': numberingMethod,
      'prevent_duplicates': preventDuplicates ? 1 : 0,
      'current_prefix': currentPrefix,
      'current_suffix': currentSuffix,
      'restart_period': restartPeriod,
      'is_tax_invoice': isTaxInvoice ? 1 : 0,
      'print_after_save': printAfterSave ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'VoucherType(name: $name, affects_stock: $affectsStock, format: ${getCurrentFormat(number: 1)})';
  }
}

// models/voucher.dart

class Voucher {
  // Primary identifiers
  final String guid;
  final int masterId;
  final int alterId;
  final int? voucherKey;
  final int? voucherRetainKey;

  // Voucher details
  final String date;
  final String? effectiveDate;
  final String voucherType;
  final String voucherNumber;
  final String? voucherNumberSeries;
  final String? persistedView;

  // Party details
  final String? partyLedgerName;
  final String? partyGstin;

  // Amounts
  final double? amount;
  final double? totalAmount;
  final double? discount;

  // GST details
  final String? gstRegistrationType;
  final String? placeOfSupply;
  final String? stateName;
  final String? countryOfResidence;

  // Text fields
  final String? narration;
  final String? reference;

  // Boolean flags
  final bool isDeleted;
  final bool isCancelled;
  final bool isInvoice;
  final bool? isOptional;
  final bool? hasDiscounts;
  final bool? isDeemedPositive;

  // Collections
  final List<LedgerEntry> ledgerEntries;
  final List<InventoryEntry> inventoryEntries;

  Voucher({
    required this.guid,
    required this.masterId,
    required this.alterId,
    this.voucherKey,
    this.voucherRetainKey,
    required this.date,
    this.effectiveDate,
    required this.voucherType,
    required this.voucherNumber,
    this.voucherNumberSeries,
    this.persistedView,
    this.partyLedgerName,
    this.partyGstin,
    this.amount,
    this.totalAmount,
    this.discount,
    this.gstRegistrationType,
    this.placeOfSupply,
    this.stateName,
    this.countryOfResidence,
    this.narration,
    this.reference,
    this.isDeleted = false,
    this.isCancelled = false,
    this.isInvoice = false,
    this.isOptional,
    this.hasDiscounts,
    this.isDeemedPositive,
    this.ledgerEntries = const [],
    this.inventoryEntries = const [],
  });
}

class LedgerEntry {
  final String ledgerName;
  final double amount;
  final bool isPartyLedger;
  final bool? isDeemedPositive;

  // Bill allocations
  final String? billName;
  final double? billAmount;
  final String? billDate;
  final String? billType;

  // Bank allocations
  final String? instrumentNumber;
  final String? instrumentDate;
  final String? transactionType;

  // Cost center
  final String? costCenterName;
  final double? costCenterAmount;

  LedgerEntry({
    required this.ledgerName,
    required this.amount,
    this.isPartyLedger = false,
    this.isDeemedPositive,
    this.billName,
    this.billAmount,
    this.billDate,
    this.billType,
    this.instrumentNumber,
    this.instrumentDate,
    this.transactionType,
    this.costCenterName,
    this.costCenterAmount,
  });
}

class InventoryEntry {
  final String stockItemName;
  final String rate;
  final double amount;
  final String actualQty;
  final String billedQty;

  // Discount
  final double? discount;
  final double? discountPercent;

  // GST details
  final String? gstRate;
  final double? cgstAmount;
  final double? sgstAmount;
  final double? igstAmount;
  final double? cessAmount;
  final String? hsnCode;
  final String? hsnDescription;

  // Unit
  final String? unit;
  final String? alternateUnit;

  // Tracking
  final String? trackingNumber;
  final String? orderNumber;
  final String? indentNumber;

  final bool? isDeemedPositive;

  final List<BatchAllocation> batchAllocations;

  InventoryEntry({
    required this.stockItemName,
    required this.rate,
    required this.amount,
    required this.actualQty,
    required this.billedQty,
    this.discount,
    this.discountPercent,
    this.gstRate,
    this.cgstAmount,
    this.sgstAmount,
    this.igstAmount,
    this.cessAmount,
    this.hsnCode,
    this.hsnDescription,
    this.unit,
    this.alternateUnit,
    this.trackingNumber,
    this.orderNumber,
    this.indentNumber,
    this.isDeemedPositive,
    this.batchAllocations = const [],
  });
}

class BatchAllocation {
  final String godownName;
  final String batchName;
  final double amount;
  final String actualQty;
  final String billedQty;
  final String trackingNumber;

  // Batch details
  final String? batchId;
  final String? mfgDate;
  final String? expiryDate;
  final double? batchRate;
  final String? destinationGodownName;

  final bool? isDeemedPositive;

  BatchAllocation(
      {required this.godownName,
      required this.batchName,
      required this.amount,
      required this.actualQty,
      required this.billedQty,
      required this.trackingNumber,
      this.batchId,
      this.mfgDate,
      this.expiryDate,
      this.batchRate,
      this.destinationGodownName,
      this.isDeemedPositive});
}

// Structure 1: Stock Item Info
class StockItemInfo {
  final String itemName;
  final String stockItemGuid;
  final String costingMethod;
  final String unit;
  final String parentName;
  final double closingRate;
  final double closingQty;
  final double closingValue;
  final List<BatchAllocation> openingData;

  StockItemInfo({
    required this.itemName,
    required this.stockItemGuid,
    required this.costingMethod,
    required this.unit,
    required this.parentName,
    required this.closingRate,
    required this.closingQty,
    required this.closingValue,
    required this.openingData,
  });
}

// Structure 2: Transaction/Voucher
class StockTransaction {
  final String voucherGuid;
  final int voucherId;
  final String voucherDate;
  final String voucherNumber;
  final String godownName;
  final String voucherType;
  final double stock;
  final double rate;
  final double amount;
  final bool isInward;
  final String batchName;
  final String destinationGodown;
  final String trackingNumber;

  StockTransaction({
    required this.voucherGuid,
    required this.voucherId,
    required this.voucherDate,
    required this.voucherNumber,
    required this.godownName,
    required this.voucherType,
    required this.stock,
    required this.rate,
    required this.amount,
    required this.isInward,
    required this.batchName,
    required this.destinationGodown,
    required this.trackingNumber
  });
}

class AverageCostResult {
  final String stockItemGuid;
  final String itemName;
  final Map<String, GodownAverageCost> godowns;

  AverageCostResult({
    required this.stockItemGuid,
    required this.itemName,
    required this.godowns,
  });
}

class GodownAverageCost {
  final String godownName;
  final double totalInwardQty;
  final double totalInwardValue;
  final double currentStockQty;
  final double averageRate;
  final double closingValue;

  GodownAverageCost({
    required this.godownName,
    required this.totalInwardQty,
    required this.totalInwardValue,
    required this.currentStockQty,
    required this.averageRate,
    required this.closingValue,
  });
}

enum StockInOutType{
  inward,
  outward
}

class StockLot {
  final String voucherGuid;
  final String voucherDate;
  final String voucherNumber;
  final String voucherType;
  double qty; // Mutable - reduced when consumed
  double amount; // Mutable - reduced when consumed
  final double rate;
  final StockInOutType type;

  StockLot({
    required this.voucherGuid,
    required this.voucherDate,
    required this.voucherNumber,
    required this.voucherType,
    required this.qty,
    required this.amount,
    required this.rate,
    required this.type
  });
}

/// Result for a single godown using FIFO method
class GodownFifoCost {
  final String godownName;
  final double totalInwardQty;
  final double totalOutwardQty;
  final double closingStockQty;
  final double closingValue;
  final List<StockLot> usedLots; // Lots used for closing value (for audit)

  GodownFifoCost({
    required this.godownName,
    required this.totalInwardQty,
    required this.totalOutwardQty,
    required this.closingStockQty,
    required this.closingValue,
    required this.usedLots,
  });
}

/// Overall FIFO result for a stock item
class FifoCostResult {
  final String stockItemGuid;
  final String itemName;
  final Map<String, GodownFifoCost> godowns;

  FifoCostResult({
    required this.stockItemGuid,
    required this.itemName,
    required this.godowns,
  });
}

class StockItemClosingData{

  final String guid;
  final double closingRate;
  final double closingQty;
  final double closingValue;
  final String date;

  StockItemClosingData({
    required this.guid,
    required this.closingRate,
    required this.closingQty,
    required this.closingValue,
    required this.date
  });
}

class BatchAccumulator {
  double inwardQty = 0.0;
  double inwardValue = 0.0;
  double outwardQty = 0.0;
}

// ── Internal helper model ──────────────────────────────────────
class MonthEntry {
  final String fy;
  final String label;
  final String fromDate;
  final String toDate;
  const MonthEntry({
    required this.fy,
    required this.label,
    required this.fromDate,
    required this.toDate,
  });
}

// ── Public models ──────────────────────────────────────────────
class MonthlyStockClosing {
  final String fy;
  final String month;
  final String fromDate;
  final String toDate;
  final double totalValue;
  final List<StockItemClosing> items;

  const MonthlyStockClosing({
    required this.fy,
    required this.month,
    required this.fromDate,
    required this.toDate,
    required this.totalValue,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'fy':         fy,
    'month':      month,
    'fromDate':   fromDate,
    'toDate':     toDate,
    'totalValue': totalValue,
    'items':      items.map((i) => i.toJson()).toList(),
  };
}

class StockItemClosing {
  final String name;
  final String guid;
  final double closingBalance;
  final double closingValue;
  final double closingRate;
  final String month;
  final String toDate;

  const StockItemClosing({
    required this.name,
    required this.guid,
    required this.closingBalance,
    required this.closingValue,
    required this.closingRate,
    required this.month,
    required this.toDate,
  });

  Map<String, dynamic> toJson() => {
    'name':           name,
    'guid':           guid,
    'closingBalance': closingBalance,
    'closingValue':   closingValue,
    'closingRate':    closingRate,
    'month':          month,
    'toDate':         toDate,
  };
}