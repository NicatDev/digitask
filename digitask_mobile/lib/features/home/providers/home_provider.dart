import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import 'package:dio/dio.dart';

class HomeProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> get tasks => _tasks;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  HomeProvider(this._apiService);

  Future<void> fetchTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('Fetching tasks from: ${AppConstants.tasksEndpoint}');
      final response = await _apiService.dio.get(AppConstants.tasksEndpoint);
      debugPrint('Tasks response type: ${response.data.runtimeType}');
      debugPrint('Tasks response: ${response.data}');
      
      List<dynamic>? taskList;
      
      if (response.data is List) {
        taskList = response.data as List<dynamic>;
      } else if (response.data is Map<String, dynamic>) {
        final mapData = response.data as Map<String, dynamic>;
        if (mapData['results'] is List) {
          taskList = mapData['results'] as List<dynamic>;
        }
      }
      
      if (taskList != null) {
        _tasks = taskList
            .whereType<Map<String, dynamic>>()
            .toList();
        debugPrint('Parsed ${_tasks.length} tasks');
      } else {
        _tasks = [];
        debugPrint('No tasks found in response');
      }
    } on DioException catch (e) {
      debugPrint('DioException fetching tasks: ${e.type} - ${e.message}');
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        _error = responseData['detail']?.toString() ?? 'Tapşırıqları yükləmək mümkün olmadı';
      } else if (responseData is String) {
        _error = responseData;
      } else {
        _error = 'Tapşırıqları yükləmək mümkün olmadı';
      }
    } catch (e) {
      debugPrint('Unexpected error fetching tasks: $e');
      _error = 'Gözlənilməz xəta: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearTasks() {
    _tasks = [];
    notifyListeners();
  }
}

