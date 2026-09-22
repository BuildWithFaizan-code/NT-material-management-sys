import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

class Department {
  final int labCode;
  final String labName;

  const Department({
    required this.labCode,
    required this.labName,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      labCode: json['labCode'] is int
          ? json['labCode']
          : (int.tryParse(json['labCode']?.toString() ?? '0') ?? 0),
      labName: json['labName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'labCode': labCode,
        'labName': labName,
      };
}

class OperatorMaster {
  final int operCode;
  final String operName;
  final int operDepCd;
  final String labName;

  const OperatorMaster({
    required this.operCode,
    required this.operName,
    required this.operDepCd,
    this.labName = '',
  });

  factory OperatorMaster.fromJson(Map<String, dynamic> json) {
    return OperatorMaster(
      operCode: json['operCode'] is int
          ? json['operCode']
          : (int.tryParse(json['operCode']?.toString() ?? '0') ?? 0),
      operName: json['operName']?.toString() ?? '',
      operDepCd: json['operDepCd'] is int
          ? json['operDepCd']
          : (int.tryParse(json['operDepCd']?.toString() ?? '0') ?? 0),
      labName: json['labName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'operCode': operCode,
        'operName': operName,
        'operDepCd': operDepCd,
        'labName': labName,
      };

  OperatorMaster copyWith({
    int? operCode,
    String? operName,
    int? operDepCd,
    String? labName,
  }) {
    return OperatorMaster(
      operCode: operCode ?? this.operCode,
      operName: operName ?? this.operName,
      operDepCd: operDepCd ?? this.operDepCd,
      labName: labName ?? this.labName,
    );
  }
}

class OperatorService {
  final String baseUrl;
  final ApiClient _client;

  // In-memory mock fallback dataset for seamless offline operation
  final List<Department> _mockDepartments = [
    const Department(labCode: 1, labName: 'PRODUCTION & ASSEMBLY'),
    const Department(labCode: 2, labName: 'QUALITY ASSURANCE'),
    const Department(labCode: 3, labName: 'MAINTENANCE & TOOLING'),
    const Department(labCode: 4, labName: 'WAREHOUSE & LOGISTICS'),
    const Department(labCode: 5, labName: 'CNC MACHINING DEPT'),
  ];

  final List<OperatorMaster> _mockOperators = [
    const OperatorMaster(operCode: 1, operName: 'TANMAY SHARMA', operDepCd: 1, labName: 'PRODUCTION & ASSEMBLY'),
    const OperatorMaster(operCode: 2, operName: 'RAJESH KUMAR', operDepCd: 2, labName: 'QUALITY ASSURANCE'),
    const OperatorMaster(operCode: 3, operName: 'AMIT PATEL', operDepCd: 3, labName: 'MAINTENANCE & TOOLING'),
    const OperatorMaster(operCode: 4, operName: 'VIKRAM SINGH', operDepCd: 1, labName: 'PRODUCTION & ASSEMBLY'),
    const OperatorMaster(operCode: 5, operName: 'SANDEEP VERMA', operDepCd: 4, labName: 'WAREHOUSE & LOGISTICS'),
  ];

  OperatorService({
    String? baseUrl,
    ApiClient? client,
  })  : baseUrl = baseUrl ?? '${ApiConfig.baseUrl}/OperatorMaster',
        _client = client ?? ApiClient.instance;

  /// GET /api/OperatorMaster/GetDepartments
  /// Fetches departments from LABOURMST table
  Future<List<Department>> fetchDepartments() async {
    try {
      final response = await _client.get('$baseUrl/GetDepartments');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => Department.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return List.from(_mockDepartments);
    } catch (_) {
      return List.from(_mockDepartments);
    }
  }

  /// GET /api/OperatorMaster/GetAll
  /// Fetches all Operator Master records joined with LABOURMST department names
  Future<List<OperatorMaster>> fetchOperators() async {
    try {
      final response = await _client.get('$baseUrl/GetAll');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data
            .map((e) => OperatorMaster.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return List.from(_mockOperators);
    } catch (_) {
      return List.from(_mockOperators);
    }
  }

  /// GET /api/OperatorMaster/GetNextCode
  /// Fetches auto-incremented next OPER_CODE from OPERATORMST table
  Future<int> fetchNextCode() async {
    try {
      final response = await _client.get('$baseUrl/GetNextCode');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final nextCode = body['data'];
        if (nextCode is int) return nextCode;
        if (nextCode != null) return int.tryParse(nextCode.toString()) ?? 1;
      }
      return _getMockNextCode();
    } catch (_) {
      return _getMockNextCode();
    }
  }

  int _getMockNextCode() {
    if (_mockOperators.isEmpty) return 1;
    final maxCode = _mockOperators
        .map((e) => e.operCode)
        .reduce((curr, next) => curr > next ? curr : next);
    return maxCode + 1;
  }

  /// POST /api/OperatorMaster/Create
  /// Inserts a new Operator Master record into OPERATORMST table
  Future<bool> createOperator(int code, String name, int depCd) async {
    try {
      final response = await _client.post(
        '$baseUrl/Create',
        body: {
          'operCode': code,
          'operName': name.trim().toUpperCase(),
          'operDepCd': depCd,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (_) {
      // Fallback mock insertion
      final dep = _mockDepartments.firstWhere(
        (d) => d.labCode == depCd,
        orElse: () => Department(labCode: depCd, labName: 'DEPT #$depCd'),
      );
      _mockOperators.add(OperatorMaster(
        operCode: code,
        operName: name.trim().toUpperCase(),
        operDepCd: depCd,
        labName: dep.labName,
      ));
      return true;
    }
    return false;
  }

  /// PUT /api/OperatorMaster/Update/{code}
  /// Updates an existing Operator Master record in OPERATORMST table
  Future<bool> updateOperator(int code, String name, int depCd) async {
    try {
      final response = await _client.put(
        '$baseUrl/Update/$code',
        body: {
          'operCode': code,
          'operName': name.trim().toUpperCase(),
          'operDepCd': depCd,
        },
      );

      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {
      // Fallback mock update
      final idx = _mockOperators.indexWhere((o) => o.operCode == code);
      if (idx != -1) {
        final dep = _mockDepartments.firstWhere(
          (d) => d.labCode == depCd,
          orElse: () => Department(labCode: depCd, labName: 'DEPT #$depCd'),
        );
        _mockOperators[idx] = OperatorMaster(
          operCode: code,
          operName: name.trim().toUpperCase(),
          operDepCd: depCd,
          labName: dep.labName,
        );
        return true;
      }
    }
    return false;
  }

  /// DELETE /api/OperatorMaster/Delete/{code}
  /// Deletes an Operator Master record by OPER_CODE from OPERATORMST table
  Future<bool> deleteOperator(int code) async {
    try {
      final response = await _client.delete('$baseUrl/Delete/$code');
      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {
      _mockOperators.removeWhere((o) => o.operCode == code);
      return true;
    }
    return false;
  }

  void dispose() {}
}
