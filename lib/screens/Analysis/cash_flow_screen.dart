// screens/Analysis/cash_flow_screen.dart

import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

class CashFlowScreen extends StatefulWidget {
  @override
  _CashFlowScreenState createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  String? _companyName;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    final company = await _db.getSelectedCompanyByGuid();
    setState(() {
      _companyName = company?['company_name'] as String?;
      _loading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cash Flow Statement'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () {},
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.monetization_on,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Cash Flow Statement',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _companyName ?? 'No Company Selected',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 32),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.construction, color: Colors.blue[700]),
                          SizedBox(height: 12),
                          Text(
                            'Coming Soon',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This report will show operating, investing,\nand financing activities',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}