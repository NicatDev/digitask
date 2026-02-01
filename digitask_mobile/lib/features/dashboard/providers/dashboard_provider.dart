import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _apiService;

  DashboardProvider(this._apiService);

  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.dio.get('/dashboard/events/', queryParameters: {
        'active_only': 'true',
      });
      
      if (response.data is List) {
        _events = (response.data as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      } else if (response.data is Map && response.data['results'] is List) {
        _events = (response.data['results'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      debugPrint('Fetched ${_events.length} events');
    } catch (e) {
      debugPrint('Error fetching events: $e');
      _error = 'Tədbirləri yükləmək mümkün olmadı';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createEvent({
    required String title,
    required String description,
    required String eventType,
    required DateTime date,
  }) async {
    final response = await _apiService.dio.post('/dashboard/events/', data: {
      'title': title,
      'description': description,
      'event_type': eventType,
      'date': date.toIso8601String().split('T')[0],
      'is_active': true,
    });
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      await fetchEvents();
    } else {
      throw Exception('Failed to create event');
    }
  }
}
