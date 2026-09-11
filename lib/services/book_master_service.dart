import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Category item model (from CATEGORYMST)
class CategoryItem {
  final int catCode;
  final String catName;

  CategoryItem({
    required this.catCode,
    required this.catName,
  });

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      catCode: (json['catCode'] ?? json['CAT_CODE'] ?? 0) as int,
      catName: (json['catName'] ?? json['CAT_NAME'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'catCode': catCode,
        'catName': catName,
      };
}

/// Summary Book Master Item (from BOOKMST list)
class BookMasterSummaryItem {
  final int bookCode;
  final String bookName;

  BookMasterSummaryItem({
    required this.bookCode,
    required this.bookName,
  });

  factory BookMasterSummaryItem.fromJson(Map<String, dynamic> json) {
    return BookMasterSummaryItem(
      bookCode: (json['bookCode'] ?? json['BOOK_CODE'] ?? 0) as int,
      bookName: (json['bookName'] ?? json['BOOK_NAME'] ?? '') as String,
    );
  }
}

/// Full Detailed Book Master Item with Categories and Series Config
class BookDetailItem {
  final int bookCode;
  final String bookName;
  final String grn;
  final String issue;
  final String jobIssue;
  final String jobReceipt;
  final List<CategoryItem> categories;

  BookDetailItem({
    required this.bookCode,
    required this.bookName,
    required this.grn,
    required this.issue,
    required this.jobIssue,
    required this.jobReceipt,
    required this.categories,
  });

  factory BookDetailItem.fromJson(Map<String, dynamic> json) {
    var rawCats = json['categories'] as List<dynamic>? ?? [];
    List<CategoryItem> catList = rawCats
        .map((c) => CategoryItem.fromJson(c as Map<String, dynamic>))
        .toList();

    return BookDetailItem(
      bookCode: (json['bookCode'] ?? json['BOOK_CODE'] ?? 0) as int,
      bookName: (json['bookName'] ?? json['BOOK_NAME'] ?? '') as String,
      grn: (json['grn'] ?? json['GRN'] ?? '') as String,
      issue: (json['issue'] ?? json['ISSUE'] ?? '') as String,
      jobIssue: (json['jobIssue'] ?? json['JOB_ISSUE'] ?? '') as String,
      jobReceipt: (json['jobReceipt'] ?? json['JOB_RECEIPT'] ?? '') as String,
      categories: catList,
    );
  }

  BookDetailItem copyWith({
    int? bookCode,
    String? bookName,
    String? grn,
    String? issue,
    String? jobIssue,
    String? jobReceipt,
    List<CategoryItem>? categories,
  }) {
    return BookDetailItem(
      bookCode: bookCode ?? this.bookCode,
      bookName: bookName ?? this.bookName,
      grn: grn ?? this.grn,
      issue: issue ?? this.issue,
      jobIssue: jobIssue ?? this.jobIssue,
      jobReceipt: jobReceipt ?? this.jobReceipt,
      categories: categories ?? this.categories,
    );
  }
}

/// DTO for Save Operations
class BookSaveDto {
  final int bookCode;
  final String bookName;
  final String grn;
  final String issue;
  final String jobIssue;
  final String jobReceipt;
  final List<int> selectedCatCodes;

  BookSaveDto({
    required this.bookCode,
    required this.bookName,
    required this.grn,
    required this.issue,
    required this.jobIssue,
    required this.jobReceipt,
    required this.selectedCatCodes,
  });

  Map<String, dynamic> toJson() => {
        'bookCode': bookCode,
        'bookName': bookName,
        'grn': grn,
        'issue': issue,
        'jobIssue': jobIssue,
        'jobReceipt': jobReceipt,
        'selectedCatCodes': selectedCatCodes,
      };
}

/// Singleton Flutter Service for Book Master operations
class BookMasterService {
  BookMasterService._internal();
  static final BookMasterService _instance = BookMasterService._internal();
  factory BookMasterService() => _instance;

  String get _baseUrl => '${ApiConfig.baseUrl}/BookMaster';
  static const Duration _timeout = Duration(seconds: 10);

  /// Get all distinct books summary
  Future<List<BookMasterSummaryItem>> getAllBooks() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/GetAllBooks'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List<dynamic> list = body['data'];
          return list.map((item) => BookMasterSummaryItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get all books with full details for export and grid preview
  Future<List<BookDetailItem>> getAllBooksWithDetails() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/GetAllBooksWithDetails'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List<dynamic> list = body['data'];
          return list.map((item) => BookDetailItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get book details including assigned categories
  Future<BookDetailItem?> getBookDetails(int bookCode) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/GetBookDetails/$bookCode'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return BookDetailItem.fromJson(body['data']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get available categories not assigned to this book
  Future<List<CategoryItem>> getAvailableCategories(int bookCode) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/GetAvailableCategories/$bookCode'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final List<dynamic> list = body['data'];
          return list.map((item) => CategoryItem.fromJson(item)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get next auto-incremented BookCode
  Future<int> getNextBookCode() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/GetNextBookCode'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return (body['data'] as num).toInt();
        }
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }

  /// Save or Update Book master record + category allocations
  Future<bool> saveBook(BookSaveDto dto) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/SaveBook'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(dto.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Delete Book master record and category allocations
  Future<bool> deleteBook(int bookCode) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/DeleteBook/$bookCode'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
