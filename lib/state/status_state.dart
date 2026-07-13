import 'package:flutter/foundation.dart';

class StatusState extends ChangeNotifier {
  final String _company = 'Meera Cotton & Synthetics Mills Pvt. Ltd.';
  final String _user = 'ADMIN';
  final String _database = 'SQL ODBC: MCMSL26_SQL';
  final String _fiscalYear = '2026-2027';
  final String _connectionStatus = 'Connected';

  String get company => _company;
  String get user => _user;
  String get database => _database;
  String get fiscalYear => _fiscalYear;
  String get connectionStatus => _connectionStatus;
  bool get isConnected => _connectionStatus == 'Connected';

  String get fullStatusString =>
      'Company: $_company | User: $_user | '
      'Database: $_database | FY: $_fiscalYear | '
      'Status: $_connectionStatus';
}
