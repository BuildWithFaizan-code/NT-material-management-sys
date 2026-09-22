import 'dart:convert';
import '../config/api_config.dart';
import 'api_client.dart';

class GradeItem {
  final int gradeSrl;
  String gradeCode;

  GradeItem({
    required this.gradeSrl,
    required this.gradeCode,
  });

  factory GradeItem.fromJson(Map<String, dynamic> json) {
    return GradeItem(
      gradeSrl: (json['gradeSrl'] ?? json['pgrd_Srl'] ?? json['pgrd_srl'] as num?)?.toInt() ?? 0,
      gradeCode: (json['gradeCode'] ?? json['pgrd_Code'] ?? json['pgrd_code'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gradeSrl': gradeSrl,
      'gradeCode': gradeCode,
    };
  }
}

class GradeMasterService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/GradeMaster';

  // Persistent in-memory fallback store for offline dev resilience
  static final List<GradeItem> _inMemoryItems = [
    GradeItem(gradeSrl: 1, gradeCode: 'A GRADE (SUPREME)'),
    GradeItem(gradeSrl: 2, gradeCode: 'B GRADE (REGULAR)'),
    GradeItem(gradeSrl: 3, gradeCode: 'C GRADE (ECONOMY)'),
    GradeItem(gradeSrl: 4, gradeCode: '1ST QUALITY EXPORT'),
    GradeItem(gradeSrl: 5, gradeCode: '569'),
  ];

  Future<List<GradeItem>> getGrades() async {
    try {
      final response = await ApiClient.instance.get('$_baseUrl/GetAll');

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List list = body['data'];
          final apiList = list.map((i) => GradeItem.fromJson(i)).toList();
          _inMemoryItems.clear();
          _inMemoryItems.addAll(apiList);
          return List.from(_inMemoryItems);
        }
      }
    } catch (_) {}

    return List.from(_inMemoryItems);
  }

  Future<int> getNextGradeSrl() async {
    try {
      final response = await ApiClient.instance.get('$_baseUrl/GetNextSrl');

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as num).toInt();
        }
      }
    } catch (_) {}

    return _inMemoryItems.isNotEmpty
        ? _inMemoryItems.map((m) => m.gradeSrl).reduce((a, b) => a > b ? a : b) + 1
        : 1;
  }

  Future<bool> insertGrade(GradeItem item) async {
    try {
      final response = await ApiClient.instance.post(
        '$_baseUrl/Insert',
        body: item.toJson(),
      );

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    _inMemoryItems.removeWhere((m) => m.gradeSrl == item.gradeSrl);
    _inMemoryItems.add(item);
    return true;
  }

  Future<bool> updateGrade(GradeItem item) async {
    try {
      final response = await ApiClient.instance.put(
        '$_baseUrl/Update',
        body: item.toJson(),
      );

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    final idx = _inMemoryItems.indexWhere((m) => m.gradeSrl == item.gradeSrl);
    if (idx != -1) {
      _inMemoryItems[idx] = item;
    } else {
      _inMemoryItems.add(item);
    }
    return true;
  }

  Future<bool> deleteGrade(int gradeSrl) async {
    try {
      final response = await ApiClient.instance.delete('$_baseUrl/Delete/$gradeSrl');

      if (response.statusCode == 200) {
        json.decode(response.body);
      }
    } catch (_) {}

    _inMemoryItems.removeWhere((m) => m.gradeSrl == gradeSrl);
    return true;
  }
}
