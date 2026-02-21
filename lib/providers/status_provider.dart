import 'package:dreamvision/services/enquiry_service.dart';

/// Model for Enquiry Status
class StatusModel {
  final int id;
  final String name;

  StatusModel({
    required this.id,
    required this.name,
  });

  factory StatusModel.fromJson(Map<String, dynamic> json) {
    return StatusModel(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatusModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

/// Singleton service to manage statuses
class StatusProvider {
  static final StatusProvider _instance = StatusProvider._internal();
  factory StatusProvider() => _instance;

  final _enquiryService = EnquiryService();
  List<StatusModel>? _cachedStatuses;
  DateTime? _lastFetch;

  StatusProvider._internal();

  /// Get all statuses from API (cached for 1 hour)
  Future<List<StatusModel>> getStatuses() async {
    // Check if cache is still valid (less than 1 hour old)
    if (_cachedStatuses != null && _lastFetch != null) {
      final now = DateTime.now();
      if (now.difference(_lastFetch!).inHours < 1) {
        return _cachedStatuses!;
      }
    }

    // Fetch from API
    try {
      final response = await _enquiryService.getStatusesList();
      _cachedStatuses = (response)
          .map((item) => StatusModel.fromJson(item))
          .toList()
          .cast<StatusModel>();
      _lastFetch = DateTime.now();
      return _cachedStatuses ?? [];
    } catch (e) {
      // Return cached if fetch fails
      return _cachedStatuses ?? _getDefaultStatuses();
    }
  }

  /// Get status names only
  Future<List<String>> getStatusNames() async {
    final statuses = await getStatuses();
    return statuses.map((s) => s.name).toList();
  }

  /// Check if a status is final (Confirmed or Closed)
  bool isFinalStatus(String? statusName) {
    if (statusName == null || statusName.isEmpty) return false;
    return statusName.toLowerCase() == 'confirmed' || 
           statusName.toLowerCase() == 'closed';
  }

  /// Get status by name
  StatusModel? getStatusByName(String? statusName, List<StatusModel>? statuses) {
    if (statusName == null || statusName.isEmpty || statuses == null) {
      return null;
    }

    try {
      return statuses.firstWhere(
        (status) => status.name.toLowerCase() == statusName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Default statuses (fallback if API fails)
  List<StatusModel> _getDefaultStatuses() {
    return [
      StatusModel(id: 2, name: 'Interested'),
      StatusModel(id: 1, name: 'Confirmed'),
      StatusModel(id: 3, name: 'Follow-Up'),
      StatusModel(id: 4, name: 'Closed'),
    ];
  }

  /// Clear cache
  void clearCache() {
    _cachedStatuses = null;
    _lastFetch = null;
  }
}
