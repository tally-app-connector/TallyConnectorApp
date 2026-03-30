import '../models/company_model.dart';

class AppState {
  static Company? selectedCompany;
  static List<Company> companies = [];
  static bool isOffline = false;
}
