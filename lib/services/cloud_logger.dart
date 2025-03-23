import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';

class CloudLogger {
  static final CloudLogger _instance = CloudLogger._internal();
  late FirebaseFunctions _functions;
  bool _isInitialized = false;
  String? _userId;
  
  // Singleton pattern
  factory CloudLogger() {
    return _instance;
  }
  
  CloudLogger._internal();
  
  /// Initialize the logger
  /// Returns a Future that completes when initialization is done
  static Future<CloudLogger> init() async {
    final instance = CloudLogger();
    if (!instance._isInitialized) {
      try {
        instance._functions = FirebaseFunctions.instance;
        instance._isInitialized = true;
      } catch (e) {
        print('Failed to initialize CloudLogger: $e');
      }
    }
    return instance;
  }
  
  /// Set current user ID for logging
  void setUserId(String userId) {
    _userId = userId;
  }
  
  /// Clear current user ID
  void clearUserId() {
    _userId = null;
  }
  
  /// Log an event to GCP Cloud Logging
  Future<void> _logEvent(
    String severity,
    String message,
    Map<String, dynamic> metadata
  ) async {
    if (!_isInitialized) {
      // Handle case where logger is not initialized yet
      print('Warning: Logger not initialized. Initializing now...');
      try {
        _functions = FirebaseFunctions.instance;
        _isInitialized = true;
      } catch (e) {
        print('Failed to initialize CloudLogger: $e');
        print('LOG [$severity]: $message - ${jsonEncode(metadata)}');
        return;
      }
    }
    
    try {
      // Add user ID if available
      final Map<String, dynamic> fullMetadata = {...metadata};
      if (_userId != null) {
        fullMetadata['userId'] = _userId;
      }
      
      // Add timestamp
      fullMetadata['clientTimestamp'] = DateTime.now().toIso8601String();
      
      // Call cloud function to write log
      await _functions.httpsCallable('writeCloudLog').call({
        'severity': severity,
        'message': message,
        'metadata': fullMetadata,
      });
    } catch (e) {
      // Fallback to console logging if cloud logging fails
      print('Cloud logging failed: $e');
      print('LOG [$severity]: $message - ${jsonEncode(metadata)}');
    }
  }
  
  /// Log an info message
  Future<void> info(String message, [Map<String, dynamic> metadata = const {}]) async {
    await _logEvent('INFO', message, metadata);
  }
  
  /// Log a warning message
  Future<void> warn(String message, [Map<String, dynamic> metadata = const {}]) async {
    await _logEvent('WARNING', message, metadata);
  }
  
  /// Log an error message
  Future<void> error(String message, [Map<String, dynamic> metadata = const {}]) async {
    await _logEvent('ERROR', message, metadata);
  }
  
  /// Log a debug message
  Future<void> debug(String message, [Map<String, dynamic> metadata = const {}]) async {
    await _logEvent('DEBUG', message, metadata);
  }
  
  /// Log a page view
  Future<void> pageView(String pageName, [Map<String, dynamic> metadata = const {}]) async {
    final pageMetadata = {
      'eventType': 'PAGE_VIEW',
      'pageName': pageName,
      ...metadata
    };
    await _logEvent('INFO', 'Page viewed: $pageName', pageMetadata);
  }
  
  /// Log a user action
  Future<void> userAction(String action, [Map<String, dynamic> metadata = const {}]) async {
    final actionMetadata = {
      'eventType': 'USER_ACTION',
      'action': action,
      ...metadata
    };
    await _logEvent('INFO', 'User action: $action', actionMetadata);
  }
  
  /// Log an API call
  Future<void> apiCall(String endpoint, bool success, int statusCode, int durationMs, [Map<String, dynamic> metadata = const {}]) async {
    final apiMetadata = {
      'eventType': 'API_CALL',
      'endpoint': endpoint,
      'success': success,
      'statusCode': statusCode,
      'durationMs': durationMs,
      ...metadata
    };
    await _logEvent(success ? 'INFO' : 'ERROR', 'API call to $endpoint', apiMetadata);
  }
}

//note logging happens in cloud Google 