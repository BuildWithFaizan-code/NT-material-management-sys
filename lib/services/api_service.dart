import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class MetricsDto {
  final int activeStocks;
  final double avgLeadTime;
  final double procurementTotal;
  final double optimizationScore;

  MetricsDto({
    required this.activeStocks,
    required this.avgLeadTime,
    required this.procurementTotal,
    required this.optimizationScore,
  });

  factory MetricsDto.fromJson(Map<String, dynamic> json) {
    return MetricsDto(
      activeStocks: json['activeStocks'] as int? ?? 0,
      avgLeadTime: (json['avgLeadTime'] as num?)?.toDouble() ?? 0.0,
      procurementTotal: (json['procurementTotal'] as num?)?.toDouble() ?? 0.0,
      optimizationScore:
          (json['optimizationScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class VelocityDataPoint {
  final String month;
  final int value;

  VelocityDataPoint({required this.month, required this.value});

  factory VelocityDataPoint.fromJson(Map<String, dynamic> json) {
    return VelocityDataPoint(
      month: json['month'] as String? ?? '',
      value: json['value'] as int? ?? 0,
    );
  }

  double get normalized => value / 210.0;
}

class AlertItem {
  final String id;
  final String itemName;
  final double currentStock;
  final double safetyThreshold;
  final String department;
  String priority;

  AlertItem({
    required this.id,
    required this.itemName,
    required this.currentStock,
    required this.safetyThreshold,
    required this.department,
    required this.priority,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0.0,
      safetyThreshold:
          (json['safetyThreshold'] as num?)?.toDouble() ?? 0.0,
      department: json['department'] as String? ?? '',
      priority: json['priority'] as String? ?? 'Low',
    );
  }

  bool get isHigh => priority == 'High';
  bool get isWarning => currentStock < safetyThreshold * 0.1;
}

class TransactionRecord {
  final String transactionId;
  final String materialDetail;
  final String department;
  final String quantity;
  final double value;
  final String status;

  TransactionRecord({
    required this.transactionId,
    required this.materialDetail,
    required this.department,
    required this.quantity,
    required this.value,
    required this.status,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      transactionId: json['transactionId'] as String? ?? '',
      materialDetail: json['materialDetail'] as String? ?? '',
      department: json['department'] as String? ?? '',
      quantity: json['quantity'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
    );
  }

  String get valueFormatted {
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    }
    return '₹${value.toStringAsFixed(0)}';
  }

  bool get isReceived => status == 'RECEIVED';
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({required this.success, required this.message, this.data});
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

class ApiService {
  final String baseUrl;
  final http.Client _client;
  static const _timeout = ApiConfig.defaultTimeout;

  ApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<MetricsDto> fetchMetrics() async {
    final response = await _get('/metrics');
    final body = _decode(response);
    final data = body['data'];
    if (data == null) throw ApiException('Invalid metrics response');
    return MetricsDto.fromJson(data as Map<String, dynamic>);
  }

  Future<List<VelocityDataPoint>> fetchVelocity(
      {String metricType = 'Material Velocity'}) async {
    final response = await _get('/velocity', queryParams: {
      'metricType': metricType,
    });
    final body = _decode(response);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => VelocityDataPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AlertItem>> fetchAlerts() async {
    final response = await _get('/alerts');
    final body = _decode(response);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AlertItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransactionRecord>> fetchTransactions() async {
    final response = await _get('/transactions');
    final body = _decode(response);
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => TransactionRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> updateAlertPriority(String id, String priority) async {
    final uri = Uri.parse('$baseUrl/alerts/$id/priority');
    final response = await _client
        .patch(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'priority': priority}))
        .timeout(_timeout);
    return response.statusCode == 200;
  }

  Future<bool> deleteAlert(String id) async {
    final uri = Uri.parse('$baseUrl/alerts/$id');
    final response = await _client.delete(uri).timeout(_timeout);
    return response.statusCode == 200;
  }

  Future<http.Response> _get(String path,
      {Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    try {
      final response = await _client.get(uri).timeout(_timeout);
      return response;
    } on http.ClientException {
      throw ApiException(
          'Connection failed — server may be offline. Tap Retry.');
    } catch (_) {
      throw ApiException(
          'Connection failed — server may be offline. Tap Retry.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Request failed',
          statusCode: response.statusCode);
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Invalid JSON response');
    }
  }

  void dispose() {
    _client.close();
  }
}
