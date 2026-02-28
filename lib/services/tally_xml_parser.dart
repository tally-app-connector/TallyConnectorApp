// services/tally_xml_parser.dart - FINAL VERSION

import 'dart:convert';

import 'package:xml/xml.dart';
import '../models/data_model.dart';

class TallyXmlParser {
  static List<Company> parseCompanies(String xmlData) {
    final companies = <Company>[];
    
    try {
      final document = XmlDocument.parse(xmlData);
      final envelopes = document.findAllElements('ENVELOPE');
      
      print('Found ${envelopes.length} company elements');
      
      for (var envelope in envelopes) {
        try {
          final company = _parseCompany(envelope);
          if (company.guid.isNotEmpty) {
            companies.add(company);
            print('✅ Parsed company: ${company.name}');
          }
        } catch (e, stack) {
          print('❌ Error parsing company: $e');
          print(stack);
        }
      }
      
      print('📋 Total parsed: ${companies.length} companies');
    } catch (e, stack) {
      print('❌ Error parsing companies XML: $e');
      print(stack);
    }
    
    return companies;
  }
 
 static Company _parseCompany(XmlElement envelope) {
  // Helper function to get element text
  String getElementText(String tagName) {
    final element = envelope.findElements(tagName).firstOrNull;
    return element?.innerText.trim() ?? '';
  }
  
  // Helper to convert Yes/No to bool
  bool yesToBool(String value) {
    return value.toLowerCase() == 'yes';
  }
  
  // Parse Tally date format: "1-Apr-23" -> "2023-04-01"
  String parseDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final monthMap = {
          'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
          'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
          'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12'
        };
        final month = monthMap[parts[1]] ?? '01';
        final year = '20${parts[2]}';
        return '$year-$month-$day';
      }
    } catch (e) {
      print('⚠️ Error parsing date: $dateStr - $e');
    }
    return dateStr;
  }
  
  final now = DateTime.now().toIso8601String();
  
  return Company(
    // Primary identifiers
    guid: getElementText('COMPGUID'),
    masterId: int.tryParse(getElementText('COMPMASTERID')) ?? 0,
    alterId: int.tryParse(getElementText('COMPALTERID')) ?? 0,
    name: getElementText('COMPNAME'),
    reservedName: getElementText('COMPRESERVEDNAME').isEmpty 
        ? null 
        : getElementText('COMPRESERVEDNAME'),
    
    // Dates
    startingFrom: parseDate(getElementText('COMPSTARTDATE')),
    endingAt: parseDate(getElementText('COMPENDDATE')),
    booksFrom: parseDate(getElementText('COMPBOOKSFROM')).isEmpty 
        ? null 
        : parseDate(getElementText('COMPBOOKSFROM')),
    booksBeginningFrom: parseDate(getElementText('COMPBOOKSBEGINDATE')).isEmpty 
        ? null 
        : parseDate(getElementText('COMPBOOKSBEGINDATE')),
    gstApplicableDate: parseDate(getElementText('COMPGSTDATE')).isEmpty 
        ? null 
        : parseDate(getElementText('COMPGSTDATE')),
    
    // Contact Details
    email: getElementText('COMPEMAIL').isEmpty ? null : getElementText('COMPEMAIL'),
    phoneNumber: getElementText('COMPPHONE').isEmpty ? null : getElementText('COMPPHONE'),
    faxNumber: getElementText('COMPFAX').isEmpty ? null : getElementText('COMPFAX'),
    website: getElementText('COMPWEBSITE').isEmpty ? null : getElementText('COMPWEBSITE'),
    
    // Address
    address: getElementText('COMPADDRESS').isEmpty ? null : getElementText('COMPADDRESS'),
    city: getElementText('COMPCITY').isEmpty ? null : getElementText('COMPCITY'),
    pincode: getElementText('COMPPINCODE').isEmpty ? null : getElementText('COMPPINCODE'),
    state: getElementText('COMPSTATE').isEmpty ? null : getElementText('COMPSTATE'),
    country: getElementText('COMPCOUNTRY').isEmpty ? null : getElementText('COMPCOUNTRY'),
    
    // Tax Details
    incomeTaxNumber: getElementText('COMPITNO').isEmpty ? null : getElementText('COMPITNO'),
    pan: getElementText('COMPPAN').isEmpty ? null : getElementText('COMPPAN'),
    gsttin: getElementText('COMPGSTIN').isEmpty ? null : getElementText('COMPGSTIN'),
    
    // Currency
    currencyName: getElementText('COMPCURRENCY').isEmpty ? null : getElementText('COMPCURRENCY'),
    baseCurrencyName: getElementText('COMPBASECURRENCY').isEmpty ? null : getElementText('COMPBASECURRENCY'),
    
    // Accounting Features
    maintainAccounts: yesToBool(getElementText('COMPMAINTAINACCOUNTS')),
    maintainBillWise: yesToBool(getElementText('COMPMAINTAINBILLWISE')),
    enableCostCentres: yesToBool(getElementText('COMPENABLECOSTCENTRES')),
    enableInterestCalc: yesToBool(getElementText('COMPENABLEINTERESTCALC')),
    
    // Inventory Features
    maintainInventory: yesToBool(getElementText('COMPINVENTORY')),
    integrateInventory: yesToBool(getElementText('COMPINTEGRATEINVENTORY')),
    multiPriceLevel: yesToBool(getElementText('COMPMULTIPRICELEVEL')),
    enableBatches: yesToBool(getElementText('COMPENABLEBATCHES')),
    maintainExpiryDate: yesToBool(getElementText('COMPMAINTAINEXPIRYDATE')),
    enableJobOrderProcessing: yesToBool(getElementText('COMPENABLEJOBORDERPROCESSING')),
    enableCostTracking: yesToBool(getElementText('COMPENABLECOSTTRACKING')),
    enableJobCosting: yesToBool(getElementText('COMPENABLEJOBCOSTING')),
    useDiscountColumn: yesToBool(getElementText('COMPUSEDISCOUNTCOLUMN')),
    useSeparateActualBilledQty: yesToBool(getElementText('COMPUSESEPARATEACTUALBILLEDQTY')),
    
    // Tax Features
    isGstApplicable: yesToBool(getElementText('COMPGSTAPPLICABLE')),
    setAlterCompanyGstRate: yesToBool(getElementText('COMPSETALTERCOMPANYGSTRATE')),
    isTdsApplicable: yesToBool(getElementText('COMPTDSAPPLICABLE')),
    isTcsApplicable: yesToBool(getElementText('COMPTCSAPPLICABLE')),
    isVatApplicable: yesToBool(getElementText('COMPVATAPPLICABLE')),
    isExciseApplicable: yesToBool(getElementText('COMPEXCISEAPPLICABLE')),
    isServiceTaxApplicable: yesToBool(getElementText('COMPSERVICETAXAPPLICABLE')),
    
    // Online Access Features
    enableBrowserReports: yesToBool(getElementText('COMPENABLEBROWSERREPORTS')),
    enableTallyNet: yesToBool(getElementText('COMPENABLETALLYNET')),
    
    // Payroll Features
    isPayrollEnabled: yesToBool(getElementText('COMPPAYROLLENABLED')),
    enablePayrollStatutory: yesToBool(getElementText('COMPENABLEPAYROLLSTATUTORY')),
    
    // Other Features
    enablePaymentLinkQr: yesToBool(getElementText('COMPENABLEPAYMENTLINKQR')),
    enableMultiAddress: yesToBool(getElementText('COMPENABLEMULTIADDRESS')),
    markModifiedVouchers: yesToBool(getElementText('COMPMARKMODIFIEDVOUCHERS')),
    
    // Status
    isDeleted: yesToBool(getElementText('COMPDELETED')),
    isAudited: yesToBool(getElementText('COMPAUDITED')),
    isSecurityEnabled: yesToBool(getElementText('COMPSECURITYENABLED')),
    isBookInUse: yesToBool(getElementText('COMPBOOKINUSE')),
    
    // Timestamps
    createdAt: now,
    updatedAt: now,
  );
}

  /// Parse Stock Items from Tally XML
  static List<StockItem> parseStockItems(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      final stockItems = <StockItem>[];

      final stockElements = document.findAllElements('STOCKITEM');

      print('Found ${stockElements.length} stock item elements');

      for (final element in stockElements) {
        try {
          final stockItem = _parseStockItem(element);

          // prettyPrint(stockItem);
          if (stockItem.guid.isNotEmpty) {
            stockItems.add(stockItem);
            print('✅ Parsed: ${stockItem.name} (${stockItem.guid})');
          }
        } catch (e, stack) {
          print('❌ Error parsing stock item: $e');
          print(stack);
        }
      }

      return stockItems;
    } catch (e, stack) {
      print('❌ Error parsing XML: $e');
      print(stack);
      return [];
    }
  }

  static StockItem _parseStockItem(XmlElement element) {
    return StockItem(
      // Basic fields
      guid: _getElementText(element, 'GUID'),
      name: element.getAttribute('NAME') ?? _getElementText(element, 'NAME'),
      alterid: _parseInt(_getElementText(element, 'ALTERID')),
      parent: _getElementTextOrNull(element, 'PARENT'),
      category: _cleanValue(_getElementText(element, 'CATEGORY')),

      // Description fields
      description: _getElementTextOrNull(element, 'DESCRIPTION'),
      narration: _getElementTextOrNull(element, 'NARRATION'),

      // Units
      baseUnits: _getElementTextOrNull(element, 'BASEUNITS'),
      additionalUnits: _getElementTextOrNull(element, 'ADDITIONALUNITS'),
      denominator:
          _parseFormattedNumber(_getElementText(element, 'DENOMINATOR')),
      conversion: _parseFormattedNumber(_getElementText(element, 'CONVERSION')),

      // GST fields
      gstApplicable: _cleanValue(_getElementText(element, 'GSTAPPLICABLE')),
      gstTypeOfSupply: _getElementTextOrNull(element, 'GSTTYPEOFSUPPLY'),

      // Costing
      costingMethod: _getElementTextOrNull(element, 'COSTINGMETHOD'),
      valuationMethod: _getElementTextOrNull(element, 'VALUATIONMETHOD'),

      // Opening balances
      openingBalance:
          _parseQuantity(_getElementText(element, 'OPENINGBALANCE')),
      openingValue:
          _parseFormattedNumber(_getElementText(element, 'OPENINGVALUE')),
      openingRate: _parseRate(_getElementText(element, 'OPENINGRATE')),

      // Boolean flags
      isCostCentresOn:
          _parseBool(_getElementTextOrNull(element, 'ISCOSTCENTRESON')),
      isBatchwiseOn:
          _parseBool(_getElementTextOrNull(element, 'ISBATCHWISEON')),
      isPerishableOn:
          _parseBool(_getElementTextOrNull(element, 'ISPERISHABLEON')),
      isDeleted: _parseBool(_getElementTextOrNull(element, 'ISDELETED')),
      ignoreNegativeStock:
          _parseBool(_getElementTextOrNull(element, 'IGNORENEGATIVESTOCK')),

      // Nested collections
      mailingNames: _parseMailingNames(element),
      hsnDetails: _parseHSNDetails(element),
      gstDetails: _parseGSTDetails(element),
      mrpDetails: _parseMRPDetails(element),
      batchAllocations: _parseStockBatchAllocations(element),
    );
  }

  /// Parse Mailing Names
  static List<String> _parseMailingNames(XmlElement element) {
    final names = <String>[];
    try {
      final mailingList = element.findElements('MAILINGNAME.LIST').firstOrNull;
      if (mailingList != null) {
        final nameElements = mailingList.findAllElements('MAILINGNAME');
        for (final nameElement in nameElements) {
          final name = nameElement.innerText.trim();
          if (name.isNotEmpty) {
            names.add(name);
          }
        }
      }
    } catch (e) {
      print('Error parsing mailing names: $e');
    }
    return names;
  }

  /// Parse HSN Details
  static List<HSNDetail> _parseHSNDetails(XmlElement element) {
    final hsnList = <HSNDetail>[];
    try {
      final hsnElements = element.findAllElements('HSNDETAILS.LIST');

      for (final hsnElement in hsnElements) {
        final hsnCode = _getElementTextOrNull(hsnElement, 'HSNCODE');
        if (hsnCode != null) {
          hsnList.add(HSNDetail(
            applicableFrom: _getElementTextOrNull(hsnElement, 'APPLICABLEFROM'),
            hsnCode: _getElementTextOrNull(hsnElement, 'HSNCODE'),
            hsnDescription: _getElementTextOrNull(hsnElement, 'HSN'),
            sourceOfDetails:
                _getElementTextOrNull(hsnElement, 'SRCOFHSNDETAILS'),
          ));
        }
      }
    } catch (e) {
      print('Error parsing HSN details: $e');
    }
    return hsnList;
  }

  /// Parse GST Details with nested rate details
  static List<GSTDetail> _parseGSTDetails(XmlElement element) {
    final gstList = <GSTDetail>[];
    try {
      final gstElements = element.findAllElements('GSTDETAILS.LIST');

      for (final gstElement in gstElements) {
        final taxability = _getElementTextOrNull(gstElement, 'TAXABILITY');

        if (taxability != null) {
          gstList.add(GSTDetail(
            applicableFrom: _getElementTextOrNull(gstElement, 'APPLICABLEFROM'),
            taxability: _getElementTextOrNull(gstElement, 'TAXABILITY'),
            isReverseChargeApplicable: _parseBool(
                _getElementTextOrNull(gstElement, 'ISREVERSECHARGEAPPLICABLE')),
            isNonGstGoods:
                _parseBool(_getElementTextOrNull(gstElement, 'ISNONGSTGOODS')),
            gstIneligibleItc: _parseBool(
                _getElementTextOrNull(gstElement, 'GSTINELIGIBLEITC')),
            statewiseDetails: _parseStatewiseDetails(gstElement),
          ));
        }
      }
    } catch (e) {
      print('Error parsing GST details: $e');
    }
    return gstList;
  }

  /// Parse Statewise GST Rate Details
  static List<StatewiseGSTDetail> _parseStatewiseDetails(XmlElement element) {
    final stateList = <StatewiseGSTDetail>[];
    try {
      final stateElements = element.findAllElements('STATEWISEDETAILS.LIST');

      for (final stateElement in stateElements) {
        stateList.add(StatewiseGSTDetail(
          stateName: _cleanValue(_getElementText(stateElement, 'STATENAME')),
          rateDetails: _parseGSTRateDetails(stateElement),
        ));
      }
    } catch (e) {
      print('Error parsing statewise details: $e');
    }
    return stateList;
  }

  /// Parse GST Rate Details (CGST, SGST, IGST, etc.)
  static List<GSTRateDetail> _parseGSTRateDetails(XmlElement element) {
    final rates = <GSTRateDetail>[];
    try {
      final rateElements = element.findAllElements('RATEDETAILS.LIST');

      for (final rateElement in rateElements) {
        final dutyHead = _getElementTextOrNull(rateElement, 'GSTRATEDUTYHEAD');
        if (dutyHead == null || dutyHead.isEmpty) continue;

        rates.add(GSTRateDetail(
          dutyHead: dutyHead,
          valuationType:
              _cleanValue(_getElementText(rateElement, 'GSTRATEVALUATIONTYPE')),
          rate: _parseFormattedNumber(_getElementText(rateElement, 'GSTRATE')),
          ratePerUnit: _parseFormattedNumber(
              _getElementText(rateElement, 'GSTRATEPERUNIT')),
        ));
      }
    } catch (e) {
      print('Error parsing GST rate details: $e');
    }
    return rates;
  }

  /// Parse MRP Details
  static List<MRPDetail> _parseMRPDetails(XmlElement element) {
    final mrpList = <MRPDetail>[];
    try {
      final mrpElements = element.findAllElements('MRPDETAILS.LIST');

      for (final mrpElement in mrpElements) {
        mrpList.add(MRPDetail(
          fromDate: _getElementTextOrNull(mrpElement, 'FROMDATE'),
          mrpRates: _parseMRPRateDetails(mrpElement),
        ));
      }
    } catch (e) {
      print('Error parsing MRP details: $e');
    }
    return mrpList;
  }

  /// Parse MRP Rate Details
  static List<MRPRateDetail> _parseMRPRateDetails(XmlElement element) {
    final rates = <MRPRateDetail>[];
    try {
      final rateElements = element.findAllElements('MRPRATEDETAILS.LIST');

      for (final rateElement in rateElements) {
        rates.add(MRPRateDetail(
          stateName: _cleanValue(_getElementText(rateElement, 'STATENAME')),
          mrpRate: _parseRate(_getElementText(rateElement, 'MRPRATE')),
        ));
      }
    } catch (e) {
      print('Error parsing MRP rate details: $e');
    }
    return rates;
  }

  /// Parse Batch Allocations for Stock Items
  static List<StockBatchAllocation> _parseStockBatchAllocations(
      XmlElement element) {
    final batches = <StockBatchAllocation>[];
    try {
      final batchElements = element.findAllElements('BATCHALLOCATIONS.LIST');

      for (final batchElement in batchElements) {

        final godownName = _getElementTextOrNull(batchElement, 'GODOWNNAME');
        if (godownName == null || godownName.isEmpty) continue;

        batches.add(StockBatchAllocation(
          godownName: godownName,
          batchName: _getElementTextOrNull(batchElement, 'BATCHNAME'),
          mfdOn: _getElementTextOrNull(batchElement, 'MFDON'),
          openingBalance:
              _parseQuantity(_getElementText(batchElement, 'OPENINGBALANCE')),
          openingValue: _parseFormattedNumber(
              _getElementText(batchElement, 'OPENINGVALUE')) * -1,
          openingRate: _parseRate(_getElementText(batchElement, 'OPENINGRATE')),
        ));
      }
    } catch (e) {
      print('Error parsing batch allocations: $e');
    }
    return batches;
  }

  static List<Group> parseGroups(String xml, String companyId) {
    try {
      final document = XmlDocument.parse(xml);
      final groups = <Group>[];

      final groupElements = document.findAllElements('GROUP');

      print('Found ${groupElements.length} group elements');

      for (final element in groupElements) {
        try {
          final group = _parseGroup(element, companyId);
          if (group.groupGuid.isNotEmpty) {
            groups.add(group);
          }
          print('✅ Parsed: ${group.name} (Parent: ${group.parent})');
        } catch (e, stack) {
          print('❌ Error parsing group: $e');
          print(stack);
        }
      }

      return groups;
    } catch (e, stack) {
      print('❌ Error parsing XML: $e');
      print(stack);
      return [];
    }
  }

  static Group _parseGroup(XmlElement element, String companyId) {
    return Group(
      groupGuid: _getElementText(element, 'GUID'),
      companyGuid: companyId,
      name: element.getAttribute('NAME') ?? _getElementText(element, 'NAME'),
      reservedName: element.getAttribute('RESERVEDNAME') ??
          _getElementText(element, 'RESERVEDNAME'),
      alterId: _parseInt(_getElementText(element, 'ALTERID')),
      parent: _cleanValue(_getElementText(element, 'PARENT')),
      narration: _getElementTextOrNull(element, 'NARRATION'),
      isBillwiseOn: _parseInt(_getElementTextOrNull(element, 'ISBILLWISEON')),
      isAddable: _parseInt(_getElementTextOrNull(element, 'ISADDABLE')),
      isDeleted: _parseInt(_getElementTextOrNull(element, 'ISDELETED')),
      isSubledger: _parseInt(_getElementTextOrNull(element, 'ISSUBLEDGER')),
      isRevenue: _parseInt(_getElementTextOrNull(element, 'ISREVENUE')),
      affectsGrossProfit:
          _parseInt(_getElementTextOrNull(element, 'AFFECTSGROSSPROFIT')),
      isDeemedPositive:
          _parseInt(_getElementTextOrNull(element, 'ISDEEMEDPOSITIVE')),
      trackNegativeBalances:
          _parseInt(_getElementTextOrNull(element, 'TRACKNEGATIVEBALANCES')),
      isCondensed: _parseInt(_getElementTextOrNull(element, 'ISCONDENSED')),
      addlAllocType: _cleanValue(_getElementText(element, 'ADDLALLOCTYPE')),
      gstApplicable: _getElementTextOrNull(element, 'GSTAPPLICABLE'),
      tdsApplicable: _getElementTextOrNull(element, 'TDSAPPLICABLE'),
      tcsApplicable: _getElementTextOrNull(element, 'TCSAPPLICABLE'),
      sortPosition: _parseInt(_getElementText(element, 'SORTPOSITION')),
      languageNames: _parseLanguageNames(element),
    );
  }

  /// Parse language names (alternative names)
  static List<String> _parseLanguageNames(XmlElement element) {
    final names = <String>[];
    try {
      final languageList =
          element.findElements('LANGUAGENAME.LIST').firstOrNull;
      if (languageList != null) {
        final nameList = languageList.findElements('NAME.LIST').firstOrNull;
        if (nameList != null) {
          final nameElements = nameList.findAllElements('NAME');
          for (final nameElement in nameElements) {
            final name = nameElement.innerText.trim();
            if (name.isNotEmpty) {
              names.add(name);
            }
          }
        }
      }
    } catch (e) {
      print('Error parsing language names: $e');
    }
    return names;
  }

  // services/tally_xml_parser.dart (update _parseLedger)

  static List<Ledger> parseLedgers(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      final ledgers = <Ledger>[];

      final ledgerElements = document.findAllElements('LEDGER');

      print('Found ${ledgerElements.length} ledger elements');

      for (final element in ledgerElements) {
        try {
          final ledger = _parseLedger(element);
          if (ledger.guid.isNotEmpty) {
            ledgers.add(ledger);
          }
          print('✅ Parsed: ${ledger.name} (${ledger.parent})');
        } catch (e, stack) {
          print('❌ Error parsing ledger: $e');
          print(stack);
        }
      }

      return ledgers;
    } catch (e, stack) {
      print('❌ Error parsing XML: $e');
      print(stack);
      return [];
    }
  }

  static Ledger _parseLedger(XmlElement element) {

      final name = element.getAttribute('NAME') ?? _getElementText(element, 'NAME');

      if (name == 'CLOSING STOCK'){
        print(name);
      }


    // Parse nested collections
    final contacts = _parseContactDetails(element);
    final mailingDetails = _parseMailingDetails(element);
    final gstRegistrations = _parseGSTRegistrations(element);
    final closingBalances = _parseClosingBalances(element);

    // Get latest mailing detail
    final latestMailing =
        mailingDetails.isNotEmpty ? mailingDetails.last : null;

    // Get latest GST registration
    final latestGst =
        gstRegistrations.isNotEmpty ? gstRegistrations.last : null;


    return Ledger(
      guid: _getElementText(element, 'GUID'),
      name: element.getAttribute('NAME') ?? _getElementText(element, 'NAME'),
      alterid: _parseInt(_getElementText(element, 'ALTERID')),
      parent: _cleanValue(_getElementText(element, 'PARENT')),
      narration: _getElementTextOrNull(element, 'NARRATION'),

      // Basic details
      currencyName: _getElementTextOrNull(element, 'CURRENCYNAME'),
      email: _getElementTextOrNull(element, 'EMAIL'),
      website: _getElementTextOrNull(element, 'WEBSITE'),
      description: _getElementTextOrNull(element, 'DESCRIPTION'), // ✅
      incomeTaxNumber: _getElementTextOrNull(element, 'INCOMETAXNUMBER'),
      partyGstin: _getElementTextOrNull(element, 'PARTYGSTIN'),

      // State/Country
      priorStateName: _getElementTextOrNull(element, 'PRIORSTATENAME'), // ✅
      countryOfResidence:
          _getElementTextOrNull(element, 'COUNTRYOFRESIDENCE'), // ✅

      // Balances
      openingBalance:
          _parseFormattedNumber(_getElementText(element, 'OPENINGBALANCE')),
      closingBalances: closingBalances,
      creditLimit:
          _parseFormattedNumber(_getElementText(element, 'CREDITLIMIT')), // ✅

      // Boolean flags
      isBillwiseOn: _parseBool(_getElementTextOrNull(element, 'ISBILLWISEON')),
      isCostCentresOn:
          _parseBool(_getElementTextOrNull(element, 'ISCOSTCENTRESON')),
      isInterestOn: _parseBool(_getElementTextOrNull(element, 'ISINTERESTON')),
      isDeleted: _parseBool(_getElementTextOrNull(element, 'ISDELETED')),
      isCostTrackingOn:
          _parseBool(_getElementTextOrNull(element, 'ISCOSTTRACKINGON')),
      isCreditDaysChkOn:
          _parseBool(_getElementTextOrNull(element, 'ISCREDITDAYSCHKON')), // ✅
      affectsStock: _parseBool(_getElementTextOrNull(element, 'AFFECTSSTOCK')),
      isGstApplicable:
          _parseBool(_getElementTextOrNull(element, 'ISGSTAPPLICABLE')),
      isTdsApplicable:
          _parseBool(_getElementTextOrNull(element, 'ISTDSAPPLICABLE')),
      isTcsApplicable:
          _parseBool(_getElementTextOrNull(element, 'ISTCSAPPLICABLE')),

      // Tax details
      taxClassificationName:
          _cleanValue(_getElementText(element, 'TAXCLASSIFICATIONNAME')),
      taxType: _getElementTextOrNull(element, 'TAXTYPE'),
      gstType: _cleanValue(_getElementText(element, 'GSTTYPE')),
      gstNatureOfSupply:
          _cleanValue(_getElementText(element, 'GSTNATUREOFSUPPLY')), // ✅

      // Credit period
      billCreditPeriod: _getElementTextOrNull(element, 'BILLCREDITPERIOD'), // ✅

      // Banking details
      ifscCode: _getElementTextOrNull(element, 'IFSCODE'),
      swiftCode: _getElementTextOrNull(element, 'SWIFTCODE'),
      bankAccountHolderName:
          _getElementTextOrNull(element, 'BANKACCHOLDERNAME'),

      // Contact details
      ledgerPhone: _getElementTextOrNull(element, 'LEDGERPHONE'),
      ledgerMobile: _getElementTextOrNull(element, 'LEDGERMOBILE'),
      ledgerContact: _getElementTextOrNull(element, 'LEDGERCONTACT'),
      ledgerCountryIsdCode:
          _getElementTextOrNull(element, 'LEDGERCOUNTRYISDCODE'), // ✅

      // Sort position
      sortPosition: _parseInt(_getElementText(element, 'SORTPOSITION')),

      // Latest mailing details
      mailingName: latestMailing?.mailingName,
      mailingState: latestMailing?.state,
      mailingPincode: latestMailing?.pincode,
      mailingCountry: latestMailing?.country,
      mailingAddress: latestMailing?.address ?? [],

      // Latest GST registration
      gstRegistrationType: latestGst?.gstRegistrationType,
      gstApplicableFrom: latestGst?.applicableFrom,
      gstPlaceOfSupply: latestGst?.placeOfSupply,
      gstin: latestGst?.gstin,

      // Collections
      languageNames: _parseLanguageNames(element),
      contacts: contacts,
      mailingDetails: mailingDetails,
      gstRegistrations: gstRegistrations,
    );
  }


  static List<VoucherType> parseVoucherTypes(String xmlString, String companyId) {
  final document = XmlDocument.parse(xmlString);
  final voucherTypes = <VoucherType>[];

  final voucherTypeElements = document.findAllElements('VOUCHERTYPE');

  for (final element in voucherTypeElements) {
    try {
      final voucherType = _parseVoucherType(element, companyId);
      if (voucherType.guid.isNotEmpty) {
          voucherTypes.add(voucherType);
        }
    } catch (e) {
      print('Error parsing voucher type: $e');
      // Continue parsing other voucher types
    }
  }

  return voucherTypes;
}

  static VoucherType _parseVoucherType(XmlElement element, String companyId) {
  // Get the LATEST prefix (most recent date)
  String? currentPrefix;
  final prefixLists = element.findElements('PREFIXLIST.LIST').toList();
  if (prefixLists.isNotEmpty) {
    // Tally lists them chronologically, so take the last one
    currentPrefix = _getElementText(prefixLists.last, 'NAME');
  }

  // Get the LATEST suffix
  String? currentSuffix;
  final suffixLists = element.findElements('SUFFIXLIST.LIST').toList();
  if (suffixLists.isNotEmpty) {
    currentSuffix = _getElementText(suffixLists.last, 'NAME');
  }

  // Get the LATEST restart rule
  String? restartPeriod;
  final restartLists = element.findElements('RESTARTFROMLIST.LIST').toList();
  if (restartLists.isNotEmpty) {
    restartPeriod = _getElementText(restartLists.last, 'RESTARTFROM');
  }

  return VoucherType(
    name:element.getAttribute('NAME') ?? _getElementText(element, 'NAME'),
    companyGuid: companyId,
    reservedName: element.getAttribute('RESERVEDNAME') ?? _getElementText(element, 'RESERVEDNAME'),
    guid: _getElementText(element, 'GUID'),
    parent: _getElementText(element, 'PARENT'),
    alterId: _parseInt(_getElementText(element, 'ALTERID')),
    masterId: _parseInt(_getElementText(element, 'MASTERID')),
    isDeemedPositive:  _parseBool(_getElementTextOrNull(element, 'ISDEEMEDPOSITIVE')),
    affectsStock:  _parseBool(_getElementTextOrNull(element, 'AFFECTSSTOCK')),
    isOptional:  _parseBool(_getElementTextOrNull(element, 'ISOPTIONAL')),
    isActive:  _parseBool(_getElementTextOrNull(element, 'ISACTIVE')),
    isDeleted:  _parseBool(_getElementTextOrNull(element, 'ISDELETED')),
    numberingMethod: _getElementText(element, 'NUMBERINGMETHOD'),
    preventDuplicates:  _parseBool(_getElementTextOrNull(element, 'PREVENTDUPLICATES')),
    currentPrefix: currentPrefix,
    currentSuffix: currentSuffix,
    restartPeriod: restartPeriod,
    isTaxInvoice:  _parseBool(_getElementTextOrNull(element, 'ISTAXINVOICE')),
    printAfterSave:  _parseBool(_getElementTextOrNull(element, 'PRINTAFTERSAVE')),
  );
}
  
  static List<Voucher> parseVouchers(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      final vouchers = <Voucher>[];

      final voucherElements = document.findAllElements('VOUCHER');

      print('Found ${voucherElements.length} voucher elements');

      for (final element in voucherElements) {
        try {
          final voucher = _parseVoucher(element);
          if (voucher.guid.isNotEmpty) {
            vouchers.add(voucher);
          }
          // print('✅ Parsed: ${voucher.voucherType} #${voucher.voucherNumber}');
        } catch (e, stack) {
          print('❌ Error parsing voucher: $e');
          print(stack);
        }
      }

      return vouchers;
    } catch (e, stack) {
      print('❌ Error parsing XML: $e');
      print(stack);
      return [];
    }
  }

  static Voucher _parseVoucher(XmlElement element) {
    // Parse ledger entries
    final ledgerEntries = _parseLedgerEntries(element);

    // Parse inventory entries
    final inventoryEntries = _parseInventoryEntries(element);

    return Voucher(
      guid: _getElementText(element, 'GUID'),
      masterId: _parseInt(_getElementText(element, 'MASTERID')),
      alterId: _parseInt(_getElementText(element, 'ALTERID')),
      voucherKey: _parseIntOrNull(_getElementTextOrNull(element, 'VOUCHERKEY')),
      voucherRetainKey:
          _parseIntOrNull(_getElementTextOrNull(element, 'VOUCHERRETAINKEY')),
      date: _getElementText(element, 'DATE'),
      effectiveDate: _getElementTextOrNull(element, 'EFFECTIVEDATE'),
      voucherType: _getElementText(element, 'VOUCHERTYPENAME'),
      voucherNumber: _getElementText(element, 'VOUCHERNUMBER'),
      voucherNumberSeries:
          _getElementTextOrNull(element, 'VOUCHERNUMBERSERIES'),
      persistedView: _getElementTextOrNull(element, 'PERSISTEDVIEW'),
      partyLedgerName: _getElementTextOrNull(element, 'PARTYLEDGERNAME'),
      partyGstin: _getElementTextOrNull(element, 'PARTYGSTIN'),
      narration: _getElementTextOrNull(element, 'NARRATION'),
      reference: _getElementTextOrNull(element, 'REFERENCE'),
      gstRegistrationType:
          _getElementTextOrNull(element, 'GSTREGISTRATIONTYPE'),
      placeOfSupply: _getElementTextOrNull(element, 'PLACEOFSUPPLY'),
      stateName: _getElementTextOrNull(element, 'STATENAME'),
      countryOfResidence: _getElementTextOrNull(element, 'COUNTRYOFRESIDENCE'),
      isDeleted: _parseBool(_getElementTextOrNull(element, 'ISDELETED')),
      isCancelled: _parseBool(_getElementTextOrNull(element, 'ISCANCELLED')),
      isInvoice: _parseBool(_getElementTextOrNull(element, 'ISINVOICE')),
      isOptional:
          _parseBoolOrNull(_getElementTextOrNull(element, 'ISOPTIONAL')),
      hasDiscounts:
          _parseBoolOrNull(_getElementTextOrNull(element, 'HASDISCOUNTS')),
      isDeemedPositive:
          _parseBoolOrNull(_getElementTextOrNull(element, 'ISDEEMEDPOSITIVE')),
      ledgerEntries: ledgerEntries,
      inventoryEntries: inventoryEntries,
    );
  }

  static Set<String> parseVoucherGuids(String xml) {
  final guids = <String>{};
  
  try {
      final document = XmlDocument.parse(xml);
    
    // Find all VOUCHER elements
    final vouchers = document.findAllElements('VOUCHER');
    
    for (var voucher in vouchers) {
      final guidElement = voucher.findElements('GUID').firstOrNull;
      if (guidElement != null && guidElement.innerText.isNotEmpty) {
        guids.add(guidElement.innerText.trim());
      }
    }
    
    print('📋 Parsed ${guids.length} GUIDs from Tally');
  } catch (e) {
    print('❌ Error parsing GUIDs: $e');
  }
  
  return guids;
}

  /// Parse ledger entries
  static List<LedgerEntry> _parseLedgerEntries(XmlElement element) {
    final entries = <LedgerEntry>[];
    try {
      // Use ALLLEDGERENTRIES.LIST
      final ledgerLists = element.findAllElements('ALLLEDGERENTRIES.LIST');

      for (final ledgerList in ledgerLists) {
        final ledgerName = _getElementText(ledgerList, 'LEDGERNAME');
        final amount =
            _parseFormattedNumber(_getElementText(ledgerList, 'AMOUNT'));
        final isPartyLedger =
            _parseBool(_getElementTextOrNull(ledgerList, 'ISPARTYLEDGER'));
        final isDeemedPositive = _parseBoolOrNull(
            _getElementTextOrNull(ledgerList, 'ISDEEMEDPOSITIVE'));

        // Parse bill allocations
        String? billName;
        double? billAmount;
        String? billDate;
        String? billType;

        final billAllocations =
            ledgerList.findAllElements('BILLALLOCATIONS.LIST');
        if (billAllocations.isNotEmpty) {
          final billAlloc = billAllocations.first;
          billName = _getElementTextOrNull(billAlloc, 'NAME');
          billAmount = _parseFormattedNumberOrNull(
              _getElementTextOrNull(billAlloc, 'AMOUNT'));
          billDate = _getElementTextOrNull(billAlloc, 'BILLDATE');
          billType = _getElementTextOrNull(billAlloc, 'BILLTYPE');
        }

        // Parse bank allocations
        String? instrumentNumber;
        String? instrumentDate;
        String? transactionType;

        final bankAllocations =
            ledgerList.findAllElements('BANKALLOCATIONS.LIST');
        if (bankAllocations.isNotEmpty) {
          final bankAlloc = bankAllocations.first;
          instrumentNumber =
              _getElementTextOrNull(bankAlloc, 'INSTRUMENTNUMBER');
          instrumentDate = _getElementTextOrNull(bankAlloc, 'INSTRUMENTDATE');
          transactionType = _getElementTextOrNull(bankAlloc, 'TRANSACTIONTYPE');
        }

        if (ledgerName.isNotEmpty) {
          entries.add(LedgerEntry(
            ledgerName: ledgerName,
            amount: amount,
            isPartyLedger: isPartyLedger,
            isDeemedPositive: isDeemedPositive,
            billName: billName,
            billAmount: billAmount,
            billDate: billDate,
            billType: billType,
            instrumentNumber: instrumentNumber,
            instrumentDate: instrumentDate,
            transactionType: transactionType,
          ));
        }
      }
    } catch (e) {
      print('Error parsing ledger entries: $e');
    }
    return entries;
  }

  /// Parse inventory entries
  static List<InventoryEntry> _parseInventoryEntries(XmlElement element) {
    final entries = <InventoryEntry>[];
    try {
      final inventoryLists =
          element.findAllElements('ALLINVENTORYENTRIES.LIST');
      for (final inventoryList in inventoryLists) {
        final stockItemName = _getElementText(inventoryList, 'STOCKITEMNAME');
        final rate = _getElementText(inventoryList, 'RATE');
        final amount =
            _parseFormattedNumber(_getElementText(inventoryList, 'AMOUNT'));
        final actualQty = _getElementText(inventoryList, 'ACTUALQTY');
        final billedQty = _getElementText(inventoryList, 'BILLEDQTY');
        final discount = _parseFormattedNumberOrNull(
            _getElementTextOrNull(inventoryList, 'DISCOUNT'));
        final hsnCode = _getElementTextOrNull(inventoryList, 'GSTHSNNAME');
        final hsnDescription =
            _getElementTextOrNull(inventoryList, 'GSTHSNDESCRIPTION');
        final isDeemedPositive = _parseBoolOrNull(_getElementTextOrNull(inventoryList, 'ISDEEMEDPOSITIVE'));

        // Parse batch allocations
        final batchAllocations = _parseBatchAllocations(inventoryList);

        if (stockItemName.isNotEmpty) {
          entries.add(InventoryEntry(
            stockItemName: stockItemName,
            rate: rate,
            amount: amount,
            actualQty: actualQty,
            billedQty: billedQty,
            discount: discount,
            hsnCode: hsnCode,
            hsnDescription: hsnDescription,
            isDeemedPositive: isDeemedPositive,
            batchAllocations: batchAllocations,
          ));
        }
      }
    } catch (e) {
      print('Error parsing inventory entries: $e');
    }
    return entries;
  }

  /// Parse batch allocations
  static List<BatchAllocation> _parseBatchAllocations(XmlElement element) {
    final batches = <BatchAllocation>[];
    try {
      final batchLists = element.findAllElements('BATCHALLOCATIONS.LIST');
      for (final batchList in batchLists) {
        final godownName = _getElementText(batchList, 'GODOWNNAME');
        final trackingNumber = _getElementText(batchList, 'TRACKINGNUMBER');
        final batchName = _getElementText(batchList, 'BATCHNAME');
        final amount =
            _parseFormattedNumber(_getElementText(batchList, 'AMOUNT'));
        final actualQty = _getElementText(batchList, 'ACTUALQTY');
        final billedQty = _getElementText(batchList, 'BILLEDQTY');
        final batchRate = _parseFormattedNumberOrNull(
            _getElementTextOrNull(batchList, 'BATCHRATE'));
        final destinationGodownName =
            _getElementTextOrNull(batchList, 'DESTINATIONGODOWNNAME');
        final mfgDate = _getElementTextOrNull(batchList, 'MFGDATE');
        final expiryDate = _getElementTextOrNull(batchList, 'EXPIRYDATE');
        final isDeemedPositive = _parseBoolOrNull(_getElementTextOrNull(element, 'ISDEEMEDPOSITIVE'));


        // if (godownName.isNotEmpty) {
          batches.add(BatchAllocation(
            godownName: godownName,
            batchName: batchName,
            amount: amount,
            actualQty: actualQty,
            billedQty: billedQty,
            trackingNumber: trackingNumber,
            batchRate: batchRate,
            destinationGodownName: destinationGodownName,
            mfgDate: mfgDate,
            expiryDate: expiryDate,
            isDeemedPositive: isDeemedPositive
          ));
        // }
      }
    } catch (e) {
      print('Error parsing batch allocations: $e');
    }
    return batches;
  }


  /// ✅ Parse contact details
  static List<ContactDetail> _parseContactDetails(XmlElement element) {
    final contacts = <ContactDetail>[];
    try {
      final contactLists = element.findAllElements('CONTACTDETAILS.LIST');
      for (final contactList in contactLists) {
        final name = _getElementText(contactList, 'NAME');
        final phoneNumber = _getElementText(contactList, 'PHONENUMBER');

        if (name.isNotEmpty || phoneNumber.isNotEmpty) {
          contacts.add(ContactDetail(
            name: name,
            phoneNumber: phoneNumber,
            countryIsdCode:
                _getElementTextOrNull(contactList, 'COUNTRYISDCODE'),
            isDefaultWhatsappNum: _parseBool(
                _getElementTextOrNull(contactList, 'ISDEFAULTWHATSAPPNUM')),
          ));
        }
      }
    } catch (e) {
      print('Error parsing contact details: $e');
    }
    return contacts;
  }


  static List<ClosingBalance> _parseClosingBalances(XmlElement element) {
    final closingBalances = <ClosingBalance>[];
    try {
      final closingList = element.findElements('LEDGERCLOSINGVALUES.LIST');
      for (final closingData in closingList) {

          closingBalances.add(ClosingBalance(
            date: _getElementText(closingData, 'DATE'),
            amount: _parseFormattedNumber(_getElementText(closingData, 'AMOUNT'))
          ));
      }
    } catch (e) {
      print('Error parsing contact details: $e');
    }
    return closingBalances;
  }

  /// ✅ Parse mailing details with addresses
  static List<MailingDetail> _parseMailingDetails(XmlElement element) {
    final mailingList = <MailingDetail>[];
    try {
      final mailingDetailLists =
          element.findAllElements('LEDMAILINGDETAILS.LIST');
      for (final mailingDetailList in mailingDetailLists) {
        final addresses = <String>[];

        // Parse multiple address lines
        final addressList =
            mailingDetailList.findElements('ADDRESS.LIST').firstOrNull;
        if (addressList != null) {
          final addressElements = addressList.findAllElements('ADDRESS');
          for (final addressElement in addressElements) {
            final address = addressElement.innerText.trim();
            if (address.isNotEmpty) {
              addresses.add(address);
            }
          }
        }

        mailingList.add(MailingDetail(
          applicableFrom: _getElementText(mailingDetailList, 'APPLICABLEFROM'),
          mailingName: _getElementTextOrNull(mailingDetailList, 'MAILINGNAME'),
          state: _getElementTextOrNull(mailingDetailList, 'STATE'),
          country: _getElementTextOrNull(mailingDetailList, 'COUNTRY'),
          pincode: _getElementTextOrNull(mailingDetailList, 'PINCODE'),
          address: addresses,
        ));
      }
    } catch (e) {
      print('Error parsing mailing details: $e');
    }
    return mailingList;
  }

  /// ✅ Parse GST registrations
  static List<GSTRegistrationDetail> _parseGSTRegistrations(
      XmlElement element) {
    final gstRegs = <GSTRegistrationDetail>[];
    try {
      final gstRegLists = element.findAllElements('LEDGSTREGDETAILS.LIST');
      for (final gstRegList in gstRegLists) {
        gstRegs.add(GSTRegistrationDetail(
          applicableFrom: _getElementText(gstRegList, 'APPLICABLEFROM'),
          gstRegistrationType:
              _getElementTextOrNull(gstRegList, 'GSTREGISTRATIONTYPE'),
          placeOfSupply: _getElementTextOrNull(gstRegList, 'PLACEOFSUPPLY'),
          gstin: _getElementTextOrNull(gstRegList, 'GSTIN'),
          transporterId: _getElementTextOrNull(gstRegList, 'TRANSPORTERID'),
          isOthTerritoryAssessee: _parseBool(
              _getElementTextOrNull(gstRegList, 'ISOTHTERRITORYASSESSEE')),
          considerPurchaseForExport: _parseBool(
              _getElementTextOrNull(gstRegList, 'CONSIDERPURCHASEFOREXPORT')),
          isTransporter:
              _parseBool(_getElementTextOrNull(gstRegList, 'ISTRANSPORTER')),
        ));
      }
    } catch (e) {
      print('Error parsing GST registrations: $e');
    }
    return gstRegs;
  }

  // Helper Methods

  static bool? _parseBoolOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase().trim();
    return lower == 'yes' || lower == 'true' || lower == '1';
  }

  static double? _parseFormattedNumberOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned);
  }

  static String _cleanValue(String value) {
    return value.replaceAll('&#4;', '').replaceAll('&#4', '').trim();
  }

  static String _getElementText(XmlElement element, String name) {
    try {
      final child = element.findElements(name).firstOrNull;
      return child?.innerText.trim() ?? '';
    } catch (e) {
      return '';
    }
  }

  static String? _getElementTextOrNull(XmlElement element, String name) {
    final text = _getElementText(element, name);
    return text.isEmpty ? null : text;
  }

  static int _parseInt(String? value) {
    if (value == null || value.isEmpty) return 0;
    try {
      final cleaned = value.replaceAll(',', '').replaceAll(' ', '').trim();
      return int.parse(cleaned);
    } catch (e) {
      return 0;
    }
  }

  // static double _parseFormattedNumber(String value) {
  //   if (value.isEmpty) return 0;

  //   try {
  //     // Handle: "(-)17,70,150.00" or "-17,70,150.00" or "17,70,150.00"
  //     bool isNegative =
  //         value.contains('(-)') || (value.startsWith('-') && value.length > 1);

  //     String cleaned = value
  //         .replaceAll('(-)', '')
  //         .replaceAll('-', '')
  //         .replaceAll(',', '')
  //         .replaceAll(' ', '')
  //         .trim();

  //     if (cleaned.isEmpty) return 0;

  //     double number = double.parse(cleaned);
  //     return isNegative ? -number : number;
  //   } catch (e) {
  //     print('Error parsing number "$value": $e');
  //     return 0;
  //   }
  // }

  static double _parseFormattedNumber(String value) {
    if (value.isEmpty) return 0;

    try {
      // If there's an '=' sign, extract the number after it (the result)
      String workingValue = value;
      if (value.contains('=')) {
        workingValue = value.split('=').last; // Get part after '='
      }

      // Clean: remove everything except digits and dots
     String cleaned = workingValue.replaceAll(RegExp(r'[^\d.\-]'), '').trim();
      // Ensure minus only at start
      if (cleaned.contains('-') && !cleaned.startsWith('-')) {
        cleaned = cleaned.replaceAll('-', '');
      }

      if (cleaned.isEmpty) return 0;

      return double.parse(cleaned);
    } catch (e) {
      print('Error parsing number "$value": $e');
      return 0;
    }
  }

  static double _parseQuantity(String value) {
    if (value.isEmpty) return 0;

    try {
      // "1000.000 KG = 1136.364 LTR" -> 1000.0
      // "(-)750.000 KG" -> -750.0
      bool isNegative = value.contains('(-)') || value.startsWith('-');

      String cleaned = value.replaceAll('(-)', '').replaceAll('-', '').trim();

      // Split by space to get just the number part
      final parts = cleaned.split(' ');
      if (parts.isEmpty) return 0;

      double number = double.parse(parts[0].replaceAll(',', ''));
      return isNegative ? -number : number;
    } catch (e) {
      print('Error parsing quantity "$value": $e');
      return 0;
    }
  }

  static double _parseRate(String value) {
    if (value.isEmpty) return 0;

    try {
      // "240.00/KG" -> 240.0
      // "1,999.00/KG" -> 1999.0
      final parts = value.split('/');
      if (parts.isEmpty) return 0;

      return double.parse(parts[0].replaceAll(',', '').trim());
    } catch (e) {
      print('Error parsing rate "$value": $e');
      return 0;
    }
  }

  static bool _parseBool(String? value) {
    if (value == null) return false;
    final lowered = value.toLowerCase().trim();
    return lowered == 'yes' || lowered == 'true';
  }

  static int? _parseIntOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value.trim());
  }
}

void prettyPrint(dynamic obj) {
  if (obj is Map || obj is List) {
    print(JsonEncoder.withIndent('  ').convert(obj));
  } else {
    // Try to convert to JSON if it has toJson method
    try {
      final json = (obj as dynamic).toJson();
      print(JsonEncoder.withIndent('  ').convert(json));
    } catch (e) {
      print(obj.toString());
    }
  }
}
