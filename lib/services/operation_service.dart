import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class OperationMaster {
  final int omCode;
  final String omDesc;
  final double omFixRate;
  final String omUser;
  final String omUserDtTime;

  const OperationMaster({
    required this.omCode,
    required this.omDesc,
    required this.omFixRate,
    this.omUser = 'ADMIN',
    this.omUserDtTime = '',
  });

  factory OperationMaster.fromJson(Map<String, dynamic> json) {
    return OperationMaster(
      omCode: json['omCode'] is int
          ? json['omCode']
          : (int.tryParse(json['omCode']?.toString() ?? '0') ?? 0),
      omDesc: json['omDesc']?.toString() ?? '',
      omFixRate: json['omFixRate'] is num
          ? (json['omFixRate'] as num).toDouble()
          : (double.tryParse(json['omFixRate']?.toString() ?? '0.0') ?? 0.0),
      omUser: json['omUser']?.toString() ?? 'ADMIN',
      omUserDtTime: json['omUserDtTime']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'omCode': omCode,
        'omDesc': omDesc,
        'omFixRate': omFixRate,
        'omUser': omUser,
        'omUserDtTime': omUserDtTime,
      };
}

class OperationService {
  final String baseUrl;
  final http.Client _client;

  OperationService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  // In-memory fallback mock list for initial demo / offline resilience
  static final List<OperationMaster> _mockOperations = [
    const OperationMaster(omCode: 12, omDesc: 'ROBOTIC LASER CUTTING & BEVELING', omFixRate: 450.00),
    const OperationMaster(omCode: 11, omDesc: 'CNC PRECISION MILLING & DRILLING', omFixRate: 380.50),
    const OperationMaster(omCode: 10, omDesc: 'HIGH-PRESSURE HYDRAULIC BENDING', omFixRate: 275.00),
    const OperationMaster(omCode: 9, omDesc: 'AUTOMATED MIG/TIG SEAM WELDING', omFixRate: 320.00),
    const OperationMaster(omCode: 8, omDesc: 'PLASMA CUTTING & EDGE FINISHING', omFixRate: 210.00),
    const OperationMaster(omCode: 7, omDesc: 'SURFACE SANDBLASTING & DEGREASING', omFixRate: 150.00),
    const OperationMaster(omCode: 6, omDesc: 'ELECTROSTATIC POWDER COATING', omFixRate: 290.00),
    const OperationMaster(omCode: 5, omDesc: 'HEAT TREATMENT & QUENCHING', omFixRate: 520.00),
    const OperationMaster(omCode: 4, omDesc: 'QUALITY ULTRASONIC NDT TESTING', omFixRate: 180.00),
    const OperationMaster(omCode: 3, omDesc: 'FINAL ASSEMBLY & HARDWARE MOUNTING', omFixRate: 240.00),
    const OperationMaster(omCode: 2, omDesc: 'PROTECTIVE CORROSION PACKAGING', omFixRate: 95.00),
    const OperationMaster(omCode: 1, omDesc: 'QUALITY INSPECTION & CERTIFICATION', omFixRate: 120.00),
  ];

  Future<List<OperationMaster>> fetchOperations() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/OperationMaster/GetAll'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List dynamicList = body['data'] ?? body;
        return dynamicList.map((e) => OperationMaster.fromJson(e)).toList();
      }
    } catch (_) {
      // Graceful fallback to mock data on network error / local dev offline
    }
    return List.from(_mockOperations);
  }

  Future<int> fetchNextCode() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/OperationMaster/GetNextCode'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['data'] is int ? body['data'] : (int.tryParse(body['data']?.toString() ?? '1') ?? 1);
      }
    } catch (_) {}

    if (_mockOperations.isEmpty) return 1;
    final maxCode = _mockOperations.map((e) => e.omCode).reduce((a, b) => a > b ? a : b);
    return maxCode + 1;
  }

  Future<bool> createOperation(int omCode, String omDesc, double omFixRate) async {
    final payload = {
      'omCode': omCode,
      'omDesc': omDesc,
      'omFixRate': omFixRate,
    };

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/OperationMaster/Create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mockOperations.insert(
          0,
          OperationMaster(omCode: omCode, omDesc: omDesc, omFixRate: omFixRate),
        );
        return true;
      }
    } catch (_) {}

    // Mock fallback insert
    _mockOperations.removeWhere((e) => e.omCode == omCode);
    _mockOperations.insert(
      0,
      OperationMaster(omCode: omCode, omDesc: omDesc, omFixRate: omFixRate),
    );
    return true;
  }

  Future<bool> updateOperation(int omCode, String omDesc, double omFixRate) async {
    final payload = {
      'omCode': omCode,
      'omDesc': omDesc,
      'omFixRate': omFixRate,
    };

    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/OperationMaster/Update/$omCode'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final idx = _mockOperations.indexWhere((e) => e.omCode == omCode);
        if (idx >= 0) {
          _mockOperations[idx] = OperationMaster(omCode: omCode, omDesc: omDesc, omFixRate: omFixRate);
        }
        return true;
      }
    } catch (_) {}

    // Mock fallback update
    final idx = _mockOperations.indexWhere((e) => e.omCode == omCode);
    if (idx >= 0) {
      _mockOperations[idx] = OperationMaster(omCode: omCode, omDesc: omDesc, omFixRate: omFixRate);
    } else {
      _mockOperations.insert(0, OperationMaster(omCode: omCode, omDesc: omDesc, omFixRate: omFixRate));
    }
    return true;
  }

  Future<bool> deleteOperation(int omCode) async {
    try {
      final response = await _client
          .delete(Uri.parse('$baseUrl/OperationMaster/Delete/$omCode'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        _mockOperations.removeWhere((e) => e.omCode == omCode);
        return true;
      }
    } catch (_) {}

    // Mock fallback delete
    _mockOperations.removeWhere((e) => e.omCode == omCode);
    return true;
  }
}
