import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';

class TallyService {
  final String tallyUrl = 'http://localhost:9000';

Future<String> getTallyData(String xmlRequest) async {
  try {
    final response = await http.post(
      Uri.parse(tallyUrl),
      headers: {
        'Content-Type': 'application/xml',
        'Access-Control-Allow-Origin': '*',
      },
      body: xmlRequest,
    );

    if (response.statusCode == 200) {
      // Use bodyBytes and decode with error handling
      try {
        return utf8.decode(response.bodyBytes);
      } catch (e) {
        // Fallback: decode allowing malformed UTF-8
        print('⚠️ UTF-8 decode error, using lenient decoder');
        return utf8.decode(response.bodyBytes, allowMalformed: true);
      }
    } else {
      throw Exception('Tally error: ${response.statusCode}');
    }
  } catch (e) {
    rethrow;
  }
}

//   Future<String> getCompanies() async {
//     print('\n🏢 [getCompanies] Fetching companies from Tally...');
//     const xml = '''
// <ENVELOPE>
//   <HEADER>
//     <VERSION>1</VERSION>
//     <TALLYREQUEST>Export</TALLYREQUEST>
//     <TYPE>Data</TYPE>
//     <ID>CompanyList</ID>
//   </HEADER>
//   <BODY>
//     <DESC>
//       <STATICVARIABLES>
//         <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
//       </STATICVARIABLES>
//       <TDL>
//         <TDLMESSAGE>
//           <REPORT NAME="CompanyList">
//             <FORMS>CompanyForm</FORMS>
//           </REPORT>
//           <FORM NAME="CompanyForm">
//             <PARTS>CompanyPart</PARTS>
//           </FORM>
//           <PART NAME="CompanyPart">
//             <LINES>CompanyLine</LINES>
//             <REPEAT>CompanyLine : CompanyCollection</REPEAT>
//             <SCROLLED>Vertical</SCROLLED>
//           </PART>
//           <LINE NAME="CompanyLine">
//             <FIELDS>FldGuid, FldCompanyName, FldAddress</FIELDS>
//             <XMLTAG>COMPANY</XMLTAG>
//           </LINE>
//           <FIELD NAME="FldGuid">
//             <SET>\$Guid</SET>
//             <XMLTAG>GUID</XMLTAG>
//           </FIELD>
//           <FIELD NAME="FldCompanyName">
//             <SET>\$Name</SET>
//             <XMLTAG>NAME</XMLTAG>
//           </FIELD>
//           <FIELD NAME="FldAddress">
//             <SET>\$Address</SET>
//             <XMLTAG>ADDRESS</XMLTAG>
//           </FIELD>
//           <COLLECTION NAME="CompanyCollection">
//             <TYPE>Company</TYPE>
//           </COLLECTION>
//         </TDLMESSAGE>
//       </TDL>
//     </DESC>
//   </BODY>
// </ENVELOPE>
// ''';
//     final result = await getTallyData(xml);
//     print('✅ [getCompanies] Companies data fetched successfully!\n');
//     return result;
//   }

// services/tally_service.dart

// /// Get ALL companies with complete details
// Future<String> getCompanies() async {
//   print('📥 Fetching all companies with complete details from Tally...');
  
//   const xml = '''
// <ENVELOPE>
//   <HEADER>
//     <VERSION>1</VERSION>
//     <TALLYREQUEST>Export</TALLYREQUEST>
//     <TYPE>Collection</TYPE>
//     <ID>AllCompanies</ID>
//   </HEADER>
//   <BODY>
//     <DESC>
//       <STATICVARIABLES>
//         <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
//       </STATICVARIABLES>
//       <TDL>
//         <TDLMESSAGE>
//           <COLLECTION NAME="AllCompanies">
//             <TYPE>Company</TYPE>
            
//             <!-- Basic Info -->
//             <FETCH>GUID, NAME, MASTERID, ALTERID</FETCH>
//             <FETCH>STARTINGFROM, BOOKSBEGINNINGFROM, ENDINGAT</FETCH>
            
//             <!-- Address Details -->
//             <FETCH>ADDRESS.LIST, MAILINGNAME.LIST</FETCH>
//             <FETCH>PINCODE, STATE, COUNTRY</FETCH>
            
//             <!-- Contact Details -->
//             <FETCH>EMAIL, PHONENUMBER, FAXNUMBER, WEBSITE</FETCH>
            
//             <!-- Tax Details -->
//             <FETCH>GSTTIN, INCOMETAXNUMBER, PAN</FETCH>
//             <FETCH>GSTREGISTRATIONTYPE, GSTAPPLICABLEDATE</FETCH>
            
//             <!-- Currency & Financial -->
//             <FETCH>CURRENCYNAME, BASECURRENCYID</FETCH>
//             <FETCH>FINANCIALYEARFROM, FINANCIALYEARTO</FETCH>
            
//             <!-- Banking -->
//             <FETCH>BANKNAME, BANKACCOUNTNUMBER, BANKIFSCCODE</FETCH>
//             <FETCH>BANKSWIFTCODE, BANKBRANCH</FETCH>
            
//             <!-- Company Settings -->
//             <FETCH>ISPAYROLLENABLED, ISGSTAPPLICABLE</FETCH>
//             <FETCH>ISTDSAPPLICABLE, ISTCSAPPLICABLE</FETCH>
//             <FETCH>USEEXCISE, USESERVICETAX, USEVAT</FETCH>
            
//             <!-- Security & Status -->
//             <FETCH>ISSECURITYENABLED, ISBOOKINUSE</FETCH>
//             <FETCH>ISAUDITED, ISDELETED</FETCH>
            
//             <!-- Company Numbers -->
//             <FETCH>LASTMASTERID, LASTALTERID</FETCH>
//             <FETCH>LASTVOUCHERID, LASTVOUCHERALTERID</FETCH>
//           </COLLECTION>
//         </TDLMESSAGE>
//       </TDL>
//     </DESC>
//   </BODY>
// </ENVELOPE>
// ''';
  
//   final result = await getTallyData(xml);
//   print(result);
//   return result;
// }

// Future<String> getCompanies() async {
//   print('📥 Fetching companies with all details from Tally...');
  
//   const xml = '''
// <ENVELOPE>
//   <HEADER>
//     <VERSION>1</VERSION>
//     <TALLYREQUEST>Export</TALLYREQUEST>
//     <TYPE>Data</TYPE>
//     <ID>MyCompanyList</ID>
//   </HEADER>
//   <BODY>
//     <DESC>
//       <STATICVARIABLES>
//         <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
//       </STATICVARIABLES>
//       <TDL>
//         <TDLMESSAGE>
//           <REPORT NAME="MyCompanyList">
//             <FORMS>MyCompanyForm</FORMS>
//           </REPORT>
          
//           <FORM NAME="MyCompanyForm">
//             <PARTS>MyCompanyPart</PARTS>
//           </FORM>
          
//           <PART NAME="MyCompanyPart">
//             <LINES>MyCompanyLine</LINES>
//             <REPEAT>MyCompanyLine : MyCompanies</REPEAT>
//             <SCROLLED>Vertical</SCROLLED>
//           </PART>
          
//           <LINE NAME="MyCompanyLine">
//             <!-- Basic Info -->
//             <FIELDS>CompName, CompReservedName, CompGUID, CompMasterID, CompAlterID</FIELDS>
            
//             <!-- Dates -->
//             <FIELDS>CompStartDate, CompEndDate, CompBooksBeginDate, CompGSTDate</FIELDS>
            
//             <!-- Contact -->
//             <FIELDS>CompEmail, CompPhone, CompFax, CompWebsite</FIELDS>
            
//             <!-- Address -->
//             <FIELDS>CompAddress, CompPincode, CompCity, CompState, CompCountry</FIELDS>
            
//             <!-- Tax -->
//             <FIELDS>CompITNo, CompPAN, CompGSTIN</FIELDS>
            
//             <!-- Currency -->
//             <FIELDS>CompCurrency</FIELDS>
            
//             <!-- Company Features -->
//             <FIELDS>CompBooksFrom, CompMaintainBillWise</FIELDS>
//             <FIELDS>CompInventory, CompIntegrateInventory</FIELDS>
//             <FIELDS>CompGSTApplicable, CompTDSApplicable, CompTCSApplicable</FIELDS>
//             <FIELDS>CompVATApplicable, CompExciseApplicable, CompServiceTaxApplicable</FIELDS>
//             <FIELDS>CompPayrollEnabled</FIELDS>
            
//             <!-- Status -->
//             <FIELDS>CompDeleted, CompAudited, CompSecurityEnabled, CompBookInUse</FIELDS>
//           </LINE>
          
//           <FIELD NAME="CompName"><SET>\$Name</SET></FIELD>
//           <FIELD NAME="CompReservedName"><SET>\$ReservedName</SET></FIELD>
//           <FIELD NAME="CompGUID"><SET>\$GUID</SET></FIELD>
//           <FIELD NAME="CompMasterID"><SET>\$MasterID</SET></FIELD>
//           <FIELD NAME="CompAlterID"><SET>\$AlterID</SET></FIELD>
          
//           <FIELD NAME="CompStartDate"><SET>\$StartingFrom</SET></FIELD>
//           <FIELD NAME="CompEndDate"><SET>\$EndingAt</SET></FIELD>
//           <FIELD NAME="CompBooksBeginDate"><SET>\$BooksBeginningFrom</SET></FIELD>
//           <FIELD NAME="CompGSTDate"><SET>\$GSTApplicableDate</SET></FIELD>
          
//           <FIELD NAME="CompEmail"><SET>\$Email</SET></FIELD>
//           <FIELD NAME="CompPhone"><SET>\$PhoneNumber</SET></FIELD>
//           <FIELD NAME="CompFax"><SET>\$FaxNumber</SET></FIELD>
//           <FIELD NAME="CompWebsite"><SET>\$Website</SET></FIELD>
          
//           <FIELD NAME="CompAddress"><SET>\$Address</SET></FIELD>
//           <FIELD NAME="CompPincode"><SET>\$Pincode</SET></FIELD>
//           <FIELD NAME="CompCity"><SET>\$CityName</SET></FIELD>
//           <FIELD NAME="CompState"><SET>\$StateName</SET></FIELD>
//           <FIELD NAME="CompCountry"><SET>\$CountryName</SET></FIELD>
          
//           <FIELD NAME="CompITNo"><SET>\$IncomeTaxNumber</SET></FIELD>
//           <FIELD NAME="CompPAN"><SET>\$PANITNumber</SET></FIELD>
//           <FIELD NAME="CompGSTIN"><SET>\$GSTRegistrationNumber</SET></FIELD>
          
//           <FIELD NAME="CompCurrency"><SET>\$CurrencyName</SET></FIELD>
          
//           <FIELD NAME="CompBooksFrom"><SET>\$BooksFrom</SET></FIELD>
//           <FIELD NAME="CompMaintainBillWise"><SET>\$IsBillWiseOn</SET></FIELD>
//           <FIELD NAME="CompInventory"><SET>\$IsInventoryOn</SET></FIELD>
//           <FIELD NAME="CompIntegrateInventory"><SET>\$IsInventoryIntegrated</SET></FIELD>
          
//           <FIELD NAME="CompGSTApplicable"><SET>\$IsGSTEnabled</SET></FIELD>
//           <FIELD NAME="CompTDSApplicable"><SET>\$IsTDSEnabled</SET></FIELD>
//           <FIELD NAME="CompTCSApplicable"><SET>\$IsTCSEnabled</SET></FIELD>
          
//           <FIELD NAME="CompVATApplicable"><SET>\$IsVATApplicable</SET></FIELD>
//           <FIELD NAME="CompExciseApplicable"><SET>\$IsExciseApplicable</SET></FIELD>
//           <FIELD NAME="CompServiceTaxApplicable"><SET>\$IsServiceTaxApplicable</SET></FIELD>
          
//           <FIELD NAME="CompPayrollEnabled"><SET>\$IsPayrollOn</SET></FIELD>
          
//           <FIELD NAME="CompDeleted"><SET>\$IsDeleted</SET></FIELD>
//           <FIELD NAME="CompAudited"><SET>\$IsAudited</SET></FIELD>
//           <FIELD NAME="CompSecurityEnabled"><SET>\$IsSecurityOn</SET></FIELD>
//           <FIELD NAME="CompBookInUse"><SET>\$IsBookInUse</SET></FIELD>
          
//           <COLLECTION NAME="MyCompanies">
//             <TYPE>Company</TYPE>
//           </COLLECTION>
//         </TDLMESSAGE>
//       </TDL>
//     </DESC>
//   </BODY>
// </ENVELOPE>
// ''';
  
//   final result = await getTallyData(xml);
//   print(result);
//   return result;
// }
Future<String> getCompanies() async {
  print('📥 Fetching companies with all details from Tally...');
  
  const xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Data</TYPE>
    <ID>MyCompanyList</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <REPORT NAME="MyCompanyList">
            <FORMS>MyCompanyForm</FORMS>
          </REPORT>
          
          <FORM NAME="MyCompanyForm">
            <PARTS>MyCompanyPart</PARTS>
          </FORM>
          
          <PART NAME="MyCompanyPart">
            <LINES>MyCompanyLine</LINES>
            <REPEAT>MyCompanyLine : MyCompanies</REPEAT>
            <SCROLLED>Vertical</SCROLLED>
          </PART>
          
          <LINE NAME="MyCompanyLine">
            <!-- Basic Info -->
            <FIELDS>CompName, CompReservedName, CompGUID, CompMasterID, CompAlterID</FIELDS>
            
            <!-- Dates -->
            <FIELDS>CompStartDate, CompEndDate, CompBooksBeginDate, CompGSTDate</FIELDS>
            
            <!-- Contact -->
            <FIELDS>CompEmail, CompPhone, CompFax, CompWebsite</FIELDS>
            
            <!-- Address -->
            <FIELDS>CompAddress, CompPincode, CompCity, CompState, CompCountry</FIELDS>
            
            <!-- Tax -->
            <FIELDS>CompITNo, CompPAN, CompGSTIN</FIELDS>
            
            <!-- Currency -->
            <FIELDS>CompCurrency, CompBaseCurrency</FIELDS>
            
            <!-- Books & Dates -->
            <FIELDS>CompBooksFrom</FIELDS>
            
            <!-- Accounting Features -->
            <FIELDS>CompMaintainAccounts, CompMaintainBillWise, CompEnableCostCentres, CompEnableInterestCalc</FIELDS>
            
            <!-- Inventory Features -->
            <FIELDS>CompInventory, CompIntegrateInventory, CompMultiPriceLevel, CompEnableBatches</FIELDS>
            <FIELDS>CompMaintainExpiryDate, CompEnableJobOrderProcessing, CompEnableCostTracking, CompEnableJobCosting</FIELDS>
            <FIELDS>CompUseDiscountColumn, CompUseSeparateActualBilledQty</FIELDS>
            
            <!-- GST & Taxation -->
            <FIELDS>CompGSTApplicable, CompSetAlterCompanyGSTRate</FIELDS>
            <FIELDS>CompTDSApplicable, CompTCSApplicable</FIELDS>
            <FIELDS>CompVATApplicable, CompExciseApplicable, CompServiceTaxApplicable</FIELDS>
            
            <!-- Online Access -->
            <FIELDS>CompEnableBrowserReports, CompEnableTallyNET</FIELDS>
            
            <!-- Payroll -->
            <FIELDS>CompPayrollEnabled, CompEnablePayrollStatutory</FIELDS>
            
            <!-- Others -->
            <FIELDS>CompEnablePaymentLinkQR, CompEnableMultiAddress, CompMarkModifiedVouchers</FIELDS>
            
            <!-- Status -->
            <FIELDS>CompDeleted, CompAudited, CompSecurityEnabled, CompBookInUse</FIELDS>
          </LINE>
          
          <!-- Basic Info Fields -->
          <FIELD NAME="CompName"><SET>\$Name</SET></FIELD>
          <FIELD NAME="CompReservedName"><SET>\$ReservedName</SET></FIELD>
          <FIELD NAME="CompGUID"><SET>\$GUID</SET></FIELD>
          <FIELD NAME="CompMasterID"><SET>\$MasterID</SET></FIELD>
          <FIELD NAME="CompAlterID"><SET>\$AlterID</SET></FIELD>
          
          <!-- Date Fields -->
          <FIELD NAME="CompStartDate"><SET>\$StartingFrom</SET></FIELD>
          <FIELD NAME="CompEndDate"><SET>\$EndingAt</SET></FIELD>
          <FIELD NAME="CompBooksBeginDate"><SET>\$BooksBeginningFrom</SET></FIELD>
          <FIELD NAME="CompGSTDate"><SET>\$GSTApplicableDate</SET></FIELD>
          <FIELD NAME="CompBooksFrom"><SET>\$BooksFrom</SET></FIELD>
          
          <!-- Contact Fields -->
          <FIELD NAME="CompEmail"><SET>\$Email</SET></FIELD>
          <FIELD NAME="CompPhone"><SET>\$PhoneNumber</SET></FIELD>
          <FIELD NAME="CompFax"><SET>\$FaxNumber</SET></FIELD>
          <FIELD NAME="CompWebsite"><SET>\$Website</SET></FIELD>
          
          <!-- Address Fields -->
          <FIELD NAME="CompAddress"><SET>\$Address</SET></FIELD>
          <FIELD NAME="CompPincode"><SET>\$Pincode</SET></FIELD>
          <FIELD NAME="CompCity"><SET>\$CityName</SET></FIELD>
          <FIELD NAME="CompState"><SET>\$StateName</SET></FIELD>
          <FIELD NAME="CompCountry"><SET>\$CountryName</SET></FIELD>
          
          <!-- Tax Fields -->
          <FIELD NAME="CompITNo"><SET>\$IncomeTaxNumber</SET></FIELD>
          <FIELD NAME="CompPAN"><SET>\$PANITNumber</SET></FIELD>
          <FIELD NAME="CompGSTIN"><SET>\$GSTRegistrationNumber</SET></FIELD>
          
          <!-- Currency Fields -->
          <FIELD NAME="CompCurrency"><SET>\$CurrencyName</SET></FIELD>
          <FIELD NAME="CompBaseCurrency"><SET>\$BaseCurrencyName</SET></FIELD>
          
          <!-- Accounting Feature Fields -->
          <FIELD NAME="CompMaintainAccounts"><SET>\$IsMaintainAccountsOn</SET></FIELD>
          <FIELD NAME="CompMaintainBillWise"><SET>\$IsBillWiseOn</SET></FIELD>
          <FIELD NAME="CompEnableCostCentres"><SET>\$IsCostCentresOn</SET></FIELD>
          <FIELD NAME="CompEnableInterestCalc"><SET>\$IsInterestCalcOn</SET></FIELD>
          
          <!-- Inventory Feature Fields -->
          <FIELD NAME="CompInventory"><SET>\$IsInventoryOn</SET></FIELD>
          <FIELD NAME="CompIntegrateInventory"><SET>\$IsIntegrated</SET></FIELD>
          <FIELD NAME="CompMultiPriceLevel"><SET>\$IsMultiPriceLevelsOn</SET></FIELD>
          <FIELD NAME="CompEnableBatches"><SET>\$IsBatchesOn</SET></FIELD>
          <FIELD NAME="CompMaintainExpiryDate"><SET>\$IsExpiryDatesOn</SET></FIELD>
          <FIELD NAME="CompEnableJobOrderProcessing"><SET>\$IsJobOrderProcessingOn</SET></FIELD>
          <FIELD NAME="CompEnableCostTracking"><SET>\$IsCostTrackingOn</SET></FIELD>
          <FIELD NAME="CompEnableJobCosting"><SET>\$IsJobCostingOn</SET></FIELD>
          <FIELD NAME="CompUseDiscountColumn"><SET>\$UseDiscountColumn</SET></FIELD>
          <FIELD NAME="CompUseSeparateActualBilledQty"><SET>\$UseSeparateActualBilledQty</SET></FIELD>
          
          <!-- GST & Tax Feature Fields -->
          <FIELD NAME="CompGSTApplicable"><SET>\$IsGSTEnabled</SET></FIELD>
          <FIELD NAME="CompSetAlterCompanyGSTRate"><SET>\$SetAlterCompanyGSTRate</SET></FIELD>
          <FIELD NAME="CompTDSApplicable"><SET>\$IsTDSEnabled</SET></FIELD>
          <FIELD NAME="CompTCSApplicable"><SET>\$IsTCSEnabled</SET></FIELD>
          <FIELD NAME="CompVATApplicable"><SET>\$IsVATApplicable</SET></FIELD>
          <FIELD NAME="CompExciseApplicable"><SET>\$IsExciseApplicable</SET></FIELD>
          <FIELD NAME="CompServiceTaxApplicable"><SET>\$IsServiceTaxApplicable</SET></FIELD>
          
          <!-- Online Access Fields -->
          <FIELD NAME="CompEnableBrowserReports"><SET>\$EnableBrowserReports</SET></FIELD>
          <FIELD NAME="CompEnableTallyNET"><SET>\$EnableTallyNET</SET></FIELD>
          
          <!-- Payroll Fields -->
          <FIELD NAME="CompPayrollEnabled"><SET>\$IsPayrollOn</SET></FIELD>
          <FIELD NAME="CompEnablePayrollStatutory"><SET>\$IsPayrollStatutoryOn</SET></FIELD>
          
          <!-- Other Feature Fields -->
          <FIELD NAME="CompEnablePaymentLinkQR"><SET>\$EnablePaymentLinkQR</SET></FIELD>
          <FIELD NAME="CompEnableMultiAddress"><SET>\$EnableMultipleAddresses</SET></FIELD>
          <FIELD NAME="CompMarkModifiedVouchers"><SET>\$MarkModifiedVouchers</SET></FIELD>
          
          <!-- Status Fields -->
          <FIELD NAME="CompDeleted"><SET>\$IsDeleted</SET></FIELD>
          <FIELD NAME="CompAudited"><SET>\$IsAudited</SET></FIELD>
          <FIELD NAME="CompSecurityEnabled"><SET>\$IsSecurityOn</SET></FIELD>
          <FIELD NAME="CompBookInUse"><SET>\$IsBookInUse</SET></FIELD>
          
          <COLLECTION NAME="MyCompanies">
            <TYPE>Company</TYPE>
          </COLLECTION>
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>
''';
  
  final result = await getTallyData(xml);
  print(result);
  return result;
}
Future<String> getGroups(String companyName, int lastAlterId) async {
  print('\n📁 [getGroups] Fetching groups from Tally...');
      
  final xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Data</TYPE>
    <ID>GroupReport</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
        <SVCURRENTCOMPANY>$companyName</SVCURRENTCOMPANY>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <REPORT NAME="GroupReport">
            <FORMS>GroupForm</FORMS>
          </REPORT>
          <FORM NAME="GroupForm">
            <PARTS>GroupPart</PARTS>
          </FORM>
          <PART NAME="GroupPart">
            <LINES>GroupLine</LINES>
            <REPEAT>GroupLine : GroupCollection</REPEAT>
            <SCROLLED>Vertical</SCROLLED>
          </PART>
          <LINE NAME="GroupLine">
            <FIELDS>FldGuid, FldName, FldParent, FldAlterId, FldAlias</FIELDS>
            <XMLTAG>GROUP</XMLTAG>
          </LINE>
          <FIELD NAME="FldGuid">
            <SET>\$Guid</SET>
            <XMLTAG>GUID</XMLTAG>
          </FIELD>
          <FIELD NAME="FldName">
            <SET>\$Name</SET>
            <XMLTAG>NAME</XMLTAG>
          </FIELD>
          <FIELD NAME="FldParent">
            <SET>If \$\$IsEmpty:\$Parent Then "" Else \$Parent</SET>
            <XMLTAG>PARENT</XMLTAG>
          </FIELD>
          <FIELD NAME="FldAlterId">
            <SET>\$AlterID</SET>
            <XMLTAG>ALTERID</XMLTAG>
          </FIELD>
          <FIELD NAME="FldAlias">
            <SET>\$AlternateName</SET>
            <XMLTAG>ALIAS</XMLTAG>
          </FIELD>
          <COLLECTION NAME="GroupCollection">
            <TYPE>Group</TYPE>
            ${lastAlterId > 0 ? '<FILTER>NewGroups</FILTER>' : ''}
          </COLLECTION>
          ${lastAlterId > 0 ? '''
          <SYSTEM TYPE="Formulae" NAME="NewGroups">
            \$AlterID > $lastAlterId
          </SYSTEM>
          ''' : ''}
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>
''';
  
  final result = await getTallyData(xml);
  return result;
}

Future<String> getAllGroups(String companyName, int lastAlterId) async {
  print('📥 Fetching all groups from Tally...');
  
  final xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Collection</TYPE>
    <ID>AllGroups</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
        <SVCURRENTCOMPANY>$companyName</SVCURRENTCOMPANY>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <COLLECTION NAME="AllGroups" ISMODIFY="No">
            <TYPE>Group</TYPE>
            ${lastAlterId > 0 ? '<FILTER>NewGroups</FILTER>' : ''}
            <FETCH>*</FETCH>
          </COLLECTION>
          ${lastAlterId > 0 ? '''
          <SYSTEM TYPE="Formulae" NAME="NewGroups">
            \$AlterID > $lastAlterId
          </SYSTEM>
          ''' : ''}
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>
''';
  
  final result = await getTallyData(xml);
  print('✅ All groups fetched!');
  return result;
}

/// Main fetch function - gets complete stock item XML
Future<String> getAllStockItems(String companyName, int lastAlterId) async {
  print('📥 Fetching full stock item data from Tally...');
  
  final xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Collection</TYPE>
    <ID>AllStockItems</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
        <SVCURRENTCOMPANY>$companyName</SVCURRENTCOMPANY>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <COLLECTION NAME="AllStockItems" ISMODIFY="No">
            <TYPE>Stock Item</TYPE>
            ${lastAlterId > 0 ? '<FILTER>NewStockItems</FILTER>' : ''}
            <FETCH>*</FETCH>
          </COLLECTION>
          ${lastAlterId > 0 ? '''
          <SYSTEM TYPE="Formulae" NAME="NewStockItems">
            \$AlterID > $lastAlterId
          </SYSTEM>
          ''' : ''}
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>
''';
  
  final result = await getTallyData(xml);
  print('✅ Complete stock items fetched!');
  return result;
}


Future<String> getAllLedgers(String companyName, int lastAlterId) async {
  print('📥 Fetching all ledgers from Tally...');
  
  final xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Collection</TYPE>
    <ID>AllLedgers</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
        <SVCURRENTCOMPANY>$companyName</SVCURRENTCOMPANY>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <COLLECTION NAME="AllLedgers" ISMODIFY="No">
            <TYPE>Ledger</TYPE>
            ${lastAlterId > 0 ? '<FILTER>NewLedgers</FILTER>' : ''}
            <FETCH>*</FETCH>
          </COLLECTION>
          ${lastAlterId > 0 ? '''
          <SYSTEM TYPE="Formulae" NAME="NewLedgers">
            \$AlterID > $lastAlterId
          </SYSTEM>
          ''' : ''}
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>
''';
  
  final result = await getTallyData(xml);
  print('✅ All ledgers fetched!');
  return result;
}

  Future<String> getVoucherTypes(String companyName, int lastAlterId) async {
  print('📥 Fetching voucher types from Tally...');
  
  final xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Collection</TYPE>
    <ID>AllVoucherTypes</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
        <SVCURRENTCOMPANY>$companyName</SVCURRENTCOMPANY>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <COLLECTION NAME="AllVoucherTypes">
            <TYPE>VoucherType</TYPE>
            ${lastAlterId > 0 ? '<FILTER>ModifiedVoucherTypes</FILTER>' : ''}
            
            <!-- Core Identification -->
            <FETCH>NAME, GUID, PARENT</FETCH>
            <FETCH>ALTERID, MASTERID</FETCH>
            
            <!-- Voucher Behavior -->
            <FETCH>ISDEEMEDPOSITIVE, AFFECTSSTOCK</FETCH>
            <FETCH>ISOPTIONAL, ISACTIVE, ISDELETED</FETCH>
            
            <!-- Numbering Config -->
            <FETCH>NUMBERINGMETHOD</FETCH>
            <FETCH>PREVENTDUPLICATES, PREFILLZERO</FETCH>
            <FETCH>BEGINNINGNUMBER, WIDTHOFNUMBER</FETCH>
            
            <!-- Tax & Invoice -->
            <FETCH>ISTAXINVOICE</FETCH>
            <FETCH>DEFAULTGSTREGISTRATION</FETCH>
            <FETCH>ALLOWMULTIPLETAXUNITSPERSERIES</FETCH>
            <FETCH>PRINTAFTERSAVE, USEFORPOSINVOICE</FETCH>
            
            <!-- Additional Useful -->
            <FETCH>COMMONNARRATION, EFFECTIVEDATE</FETCH>
            
            <!-- Prefix/Suffix Lists -->
            <FETCH>PREFIXLIST.LIST</FETCH>
            <FETCH>SUFFIXLIST.LIST</FETCH>
            
            <!-- Restart Rules -->
            <FETCH>RESTARTFROMLIST.LIST</FETCH>
            
            <!-- Number Series -->
            <FETCH>VOUCHERNUMBERSERIES.LIST</FETCH>
            
          </COLLECTION>
          
          ${lastAlterId > 0 ? '''
          <SYSTEM TYPE="Formulae" NAME="ModifiedVoucherTypes">
            \$AlterID > $lastAlterId
          </SYSTEM>
          ''' : ''}
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>
''';
  
  final result = await getTallyData(xml);
  print('✅ Voucher types fetched!');
  return result;
}

Future<String> getAllVouchers(String companyName, int lastAlterId, String fromDate, String toDate) async {
  print('📥 Fetching vouchers from Tally...');
  
  final xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Collection</TYPE>
    <ID>AllVouchers</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
        <SVCURRENTCOMPANY>$companyName</SVCURRENTCOMPANY>
        <SVFROMDATE TYPE="Date">$fromDate</SVFROMDATE>
        <SVTODATE TYPE="Date">$toDate</SVTODATE>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <COLLECTION NAME="AllVouchers">
            <TYPE>Voucher</TYPE>
            ${lastAlterId > 0 ? '<FILTER>ModifiedVouchers</FILTER>' : ''}
            
            <!-- Voucher Header -->
            <FETCH>GUID, DATE, EFFECTIVEDATE, VOUCHERTYPENAME, VOUCHERNUMBER</FETCH>
            <FETCH>PARTYLEDGERNAME, PARTYGSTIN, NARRATION, REFERENCE</FETCH>
            <FETCH>MASTERID, ALTERID, VOUCHERKEY, VOUCHERRETAINKEY</FETCH>
            <FETCH>PERSISTEDVIEW, VOUCHERNUMBERSERIES</FETCH>
            <FETCH>ISDELETED, ISCANCELLED, ISINVOICE, ISOPTIONAL, ISDEEMEDPOSITIVE</FETCH>
            <FETCH>HASDISCOUNTS</FETCH>
            
            <!-- GST Fields -->
            <FETCH>GSTREGISTRATIONTYPE, PLACEOFSUPPLY, STATENAME, COUNTRYOFRESIDENCE</FETCH>
            
            <!-- ALL Ledger Entries -->
            <FETCH>ALLLEDGERENTRIES</FETCH>
            
            
            <!-- Bill Allocations -->
            <FETCH>ALLLEDGERENTRIES.BILLALLOCATIONS</FETCH>
            
            
            <!-- Bank Allocations -->
            <FETCH>ALLLEDGERENTRIES.BANKALLOCATIONS</FETCH>
           
            
            <!-- ALL Inventory Entries -->
            <FETCH>ALLINVENTORYENTRIES</FETCH>
                        
            <!-- Batch Allocations -->
            <FETCH>ALLINVENTORYENTRIES.BATCHALLOCATIONS</FETCH>
            
          </COLLECTION>
          
          ${lastAlterId > 0 ? '''
          <SYSTEM TYPE="Formulae" NAME="ModifiedVouchers">
            \$AlterID > $lastAlterId
          </SYSTEM>
          ''' : ''}
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>
''';
  
  final result = await getTallyData(xml);
  // print(result);
  print('✅ Vouchers fetched!');
  return result;
}

/// Step 1: Get all GUIDs (your existing working function)
Future<List<String>> fetchVoucherGUIDs(
  String companyName, String fromDate, String toDate, int lastAlterId,
) async {
  print('📋 Fetching voucher GUIDs...');

  final xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Collection</TYPE>
    <ID>VoucherGUIDs</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
        <SVCURRENTCOMPANY>$companyName</SVCURRENTCOMPANY>
        <SVFROMDATE TYPE="Date">$fromDate</SVFROMDATE>
        <SVTODATE TYPE="Date">$toDate</SVTODATE>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <COLLECTION NAME="VoucherGUIDs">
            <TYPE>Voucher</TYPE>
            <FETCH>GUID</FETCH>
          </COLLECTION>
          ${lastAlterId > 0 ? '''
          <SYSTEM TYPE="Formulae" NAME="ModifiedFilter">
            \$AlterID > $lastAlterId
          </SYSTEM>
          ''' : ''}
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>''';

  final result = await getTallyData(xml);

  final regex = RegExp(r'<GUID>(.*?)</GUID>');
  final guids = regex.allMatches(result)
      .map((m) => m.group(1)?.trim() ?? '')
      .where((g) => g.isNotEmpty)
      .toList();

  print('✅ Found ${guids.length} vouchers');
  return guids;
}

/// Fetch batch of vouchers by multiple GUIDs (10-20 at a time)
Future<String> fetchVoucherBatch(
  String companyName, String fromDate, String toDate, List<String> guids,
) async {
  final guidFilter = guids.map((g) => '\$GUID = "$g"').join(' OR ');

  final xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Collection</TYPE>
    <ID>VoucherBatch</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
        <SVCURRENTCOMPANY>$companyName</SVCURRENTCOMPANY>
        <SVFROMDATE TYPE="Date">$fromDate</SVFROMDATE>
        <SVTODATE TYPE="Date">$toDate</SVTODATE>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <COLLECTION NAME="VoucherBatch">
            <TYPE>Voucher</TYPE>
            <FILTER>GuidBatchFilter</FILTER>
            
            <FETCH>GUID, DATE, EFFECTIVEDATE, VOUCHERTYPENAME, VOUCHERNUMBER</FETCH>
            <FETCH>PARTYLEDGERNAME, PARTYGSTIN, NARRATION, REFERENCE</FETCH>
            <FETCH>MASTERID, ALTERID, VOUCHERKEY, VOUCHERRETAINKEY</FETCH>
            <FETCH>PERSISTEDVIEW, VOUCHERNUMBERSERIES</FETCH>
            <FETCH>ISDELETED, ISCANCELLED, ISINVOICE, ISOPTIONAL, ISDEEMEDPOSITIVE</FETCH>
            <FETCH>HASDISCOUNTS</FETCH>
            <FETCH>GSTREGISTRATIONTYPE, PLACEOFSUPPLY, STATENAME, COUNTRYOFRESIDENCE</FETCH>
            <FETCH>ALLLEDGERENTRIES</FETCH>
            <FETCH>ALLLEDGERENTRIES.BILLALLOCATIONS</FETCH>
            <FETCH>ALLLEDGERENTRIES.BANKALLOCATIONS</FETCH>
            <FETCH>ALLINVENTORYENTRIES</FETCH>
            <FETCH>ALLINVENTORYENTRIES.BATCHALLOCATIONS</FETCH>
          </COLLECTION>
          
          <SYSTEM TYPE="Formulae" NAME="GuidBatchFilter">
            $guidFilter
          </SYSTEM>
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>''';

  for (int attempt = 1; attempt <= 3; attempt++) {
    try {
      final result = await getTallyData(xml);
      return result;
    } catch (e) {
      print('⚠️ Attempt $attempt failed: $e');
      if (attempt < 3) {
        await Future.delayed(Duration(seconds: attempt * 2 + 1));
      } else {
        rethrow;
      }
    }
  }
  return '';
}

/// Main function - fetch all vouchers in batches
Future<List<String>> getAllVouchersBatched(
  String companyName, int lastAlterId, String fromDate, String toDate,
  {int batchSize = 150, Function(int fetched, int total)? onProgress}
) async {
  final guids = await fetchVoucherGUIDs(companyName, fromDate, toDate, lastAlterId);
  if (guids.isEmpty) return [];

  final totalBatches = (guids.length / batchSize).ceil();
  final List<String> allResults = [];

  for (int i = 0; i < guids.length; i += batchSize) {
    final batchNum = (i ~/ batchSize) + 1;
    final end = (i + batchSize > guids.length) ? guids.length : i + batchSize;
    final batchGuids = guids.sublist(i, end);

    print('📦 Batch $batchNum/$totalBatches (${batchGuids.length} vouchers)');

    final result = await fetchVoucherBatch(companyName, fromDate, toDate, batchGuids);
    allResults.add(result);

    // Pause every 10 batches to prevent socket overload
    if (batchNum % 10 == 0) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    onProgress?.call(end, guids.length);
  }

  print('✅ All ${guids.length} vouchers fetched in $totalBatches batches');
  return allResults;
}

Future<String> getAllVouchersGuid(String companyName) async {
  print('📥 Fetching vouchers GUID from Tally...');
  
  final xml = '''
<ENVELOPE>
  <HEADER>
    <VERSION>1</VERSION>
    <TALLYREQUEST>Export</TALLYREQUEST>
    <TYPE>Collection</TYPE>
    <ID>AllVouchers</ID>
  </HEADER>
  <BODY>
    <DESC>
      <STATICVARIABLES>
        <SVEXPORTFORMAT>\$\$SysName:XML</SVEXPORTFORMAT>
        <SVCURRENTCOMPANY>$companyName</SVCURRENTCOMPANY>
      </STATICVARIABLES>
      <TDL>
        <TDLMESSAGE>
          <COLLECTION NAME="AllVouchers">
            <TYPE>Voucher</TYPE>
            <FETCH>GUID</FETCH>
          </COLLECTION>
        </TDLMESSAGE>
      </TDL>
    </DESC>
  </BODY>
</ENVELOPE>
''';
  
  final result = await getTallyData(xml);
  print('✅ Vouchers GUID fetched!');
  return result;
}


}

