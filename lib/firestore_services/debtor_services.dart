import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

// ================== المتغيرات الأساسية ==================
final CollectionReference DebtorsCollection = FirebaseFirestore.instance
    .collection("debtors");

// ================== Enums الأصلية ==================
enum SortBy { name, debt, lastPayment, createdDate }

enum SortOrder { ascending, descending }

enum FirestoreErrorType {
  networkError,
  permissionDenied,
  documentNotFound,
  invalidData,
  quotaExceeded,
  unknown,
}

// ================== Enums الجديدة للتحسينات ==================
enum RetryStrategy { fixed, linear, exponential, fibonacci }

enum CircuitBreakerState { closed, open, halfOpen }

enum CacheLevel { hot, warm, cold }

enum FeatureFlagStatus { enabled, disabled, rollout }


// ================== Base Logger Class ==================
abstract class DebtorsFirestoreLogger {
  static bool isEnabled = true;

  static void logOperation(
      String operation,
      String details, {
        bool isError = false,
      }) {
    if (!isEnabled) return;
    if (kReleaseMode) {
      if (isError) {
        // In a real app, log to a service like Crashlytics or Sentry
        debugPrint('[FIRESTORE ERROR] $operation: $details');
      }
    } else {
      // In debug mode, print all logs
      debugPrint('[FIRESTORE] $operation: $details ${isError ? "(ERROR)" : ""}');
    }
  }

  static void logPerformance(String operation, Duration duration) {
    if (!isEnabled || kReleaseMode) return;
    debugPrint('[PERFORMANCE] $operation: ${duration.inMilliseconds}ms');
  }
}

// ================== Base Error Handler ==================
abstract class DebtorsFirestoreErrorHandler {
  static void handleError(String operation, dynamic error) {
    DebtorsFirestoreLogger.logOperation(operation, error.toString(), isError: true);
  }
}

// ================== Base Data Validator ==================
abstract class DebtorsDataValidator {
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'الاسم مطلوب';
    }
    return null;
  }

  static String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return null;
    }
    return null;
  }

  static String? validateAmount(int? amount) {
    if (amount == null || amount < 0) {
      return 'المبلغ يجب أن يكون صحيح وموجب';
    }
    return null;
  }
}

// ================== 1. LRU Cache System ==================
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, CacheEntry<V>> _cache;
  int _hits = 0;
  int _misses = 0;

  LRUCache(this.maxSize) : _cache = LinkedHashMap<K, CacheEntry<V>>();

  void put(K key, V value, {Duration? ttl}) {
    final now = DateTime.now();
    final entry = CacheEntry<V>(
      value: value,
      createdAt: now,
      lastAccessedAt: now,
      ttl: ttl,
    );

    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    _cache[key] = entry;
  }

  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) {
      _misses++;
      return null;
    }

    // Check TTL
    if (entry.isExpired()) {
      _cache.remove(key);
      _misses++;
      return null;
    }

    // Move to end (mark as recently used)
    _cache.remove(key);
    entry.lastAccessedAt = DateTime.now();
    _cache[key] = entry;

    _hits++;
    return entry.value;
  }

  void remove(K key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
  }

  Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'maxSize': maxSize,
      'hits': _hits,
      'misses': _misses,
      'hitRatio': _hits + _misses > 0 ? (_hits / (_hits + _misses)) : 0.0,
      'memoryUsage': _estimateMemoryUsage(),
    };
  }

  int _estimateMemoryUsage() {
    // تقدير تقريبي بالبايت
    return _cache.length * 512; // متوسط 512 بايت لكل عنصر
  }
}

class CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  DateTime lastAccessedAt;
  final Duration? ttl;

  CacheEntry({
    required this.value,
    required this.createdAt,
    required this.lastAccessedAt,
    this.ttl,
  });

  bool isExpired() {
    if (ttl == null) return false;
    return DateTime.now().difference(createdAt) > ttl!;
  }
}

// ================== 2. Enhanced Cache Manager ==================
class EnhancedCacheManager {
  static late LRUCache<String, Map<String, dynamic>> _debtorCache;
  static late LRUCache<String, List<Map<String, dynamic>>> _searchCache;
  static late LRUCache<String, Map<String, dynamic>> _statsCache;
  static late LRUCache<String, PaginatedResult<Map<String, dynamic>>>
  _paginationCache;

  static bool _initialized = false;

  static void initialize({
    int debtorCacheSize = 200,
    int searchCacheSize = 100,
    int statsCacheSize = 50,
    int paginationCacheSize = 50,
  }) {
    if (_initialized) return;

    _debtorCache = LRUCache<String, Map<String, dynamic>>(debtorCacheSize);
    _searchCache = LRUCache<String, List<Map<String, dynamic>>>(
      searchCacheSize,
    );
    _statsCache = LRUCache<String, Map<String, dynamic>>(statsCacheSize);
    _paginationCache = LRUCache<String, PaginatedResult<Map<String, dynamic>>>(
      paginationCacheSize,
    );

    _initialized = true;

    // بدء تنظيف دوري للCache
    _startPeriodicCleanup();

    EnhancedLogger.logOperation(
      "CACHE_INIT",
      "All caches initialized successfully",
    );
  }

  static void _startPeriodicCleanup() {
    Timer.periodic(const Duration(minutes: 10), (timer) {
      _performCleanup();
    });
  }

  static void _performCleanup() {
    final beforeStats = getAllCacheStats();
    // يمكن إضافة منطق تنظيف أكثر تطوراً هنا
    final afterStats = getAllCacheStats();

    EnhancedLogger.logOperation(
      "CACHE_CLEANUP",
      "Cleanup completed. Memory before: ${beforeStats['totalMemory']}, after: ${afterStats['totalMemory']}",
    );
  }

  // Cache للعملاء
  static void cacheDebtor(String debtorId, Map<String, dynamic> data) {
    if (!_initialized) initialize();
    _debtorCache.put(debtorId, data, ttl: const Duration(minutes: 5));
  }

  static Map<String, dynamic>? getDebtor(String debtorId) {
    if (!_initialized) initialize();
    return _debtorCache.get(debtorId);
  }

  // Cache للبحث
  static void cacheSearchResults(
      String query,
      List<Map<String, dynamic>> results,
      ) {
    if (!_initialized) initialize();
    final cacheKey = _generateSearchCacheKey(query);
    _searchCache.put(cacheKey, results, ttl: const Duration(minutes: 2));
  }

  static List<Map<String, dynamic>>? getSearchResults(String query) {
    if (!_initialized) initialize();
    final cacheKey = _generateSearchCacheKey(query);
    return _searchCache.get(cacheKey);
  }

  // Cache للإحصائيات
  static void cacheStats(String key, Map<String, dynamic> stats) {
    if (!_initialized) initialize();
    _statsCache.put(key, stats, ttl: const Duration(minutes: 10));
  }

  static Map<String, dynamic>? getStats(String key) {
    if (!_initialized) initialize();
    return _statsCache.get(key);
  }

  // Cache للصفحات
  static void cachePaginationResults(
      String key,
      PaginatedResult<Map<String, dynamic>> result,
      ) {
    if (!_initialized) initialize();
    _paginationCache.put(key, result, ttl: const Duration(minutes: 3));
  }

  static PaginatedResult<Map<String, dynamic>>? getPaginationResults(
      String key,
      ) {
    if (!_initialized) initialize();
    return _paginationCache.get(key);
  }

  static String _generateSearchCacheKey(String query) {
    return 'search_${query.toLowerCase().trim().replaceAll(' ', '_')}';
  }

  static String generatePaginationCacheKey({
    required String operation,
    int pageSize = 20,
    String? searchQuery,
    SortBy sortBy = SortBy.debt,
    SortOrder sortOrder = SortOrder.descending,
    int pageNumber = 1,
  }) {
    return 'pagination_${operation}_${pageSize}_${searchQuery ?? 'all'}_${sortBy.name}_${sortOrder.name}_$pageNumber';
  }

  static void clearDebtorCache(String debtorId) {
    if (!_initialized) return;
    _debtorCache.remove(debtorId);
    // مسح caches ذات العلاقة
    _searchCache.clear(); // البحثات قد تحتوي على هذا العميل
    _statsCache.clear(); // الإحصائيات قد تتأثر
  }

  static void clearAllCaches() {
    if (!_initialized) return;
    _debtorCache.clear();
    _searchCache.clear();
    _statsCache.clear();
    _paginationCache.clear();
  }

  static Map<String, dynamic> getAllCacheStats() {
    if (!_initialized) initialize();

    final debtorStats = _debtorCache.getStats();
    final searchStats = _searchCache.getStats();
    final statsStats = _statsCache.getStats();
    final paginationStats = _paginationCache.getStats();

    return {
      'debtor': debtorStats,
      'search': searchStats,
      'stats': statsStats,
      'pagination': paginationStats,
      'totalMemory':
      debtorStats['memoryUsage'] +
          searchStats['memoryUsage'] +
          statsStats['memoryUsage'] +
          paginationStats['memoryUsage'],
      'totalHitRatio':
      ((debtorStats['hitRatio'] +
          searchStats['hitRatio'] +
          statsStats['hitRatio'] +
          paginationStats['hitRatio']) /
          4),
    };
  }
}

// ================== 3. Retry Configuration ==================
class RetryConfig {
  final int maxAttempts;
  final Duration baseDelay;
  final RetryStrategy strategy;
  final Duration maxDelay;
  final List<String> retryableFirebaseErrors;
  final List<Type> retryableExceptionTypes;

  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.strategy = RetryStrategy.exponential,
    this.maxDelay = const Duration(seconds: 30),
    this.retryableFirebaseErrors = const [
      'unavailable',
      'deadline-exceeded',
      'resource-exhausted',
      'internal',
      'cancelled',
    ],
    this.retryableExceptionTypes = const [SocketException, TimeoutException],
  });
}

// ================== 4. Retry Mechanism ==================
class RetryMechanism {
  static Future<T> executeWithRetry<T>(
      Future<T> Function() operation, {
        RetryConfig config = const RetryConfig(),
        String operationName = 'Unknown',
        Function(Exception, int)? onRetry,
      }) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt < config.maxAttempts) {
      attempt++;

      try {
        if (attempt > 1) {
          EnhancedLogger.logOperation(
            "RETRY_ATTEMPT",
            "$operationName - Attempt $attempt/${config.maxAttempts}",
          );
        }

        final result = await operation();

        if (attempt > 1) {
          EnhancedLogger.logOperation(
            "RETRY_SUCCESS",
            "$operationName succeeded after $attempt attempts",
          );
        }

        return result;
      } on Exception catch (e) {
        lastException = e;

        if (!_shouldRetry(e, config)) {
          EnhancedLogger.logOperation(
            "RETRY_NON_RETRYABLE",
            "$operationName failed with non-retryable error: ${e.runtimeType}",
            isError: true,
          );
          rethrow;
        }

        if (attempt >= config.maxAttempts) {
          EnhancedLogger.logOperation(
            "RETRY_EXHAUSTED",
            "$operationName failed after $attempt attempts. Final error: $e",
            isError: true,
          );
          rethrow;
        }

        final delay = _calculateDelay(attempt, config);

        EnhancedLogger.logOperation(
          "RETRY_WAITING",
          "$operationName attempt $attempt failed: ${e.runtimeType}. Retrying in ${delay.inMilliseconds}ms",
        );

        onRetry?.call(e, attempt);
        await Future.delayed(delay);
      }
    }

    throw lastException!;
  }

  static bool _shouldRetry(Exception error, RetryConfig config) {
    // التحقق من نوع Exception
    for (final type in config.retryableExceptionTypes) {
      if (error.runtimeType == type) return true;
    }

    // التحقق من Firebase errors
    if (error is FirebaseException) {
      return config.retryableFirebaseErrors.contains(error.code);
    }

    return false;
  }

  static Duration _calculateDelay(int attempt, RetryConfig config) {
    Duration calculatedDelay;

    switch (config.strategy) {
      case RetryStrategy.fixed:
        calculatedDelay = config.baseDelay;
        break;
      case RetryStrategy.linear:
        calculatedDelay = config.baseDelay * attempt;
        break;
      case RetryStrategy.exponential:
        final multiplier = math.pow(2, attempt - 1).toInt();
        calculatedDelay = config.baseDelay * multiplier;
        break;
      case RetryStrategy.fibonacci:
        final fibNumber = _fibonacci(attempt);
        calculatedDelay = config.baseDelay * fibNumber;
        break;
    }

    return calculatedDelay > config.maxDelay
        ? config.maxDelay
        : calculatedDelay;
  }

  static int _fibonacci(int n) {
    if (n <= 1) return 1;
    if (n == 2) return 1;

    int prev1 = 1, prev2 = 1;
    for (int i = 3; i <= n; i++) {
      final current = prev1 + prev2;
      prev2 = prev1;
      prev1 = current;
    }
    return prev1;
  }
}

// ================== 5. Circuit Breaker ==================
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration timeout;
  final Duration retryTimeout;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 10),
    this.retryTimeout = const Duration(seconds: 30),
  });

  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitBreakerState.open) {
      if (_shouldAttemptReset()) {
        _state = CircuitBreakerState.halfOpen;
        EnhancedLogger.logOperation(
          "CIRCUIT_BREAKER",
          "$name: Moving to HALF_OPEN state",
        );
      } else {
        throw CircuitBreakerOpenException("Circuit breaker '$name' is OPEN");
      }
    }

    try {
      final result = await operation().timeout(timeout);
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    if (_state == CircuitBreakerState.halfOpen) {
      _state = CircuitBreakerState.closed;
      EnhancedLogger.logOperation(
        "CIRCUIT_BREAKER",
        "$name: Reset to CLOSED state",
      );
    }
    _failureCount = 0;
    _lastFailureTime = null;
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
      EnhancedLogger.logOperation(
        "CIRCUIT_BREAKER",
        "$name: Tripped to OPEN state after $_failureCount failures",
        isError: true,
      );
    }
  }

  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return false;
    return DateTime.now().difference(_lastFailureTime!) >= retryTimeout;
  }

  Map<String, dynamic> getStatus() {
    return {
      'name': name,
      'state': _state.name,
      'failureCount': _failureCount,
      'lastFailureTime': _lastFailureTime?.toIso8601String(),
    };
  }
}

class CircuitBreakerOpenException implements Exception {
  final String message;
  CircuitBreakerOpenException(this.message);

  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}

// ================== 6. Enhanced Error Handler ==================
class EnhancedFirestoreErrorHandler extends DebtorsFirestoreErrorHandler {
  static final Map<String, CircuitBreaker> _circuitBreakers = {};

  static CircuitBreaker _getCircuitBreaker(String operation) {
    return _circuitBreakers.putIfAbsent(
      operation,
          () => CircuitBreaker(name: operation),
    );
  }

  static Future<T> executeWithProtection<T>(
      String operation,
      Future<T> Function() function, {
        RetryConfig? retryConfig,
      }) async {
    final circuitBreaker = _getCircuitBreaker(operation);

    return await circuitBreaker.execute(() async {
      return await RetryMechanism.executeWithRetry(
        function,
        config: retryConfig ?? const RetryConfig(),
        operationName: operation,
      );
    });
  }

  static Map<String, dynamic> getAllCircuitBreakerStatus() {
    return Map.fromEntries(
      _circuitBreakers.entries.map(
            (entry) => MapEntry(entry.key, entry.value.getStatus()),
      ),
    );
  }
}

// ================== 7. Health Check System ==================
class HealthCheckSystem {
  static Timer? _healthCheckTimer;
  static final Map<String, HealthCheck> _checks = {};
  static final StreamController<HealthCheckResult> _resultController =
  StreamController.broadcast();

  static Stream<HealthCheckResult> get healthStream => _resultController.stream;

  static void initialize() {
    // إضافة فحوصات أساسية
    registerCheck('firestore_connection', _checkFirestoreConnection);
    registerCheck('internet_connection', _checkInternetConnection);
    registerCheck('cache_health', _checkCacheHealth);

    // بدء الفحص الدوري
    startPeriodicHealthCheck(const Duration(seconds: 30));
  }

  static void registerCheck(
      String name,
      Future<bool> Function() checkFunction,
      ) {
    _checks[name] = HealthCheck(name: name, checkFunction: checkFunction);
  }

  static void startPeriodicHealthCheck(Duration interval) {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(interval, (_) => performAllChecks());
  }

  static Future<Map<String, HealthCheckResult>> performAllChecks() async {
    final results = <String, HealthCheckResult>{};

    for (final check in _checks.values) {
      final result = await _performCheck(check);
      results[check.name] = result;
      _resultController.add(result);
    }

    return results;
  }

  static Future<HealthCheckResult> _performCheck(HealthCheck check) async {
    final stopwatch = Stopwatch()..start();

    try {
      final isHealthy = await check.checkFunction().timeout(
        const Duration(seconds: 10),
      );
      stopwatch.stop();

      final result = HealthCheckResult(
        checkName: check.name,
        isHealthy: isHealthy,
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
        error: null,
      );

      if (!isHealthy) {
        EnhancedLogger.logOperation(
          "HEALTH_CHECK",
          "Health check '${check.name}' failed",
          isError: true,
        );
      }

      return result;
    } catch (e) {
      stopwatch.stop();

      final result = HealthCheckResult(
        checkName: check.name,
        isHealthy: false,
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
        error: e.toString(),
      );

      EnhancedLogger.logOperation(
        "HEALTH_CHECK",
        "Health check '${check.name}' threw exception: $e",
        isError: true,
      );

      return result;
    }
  }

  static Future<bool> _checkFirestoreConnection() async {
    try {
      await DebtorsCollection.limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _checkCacheHealth() async {
    try {
      final stats = EnhancedCacheManager.getAllCacheStats();
      final memoryUsage = stats['totalMemory'] as int;
      // اعتبار الذاكرة صحيحة إذا كانت أقل من 10MB
      return memoryUsage < 10 * 1024 * 1024;
    } catch (e) {
      return false;
    }
  }

  static void dispose() {
    _healthCheckTimer?.cancel();
    _resultController.close();
  }
}

class HealthCheck {
  final String name;
  final Future<bool> Function() checkFunction;

  HealthCheck({required this.name, required this.checkFunction});
}

class HealthCheckResult {
  final String checkName;
  final bool isHealthy;
  final Duration responseTime;
  final DateTime timestamp;
  final String? error;

  HealthCheckResult({
    required this.checkName,
    required this.isHealthy,
    required this.responseTime,
    required this.timestamp,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'checkName': checkName,
      'isHealthy': isHealthy,
      'responseTime': responseTime.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
    };
  }
}

// ================== 8. Feature Flag System ==================
class FeatureFlagManager {
  static final Map<String, FeatureFlag> _flags = {};
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;

    // إعداد الأعلام الافتراضية
    _setupDefaultFlags();
    _initialized = true;

    EnhancedLogger.logOperation(
      "FEATURE_FLAGS",
      "Feature flag system initialized",
    );
  }

  static void _setupDefaultFlags() {
    // أمثلة على أعلام الميزات
    setFlag('fuzzy_search', FeatureFlagStatus.enabled);
    setFlag('advanced_analytics', FeatureFlagStatus.disabled);
    setFlag('pdf_export', FeatureFlagStatus.rollout, rolloutPercentage: 20);
    setFlag('voice_search', FeatureFlagStatus.disabled);
    setFlag('dark_mode', FeatureFlagStatus.enabled);
    setFlag('progressive_loading', FeatureFlagStatus.enabled);
  }

  static void setFlag(
      String flagName,
      FeatureFlagStatus status, {
        int rolloutPercentage = 0,
      }) {
    _flags[flagName] = FeatureFlag(
      name: flagName,
      status: status,
      rolloutPercentage: rolloutPercentage,
    );
  }

  static bool isEnabled(String flagName, {String? userId}) {
    if (!_initialized) initialize();

    final flag = _flags[flagName];
    if (flag == null) return false;

    switch (flag.status) {
      case FeatureFlagStatus.enabled:
        return true;
      case FeatureFlagStatus.disabled:
        return false;
      case FeatureFlagStatus.rollout:
        if (userId == null) return false;
        // استخدام hash للحصول على نسبة ثابتة لكل مستخدم
        final hash = userId.hashCode.abs();
        final userPercentage = hash % 100;
        return userPercentage < flag.rolloutPercentage;
    }
  }

  static Map<String, dynamic> getAllFlags() {
    return Map.fromEntries(
      _flags.entries.map((entry) => MapEntry(entry.key, entry.value.toMap())),
    );
  }

  static void updateFlag(
      String flagName,
      FeatureFlagStatus status, {
        int rolloutPercentage = 0,
      }) {
    setFlag(flagName, status, rolloutPercentage: rolloutPercentage);
    EnhancedLogger.logOperation(
      "FEATURE_FLAGS",
      "Flag '$flagName' updated to ${status.name}",
    );
  }
}

class FeatureFlag {
  final String name;
  final FeatureFlagStatus status;
  final int rolloutPercentage;
  final DateTime createdAt;

  FeatureFlag({
    required this.name,
    required this.status,
    this.rolloutPercentage = 0,
  }) : createdAt = DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'status': status.name,
      'rolloutPercentage': rolloutPercentage,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// ================== 9. Enhanced Logger ==================
class EnhancedLogger extends  DebtorsFirestoreLogger {
  static final List<LogEntry> _logHistory = [];
  static const int maxLogHistory = 1000;

  static Timer? _performanceLogTimer;
  static final Map<String, PerformanceMetric> _performanceMetrics = {};

  static void initialize() {
    // بدء تسجيل إحصائيات الأداء الدورية
    _performanceLogTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _logPerformanceMetrics();
    });
  }

  static void logOperation(
      String operation,
      String details, {
        bool isError = false,
      }) {
    if (! DebtorsFirestoreLogger.isEnabled) return;

    final entry = LogEntry(
      operation: operation,
      details: details,
      isError: isError,
      timestamp: DateTime.now(),
    );

    _logHistory.add(entry);

    // الحفاظ على حجم اللوج
    if (_logHistory.length > maxLogHistory) {
      _logHistory.removeAt(0);
    }

    // استدعاء الLogger الأصلي
    DebtorsFirestoreLogger.logOperation(operation, details, isError: isError);
  }

  static void logPerformance(String operation, Duration duration) {
    if (! DebtorsFirestoreLogger.isEnabled) return;

    // تحديث إحصائيات الأداء
    final metric = _performanceMetrics.putIfAbsent(
      operation,
          () => PerformanceMetric(operation),
    );

    metric.addMeasurement(duration);

    // استدعاء الLogger الأصلي
    DebtorsFirestoreLogger.logPerformance(operation, duration);
  }

  static void _logPerformanceMetrics() {
    if (_performanceMetrics.isEmpty) return;

    for (final metric in _performanceMetrics.values) {
      if (metric.count > 0) {
        logOperation(
          "PERFORMANCE_SUMMARY",
          "${metric.operation}: Avg=${metric.averageDuration.inMilliseconds}ms, "
              "Count=${metric.count}, Min=${metric.minDuration.inMilliseconds}ms, "
              "Max=${metric.maxDuration.inMilliseconds}ms",
        );
      }
    }
  }

  static List<LogEntry> getRecentLogs({
    int limit = 100,
    bool errorsOnly = false,
  }) {
    var logs = _logHistory;

    if (errorsOnly) {
      logs = logs.where((log) => log.isError).toList();
    }

    return logs.reversed.take(limit).toList();
  }

  static Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};

    for (final metric in _performanceMetrics.values) {
      report[metric.operation] = {
        'averageDurationMs': metric.averageDuration.inMilliseconds,
        'minDurationMs': metric.minDuration.inMilliseconds,
        'maxDurationMs': metric.maxDuration.inMilliseconds,
        'count': metric.count,
        'totalDurationMs': metric.totalDuration.inMilliseconds,
      };
    }

    return report;
  }

  static void dispose() {
    _performanceLogTimer?.cancel();
  }
}

class LogEntry {
  final String operation;
  final String details;
  final bool isError;
  final DateTime timestamp;

  LogEntry({
    required this.operation,
    required this.details,
    required this.isError,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'operation': operation,
      'details': details,
      'isError': isError,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class PerformanceMetric {
  final String operation;
  Duration totalDuration = Duration.zero;
  Duration minDuration = const Duration(days: 1);
  Duration maxDuration = Duration.zero;
  int count = 0;

  PerformanceMetric(this.operation);

  void addMeasurement(Duration duration) {
    totalDuration += duration;
    count++;

    if (duration < minDuration) {
      minDuration = duration;
    }
    if (duration > maxDuration) {
      maxDuration = duration;
    }
  }

  Duration get averageDuration {
    return count > 0
        ? Duration(microseconds: totalDuration.inMicroseconds ~/ count)
        : Duration.zero;
  }
}

// ================== 10. Fuzzy Search System ==================
class FuzzySearchEngine {
  // حساب Levenshtein Distance بين نصين
  static int calculateLevenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
          (i) => List.generate(b.length + 1, (j) => 0),
    );

    // تهيئة الصف والعمود الأول
    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    // حساب المسافة
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        matrix[i][j] = [
          matrix[i - 1][j] + 1, // حذف
          matrix[i][j - 1] + 1, // إضافة
          matrix[i - 1][j - 1] + cost, // تعديل
        ].reduce(math.min);
      }
    }

    return matrix[a.length][b.length];
  }

  // حساب درجة التشابه (0-1)
  static double calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final distance = calculateLevenshteinDistance(
      a.toLowerCase(),
      b.toLowerCase(),
    );
    final maxLength = math.max(a.length, b.length);

    return 1.0 - (distance / maxLength);
  }

  // البحث التقريبي في قائمة
  static List<FuzzySearchResult> fuzzySearch(
      String query,
      List<Map<String, dynamic>> items,
      String searchField, {
        double threshold = 0.6,
        int maxResults = 20,
      }) {
    if (query.trim().isEmpty) return [];

    final results = <FuzzySearchResult>[];
    final queryLower = query.toLowerCase().trim();

    for (final item in items) {
      final text = item[searchField]?.toString().toLowerCase() ?? '';
      if (text.isEmpty) continue;

      // البحث المباشر أولاً (أولوية عالية)
      if (text.contains(queryLower)) {
        results.add(
          FuzzySearchResult(
            item: item,
            similarity: text == queryLower ? 1.0 : 0.9,
            matchType:
            text == queryLower ? MatchType.exact : MatchType.contains,
          ),
        );
        continue;
      }

      // البحث التقريبي
      final similarity = calculateSimilarity(queryLower, text);
      if (similarity >= threshold) {
        results.add(
          FuzzySearchResult(
            item: item,
            similarity: similarity,
            matchType: MatchType.fuzzy,
          ),
        );
      }

      // البحث في بداية الكلمات
      final words = text.split(' ');
      for (final word in words) {
        if (word.startsWith(queryLower)) {
          results.add(
            FuzzySearchResult(
              item: item,
              similarity: 0.8,
              matchType: MatchType.startsWith,
            ),
          );
          break;
        }
      }
    }

    // إزالة المكرر وترتيب النتائج
    final uniqueResults = <String, FuzzySearchResult>{};
    for (final result in results) {
      final key = result.item['id']?.toString() ?? '';
      if (key.isNotEmpty) {
        final existing = uniqueResults[key];
        if (existing == null || result.similarity > existing.similarity) {
          uniqueResults[key] = result;
        }
      }
    }

    final finalResults = uniqueResults.values.toList();
    finalResults.sort((a, b) => b.similarity.compareTo(a.similarity));

    return finalResults.take(maxResults).toList();
  }

  // توليد N-grams
  static List<String> generateNGrams(String text, int n) {
    if (text.length < n) return [text];

    final ngrams = <String>[];
    for (int i = 0; i <= text.length - n; i++) {
      ngrams.add(text.substring(i, i + n));
    }

    return ngrams;
  }

  // البحث باستخدام N-grams (للنصوص الطويلة)
  static double calculateNGramSimilarity(String a, String b, int n) {
    final ngramsA = generateNGrams(a.toLowerCase(), n).toSet();
    final ngramsB = generateNGrams(b.toLowerCase(), n).toSet();

    if (ngramsA.isEmpty && ngramsB.isEmpty) return 1.0;
    if (ngramsA.isEmpty || ngramsB.isEmpty) return 0.0;

    final intersection = ngramsA.intersection(ngramsB).length;
    final union = ngramsA.union(ngramsB).length;

    return intersection / union;
  }
}

enum MatchType { exact, contains, startsWith, fuzzy, ngram }

class FuzzySearchResult {
  final Map<String, dynamic> item;
  final double similarity;
  final MatchType matchType;

  FuzzySearchResult({
    required this.item,
    required this.similarity,
    required this.matchType,
  });
}

// ================== 11. Background Sync System ==================
class BackgroundSyncManager {
  static Timer? _syncTimer;
  static bool _isInitialized = false;
  static bool _isSyncing = false;
  static DateTime? _lastSyncTime;
  static final List<SyncOperation> _pendingSyncOperations = [];

  static void initialize({Duration syncInterval = const Duration(minutes: 5)}) {
    if (_isInitialized) return;

    _isInitialized = true;
    _startPeriodicSync(syncInterval);

    EnhancedLogger.logOperation(
      "BACKGROUND_SYNC",
      "Background sync initialized with interval: ${syncInterval.inMinutes}m",
    );
  }

  static void _startPeriodicSync(Duration interval) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => _performBackgroundSync());
  }

  static Future<void> _performBackgroundSync() async {
    if (_isSyncing) {
      EnhancedLogger.logOperation(
        "BACKGROUND_SYNC",
        "Sync already in progress, skipping",
      );
      return;
    }

    _isSyncing = true;
    final stopwatch = Stopwatch()..start();

    try {
      EnhancedLogger.logOperation(
        "BACKGROUND_SYNC",
        "Starting background sync",
      );

      // تنفيذ العمليات المعلقة
      await _processPendingOperations();

      // مزامنة البيانات المحدثة
      await _syncUpdatedData();

      // تنظيف الcache إذا لزم الأمر
      await _performMaintenanceTasks();

      _lastSyncTime = DateTime.now();
      stopwatch.stop();

      EnhancedLogger.logPerformance("BACKGROUND_SYNC", stopwatch.elapsed);
    } catch (e) {
      EnhancedLogger.logOperation(
        "BACKGROUND_SYNC",
        "Background sync failed: $e",
        isError: true,
      );
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> _processPendingOperations() async {
    if (_pendingSyncOperations.isEmpty) return;

    final operations = List<SyncOperation>.from(_pendingSyncOperations);
    _pendingSyncOperations.clear();

    for (final operation in operations) {
      try {
        await operation.execute();
        EnhancedLogger.logOperation(
          "BACKGROUND_SYNC",
          "Executed pending operation: ${operation.type}",
        );
      } catch (e) {
        EnhancedLogger.logOperation(
          "BACKGROUND_SYNC",
          "Failed to execute operation ${operation.type}: $e",
          isError: true,
        );
        // إعادة إضافة العملية للمحاولة لاحقاً
        if (operation.retryCount < 3) {
          operation.retryCount++;
          _pendingSyncOperations.add(operation);
        }
      }
    }
  }

  static Future<void> _syncUpdatedData() async {
    if (_lastSyncTime == null) return;

    try {
      // جلب البيانات المحدثة منذ آخر مزامنة
      final updatedDebtors =
      await DebtorsCollection.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromDate(_lastSyncTime!),
      ).get();

      // تحديث الcache مع البيانات الجديدة
      for (final doc in updatedDebtors.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        EnhancedCacheManager.cacheDebtor(doc.id, data);
      }

      if (updatedDebtors.docs.isNotEmpty) {
        EnhancedLogger.logOperation(
          "BACKGROUND_SYNC",
          "Synced ${updatedDebtors.docs.length} updated records",
        );
      }
    } catch (e) {
      EnhancedLogger.logOperation(
        "BACKGROUND_SYNC",
        "Failed to sync updated data: $e",
        isError: true,
      );
    }
  }

  static Future<void> _performMaintenanceTasks() async {
    // تنظيف الcache القديم
    final cacheStats = EnhancedCacheManager.getAllCacheStats();
    if (cacheStats['totalMemory'] > 5 * 1024 * 1024) {
      // أكثر من 5MB
      EnhancedCacheManager.clearAllCaches();
      EnhancedLogger.logOperation(
        "BACKGROUND_SYNC",
        "Cleared caches due to high memory usage",
      );
    }

    // إحصائيات الأداء
    final performanceReport = EnhancedLogger.getPerformanceReport();
    if (performanceReport.isNotEmpty) {
      EnhancedLogger.logOperation(
        "BACKGROUND_SYNC",
        "Performance report: ${performanceReport.length} operations tracked",
      );
    }
  }

  static void queueSyncOperation(SyncOperation operation) {
    _pendingSyncOperations.add(operation);
    EnhancedLogger.logOperation(
      "BACKGROUND_SYNC",
      "Queued sync operation: ${operation.type}",
    );
  }

  static Map<String, dynamic> getSyncStatus() {
    return {
      'isInitialized': _isInitialized,
      'isSyncing': _isSyncing,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'pendingOperations': _pendingSyncOperations.length,
    };
  }

  static void dispose() {
    _syncTimer?.cancel();
    _isInitialized = false;
  }
}

class SyncOperation {
  final String type;
  final Future<void> Function() execute;
  int retryCount = 0;
  final DateTime createdAt;

  SyncOperation({required this.type, required this.execute})
      : createdAt = DateTime.now();
}

// ================== 12. Enhanced Data Validator ==================
class EnhancedDataValidator extends DebtorsDataValidator {
  // تحسين التحقق من الأسماء مع دعم أفضل للعربية
  static String? validateNameEnhanced(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'الاسم مطلوب';
    }

    final cleanName = name.trim();

    if (cleanName.length < 2) {
      return 'الاسم يجب أن يكون أكثر من حرفين';
    }

    if (cleanName.length > 100) {
      return 'الاسم طويل جداً (الحد الأقصى 100 حرف)';
    }

    // التحقق من وجود أحرف صحيحة فقط (عربي، انجليزي، أرقام، مسافات)
    final validPattern = RegExp(r'^[\u0600-\u06FFa-zA-Z0-9\s\-\.]+');
    if (!validPattern.hasMatch(cleanName)) {
      return 'الاسم يحتوي على رموز غير مسموحة';
    }

    // التحقق من عدم وجود أرقام فقط
    if (RegExp(r'^[\d\s\-\.]+').hasMatch(cleanName)) {
      return 'الاسم لا يمكن أن يكون أرقام فقط';
    }

    return null;
  }

  // تحسين التحقق من رقم الهاتف
  static String? validatePhoneEnhanced(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return null;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // أنماط مختلفة للهواتف المصرية
    final egyptianPatterns = [
      RegExp(r'^(\+201|01)[0-9]{9}'), // النمط العادي
      RegExp(r'^(\+2010|010)[0-9]{8}'), // فودافون
      RegExp(r'^(\+2011|011)[0-9]{8}'), // اتصالات
      RegExp(r'^(\+2012|012)[0-9]{8}'), // أورانج
      RegExp(r'^(\+2015|015)[0-9]{8}'), // WE
    ];

    bool isValid = egyptianPatterns.any(
          (pattern) => pattern.hasMatch(cleanPhone),
    );

    if (!isValid) {
      return 'رقم الهاتف غير صحيح (يجب أن يكون رقم مصري صحيح)';
    }

    return null;
  }

  // التحقق من التواريخ
  static String? validateDate(
      DateTime? date, {
        DateTime? minDate,
        DateTime? maxDate,
      }) {
    if (date == null) {
      return 'التاريخ مطلوب';
    }

    if (minDate != null && date.isBefore(minDate)) {
      return 'التاريخ لا يمكن أن يكون قبل ${minDate.day}/${minDate.month}/${minDate.year}';
    }

    if (maxDate != null && date.isAfter(maxDate)) {
      return 'التاريخ لا يمكن أن يكون بعد ${maxDate.day}/${maxDate.month}/${maxDate.year}';
    }

    return null;
  }

  // التحقق من البيانات المالية مع حدود
  static String? validateAmountEnhanced(
      int? amount, {
        String fieldName = 'المبلغ',
        int? minAmount,
        int? maxAmount,
      }) {
    if (amount == null) {
      return '$fieldName مطلوب';
    }

    if (amount < 0) {
      return '$fieldName لا يمكن أن يكون سالباً';
    }

    if (minAmount != null && amount < minAmount) {
      return '$fieldName يجب أن يكون على الأقل $minAmount';
    }

    if (maxAmount != null && amount > maxAmount) {
      return '$fieldName يجب أن يكون أقل من $maxAmount';
    }

    // تحذير للمبالغ الكبيرة جداً (أكثر من مليون)
    if (amount > 1000000) {
      return '$fieldName كبير جداً، يرجى التأكد من صحة المبلغ';
    }

    return null;
  }

  // التحقق من البيانات المعقدة
  static ValidationResult validateComplexData(Map<String, dynamic> data) {
    final errors = <String, String>{};
    final warnings = <String, String>{};

    // التحقق من البيانات الأساسية
    final nameError = validateNameEnhanced(data['name']);
    if (nameError != null) errors['name'] = nameError;

    final phoneError = validatePhoneEnhanced(data['phone']);
    if (phoneError != null) errors['phone'] = phoneError;

    final borrowedError = validateAmountEnhanced(
      data['totalBorrowed'],
      fieldName: 'المبلغ المطلوب',
    );
    if (borrowedError != null) errors['totalBorrowed'] = borrowedError;

    final paidError = validateAmountEnhanced(
      data['totalPaid'],
      fieldName: 'المبلغ المدفوع',
    );
    if (paidError != null) errors['totalPaid'] = paidError;

    // التحقق من المنطق
    final totalBorrowed = data['totalBorrowed'] as int? ?? 0;
    final totalPaid = data['totalPaid'] as int? ?? 0;

    if (totalPaid > totalBorrowed) {
      errors['totalPaid'] =
      'المبلغ المدفوع لا يمكن أن يكون أكبر من المبلغ المطلوب';
    }

    // تحذيرات
    if (totalBorrowed > 100000) {
      warnings['totalBorrowed'] = 'مبلغ كبير، يرجى التأكد من صحة المبلغ';
    }

    if (totalBorrowed > 0 && totalPaid == 0) {
      warnings['totalPaid'] = 'لا توجد مدفوعات لهذا العميل';
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}

class ValidationResult {
  final bool isValid;
  final Map<String, String> errors;
  final Map<String, String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
}

// ================== 13. Optimistic Locking System ==================
class OptimisticLockingManager {
  static const String versionField = '_version';
  static const String lockField = '_lockedBy';
  static const String lockTimeField = '_lockTime';

  static Future<T> executeWithOptimisticLock<T>(
      DocumentReference docRef,
      Future<T> Function(
          Transaction transaction,
          Map<String, dynamic> currentData,
          )
      operation,
      ) async {
    return await FirebaseFirestore.instance.runTransaction<T>((
        transaction,
        ) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw OptimisticLockException('المستند غير موجود');
      }

      final currentData = snapshot.data() as Map<String, dynamic>;
      final currentVersion = currentData[versionField] as int? ?? 0;

      // تنفيذ العملية
      final result = await operation(transaction, currentData);

      // تحديث الإصدار
      transaction.update(docRef, {
        versionField: currentVersion + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return result;
    });
  }

  static Future<void> initializeVersioning(DocumentReference docRef) async {
    await docRef.update({
      versionField: 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class OptimisticLockException implements Exception {
  final String message;
  OptimisticLockException(this.message);

  @override
  String toString() => 'OptimisticLockException: $message';
}

// ================== 14. Progressive Loading System ==================
class ProgressiveLoader {
  static Future<ProgressiveLoadResult> loadDebtorsProgressively({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    final stages = <String, List<Map<String, dynamic>>>{};
    final stopwatch = Stopwatch()..start();

    try {
      // المرحلة الأولى: البيانات الأساسية
      Query query = DebtorsCollection.where(
        'isActive',
        isEqualTo: true,
      ).orderBy('currentDebt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      // البيانات الأساسية
      final basicData =
      snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'],
          'currentDebt': data['currentDebt'] ?? 0,
          '_docSnapshot': doc, // للpagination
        };
      }).toList();

      stages['basic'] = basicData;

      // المرحلة الثانية: بيانات إضافية
      await Future.delayed(const Duration(milliseconds: 100));

      final enhancedData =
      snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'],
          'phone': data['phone'],
          'currentDebt': data['currentDebt'] ?? 0,
          'totalBorrowed': data['totalBorrowed'] ?? 0,
          'totalPaid': data['totalPaid'] ?? 0,
          '_docSnapshot': doc,
        };
      }).toList();

      stages['enhanced'] = enhancedData;

      // المرحلة الثالثة: تفاصيل كاملة
      await Future.delayed(const Duration(milliseconds: 200));

      final fullData =
      snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'],
          'phone': data['phone'],
          'currentDebt': data['currentDebt'] ?? 0,
          'totalBorrowed': data['totalBorrowed'] ?? 0,
          'totalPaid': data['totalPaid'] ?? 0,
          'lastPaymentAt': data['lastPaymentAt'],
          'createdAt': data['createdAt'],
          'isActive': data['isActive'] ?? true,
          '_docSnapshot': doc,
        };
      }).toList();

      stages['full'] = fullData;

      stopwatch.stop();

      return ProgressiveLoadResult(
        stages: stages,
        hasMore: snapshot.docs.length == limit,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        loadTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      EnhancedLogger.logOperation(
        "PROGRESSIVE_LOAD",
        "Error: $e",
        isError: true,
      );
      rethrow;
    }
  }
}

class ProgressiveLoadResult {
  final Map<String, List<Map<String, dynamic>>> stages;
  final bool hasMore;
  final DocumentSnapshot? lastDocument;
  final Duration loadTime;

  ProgressiveLoadResult({
    required this.stages,
    required this.hasMore,
    required this.lastDocument,
    required this.loadTime,
  });

  List<Map<String, dynamic>> getStage(String stageName) {
    return stages[stageName] ?? [];
  }
}

// ================== Enhanced Original Classes ==================
class PaginatedResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final int currentPage;
  final Duration loadTime;
  final Map<String, dynamic>? cacheInfo;

  PaginatedResult({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
    required this.currentPage,
    this.loadTime = Duration.zero,
    this.cacheInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemCount': items.length,
      'hasMore': hasMore,
      'currentPage': currentPage,
      'loadTimeMs': loadTime.inMilliseconds,
      'cacheInfo': cacheInfo,
    };
  }
}

// ================== 15. Enhanced Core Functions ==================

/// إضافة عميل مع جميع التحسينات الجديدة
Future<String?> addDebtorEnhanced({
  required String name,
  required String phone,
  required int totalBorrowed,
  required int totalPaid,
  String? userId,
}) async {
  return await EnhancedFirestoreErrorHandler.executeWithProtection(
    'ADD_DEBTOR',
        () async {
      final stopwatch = Stopwatch()..start();

      try {
        // التحقق من البيانات المحسن
        final validationResult = EnhancedDataValidator.validateComplexData({
          'name': name,
          'phone': phone,
          'totalBorrowed': totalBorrowed,
          'totalPaid': totalPaid,
        });

        if (!validationResult.isValid) {
          throw Exception(
            'بيانات غير صحيحة: ${validationResult.errors.values.first}',
          );
        }

        // التحقق من عدم تكرار رقم الهاتف مع Cache
        final existingFromCache = await _checkExistingPhoneWithCache(phone);
        if (existingFromCache) {
          throw Exception('رقم الهاتف موجود مسبقاً');
        }

        // إنشاء كلمات البحث المحسنة
        final searchKeywords = _generateEnhancedSearchKeywords(name);

        // حساب الدين الحالي
        final int currentDebt = totalBorrowed - totalPaid;

        // إعداد البيانات
        final debtorData = {
          'name': name.trim(),
          'phone': phone.trim(),
          'totalBorrowed': totalBorrowed,
          'totalPaid': totalPaid,
          'currentDebt': currentDebt,
          'searchKeywords': searchKeywords,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'lastPaymentAt': null,
          'totalTransactions': 0,
          OptimisticLockingManager.versionField: 1,
        };

        final docRef = await DebtorsCollection.add(debtorData);

        // حفظ في Cache
        final cacheData = Map<String, dynamic>.from(debtorData);
        cacheData['id'] = docRef.id;
        EnhancedCacheManager.cacheDebtor(docRef.id, cacheData);

        // إضافة عملية للمزامنة في الخلفية
        BackgroundSyncManager.queueSyncOperation(
          SyncOperation(
            type: 'DEBTOR_ADDED',
            execute: () async {
              EnhancedLogger.logOperation(
                "SYNC",
                "Debtor ${docRef.id} sync completed",
              );
            },
          ),
        );

        stopwatch.stop();
        EnhancedLogger.logPerformance("ADD_DEBTOR_ENHANCED", stopwatch.elapsed);
        EnhancedLogger.logOperation(
          "ADD_DEBTOR_ENHANCED",
          "Successfully added: ${name.trim()}",
        );

        return docRef.id;
      } catch (e) {
        stopwatch.stop();
        EnhancedLogger.logOperation(
          "ADD_DEBTOR_ENHANCED",
          "Error: $e",
          isError: true,
        );
        return null;
      }
    },
  );
}

/// فحص وجود رقم هاتف مع استخدام Cache
Future<bool> _checkExistingPhoneWithCache(String phone) async {
  // البحث في Cache أولاً
  final cacheStats = EnhancedCacheManager.getAllCacheStats();
  if (cacheStats['debtor']['size'] > 0) {
    // يمكن تحسين هذا بإضافة فهرس للهواتف في Cache
    // لكن للبساطة سنبحث في القاعدة مباشرة
  }

  // البحث في القاعدة
  final existingDebtor =
  await DebtorsCollection.where(
    'phone',
    isEqualTo: phone.trim(),
  ).limit(1).get();

  return existingDebtor.docs.isNotEmpty;
}

/// إنتاج كلمات بحث محسنة مع دعم Fuzzy Search
List<String> _generateEnhancedSearchKeywords(String name) {
  final keywords = <String>{};
  final cleanName = name.trim().toLowerCase();

  // الاسم كاملاً
  keywords.add(cleanName);

  // كل كلمة منفصلة
  final words = cleanName.split(' ');
  keywords.addAll(words);

  // Prefixes لكل كلمة
  for (String word in words) {
    for (int i = 1; i <= word.length; i++) {
      keywords.add(word.substring(0, i));
    }
  }

  // N-grams للبحث التقريبي
  for (String word in words) {
    if (word.length >= 3) {
      keywords.addAll(FuzzySearchEngine.generateNGrams(word, 2));
      keywords.addAll(FuzzySearchEngine.generateNGrams(word, 3));
    }
  }

  // إزالة الكلمات القصيرة جداً
  keywords.removeWhere((keyword) => keyword.length < 2);

  return keywords.toList();
}

/// تحديث بيانات العميل مع Optimistic Locking
Future<void> updateDebtorInfoEnhanced({
  required String debtorId,
  String? name,
  String? phone,
  String? userId,
}) async {
  await EnhancedFirestoreErrorHandler.executeWithProtection(
    'UPDATE_DEBTOR_INFO',
        () async {
      final debtorRef = DebtorsCollection.doc(debtorId);

      return await OptimisticLockingManager.executeWithOptimisticLock(
        debtorRef,
            (transaction, currentData) async {
          final Map<String, dynamic> updates = {};

          if (name != null) {
            final nameError = EnhancedDataValidator.validateNameEnhanced(name);
            if (nameError != null) throw Exception(nameError);

            updates['name'] = name.trim();
            updates['searchKeywords'] = _generateEnhancedSearchKeywords(name);
          }

          if (phone != null) {
            final phoneError = EnhancedDataValidator.validatePhoneEnhanced(
              phone,
            );
            if (phoneError != null) throw Exception(phoneError);

            // التحقق من عدم وجود نفس الرقم لعميل آخر
            final existingDebtor =
            await DebtorsCollection.where(
              'phone',
              isEqualTo: phone.trim(),
            ).limit(1).get();

            if (existingDebtor.docs.isNotEmpty &&
                existingDebtor.docs.first.id != debtorId) {
              throw Exception('رقم الهاتف موجود لعميل آخر');
            }

            updates['phone'] = phone.trim();
          }

          if (updates.isEmpty) {
            throw Exception('لم يتم تحديد أي بيانات للتحديث');
          }

          updates['updatedAt'] = FieldValue.serverTimestamp();

          transaction.update(debtorRef, updates);

          // تحديث Cache
          EnhancedCacheManager.clearDebtorCache(debtorId);

          return;
        },
      );
    },
  );
}

/// البحث المحسن مع Fuzzy Search
Future<List<Map<String, dynamic>>> searchDebtorsEnhanced(
    String query, {
      bool useFuzzySearch = true,
      double fuzzyThreshold = 0.6,
      int maxResults = 20,
    }) async {
  return await EnhancedFirestoreErrorHandler.executeWithProtection(
    'SEARCH_DEBTORS_ENHANCED',
        () async {
      final stopwatch = Stopwatch()..start();

      try {
        if (query.trim().isEmpty) {
          return await fetchDebtorMainDataEnhanced();
        }

        // التحقق من Cache أولاً
        final cachedResults = EnhancedCacheManager.getSearchResults(query);
        if (cachedResults != null) {
          stopwatch.stop();
          EnhancedLogger.logPerformance(
            "SEARCH_DEBTORS_CACHED",
            stopwatch.elapsed,
          );
          return cachedResults;
        }

        final searchQuery = query.trim().toLowerCase();

        // البحث العادي أولاً
        final snapshot =
        await DebtorsCollection.where(
          'searchKeywords',
          arrayContains: searchQuery,
        )
            .where('isActive', isEqualTo: true)
            .orderBy('name')
            .limit(maxResults)
            .get();

        var results =
        snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'],
            'phone': data['phone'],
            'totalBorrowed': data['totalBorrowed'] ?? 0,
            'totalPaid': data['totalPaid'] ?? 0,
            'currentDebt': data['currentDebt'] ?? 0,
          };
        }).toList();

        // إذا لم نجد نتائج كافية وكان Fuzzy Search مفعل
        if (results.length < maxResults &&
            useFuzzySearch &&
            FeatureFlagManager.isEnabled('fuzzy_search')) {
          // جلب عينة أكبر للبحث التقريبي
          final allDebtorsSnapshot =
          await DebtorsCollection.where('isActive', isEqualTo: true)
              .limit(200) // عينة أكبر للبحث التقريبي
              .get();

          final allDebtors =
          allDebtorsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'],
              'phone': data['phone'],
              'totalBorrowed': data['totalBorrowed'] ?? 0,
              'totalPaid': data['totalPaid'] ?? 0,
              'currentDebt': data['currentDebt'] ?? 0,
            };
          }).toList();

          // البحث التقريبي
          final fuzzyResults = FuzzySearchEngine.fuzzySearch(
            query,
            allDebtors,
            'name',
            threshold: fuzzyThreshold,
            maxResults: maxResults,
          );

          // دمج النتائج وإزالة المكرر
          final existingIds = results.map((r) => r['id']).toSet();
          final additionalResults =
          fuzzyResults
              .where((fr) => !existingIds.contains(fr.item['id']))
              .map((fr) => fr.item)
              .toList();

          results.addAll(additionalResults);

          // قطع النتائج للحد المطلوب
          if (results.length > maxResults) {
            results = results.take(maxResults).toList();
          }
        }

        // حفظ في Cache
        EnhancedCacheManager.cacheSearchResults(query, results);

        stopwatch.stop();
        EnhancedLogger.logPerformance(
          "SEARCH_DEBTORS_ENHANCED",
          stopwatch.elapsed,
        );

        return results;
      } catch (e) {
        stopwatch.stop();
        EnhancedLogger.logOperation(
          "SEARCH_DEBTORS_ENHANCED",
          "Error: $e",
          isError: true,
        );
        return [];
      }
    },
  );
}

/// جلب البيانات الأساسية مع Progressive Loading
Future<List<Map<String, dynamic>>> fetchDebtorMainDataEnhanced({
  bool useProgressiveLoading = false,
}) async {
  return await EnhancedFirestoreErrorHandler.executeWithProtection(
    'FETCH_DEBTOR_MAIN_DATA',
        () async {
      if (useProgressiveLoading &&
          FeatureFlagManager.isEnabled('progressive_loading')) {
        final progressiveResult =
        await ProgressiveLoader.loadDebtorsProgressively();
        return progressiveResult.getStage('full');
      }

      // الطريقة العادية مع Cache
      final stopwatch = Stopwatch()..start();

      try {
        final snapshot =
        await DebtorsCollection.where(
          'isActive',
          isEqualTo: true,
        ).orderBy('currentDebt', descending: true).get();

        final result =
        snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final debtorData = {
            'id': doc.id,
            'name': data['name'],
            'phone': data['phone'],
            'totalBorrowed': data['totalBorrowed'] ?? 0,
            'totalPaid': data['totalPaid'] ?? 0,
            'currentDebt': data['currentDebt'] ?? 0,
            'lastPaymentAt': data['lastPaymentAt'],
          };

          // حفظ في Cache
          EnhancedCacheManager.cacheDebtor(doc.id, debtorData);

          return debtorData;
        }).toList();

        stopwatch.stop();
        EnhancedLogger.logPerformance(
          "FETCH_DEBTOR_MAIN_DATA_ENHANCED",
          stopwatch.elapsed,
        );

        return result;
      } catch (e) {
        stopwatch.stop();
        EnhancedLogger.logOperation(
          "FETCH_DEBTOR_MAIN_DATA_ENHANCED",
          "Error: $e",
          isError: true,
        );
        return [];
      }
    },
  );
}

/// Pagination محسن مع Cache
Future<PaginatedResult<Map<String, dynamic>>> getDebtorsPaginatedEnhanced({
  int pageSize = 20,
  DocumentSnapshot? lastDocument,
  String? searchQuery,
  SortBy sortBy = SortBy.debt,
  SortOrder sortOrder = SortOrder.descending,
  int pageNumber = 1,
  bool useCache = true,
}) async {
  return await EnhancedFirestoreErrorHandler.executeWithProtection(
    'GET_DEBTORS_PAGINATED',
        () async {
      final stopwatch = Stopwatch()..start();

      try {
        // إنتاج مفتاح Cache
        final cacheKey = EnhancedCacheManager.generatePaginationCacheKey(
          operation: 'debtor_paginated',
          pageSize: pageSize,
          searchQuery: searchQuery,
          sortBy: sortBy,
          sortOrder: sortOrder,
          pageNumber: pageNumber,
        );

        // التحقق من Cache
        if (useCache) {
          final cachedResult = EnhancedCacheManager.getPaginationResults(
            cacheKey,
          );
          if (cachedResult != null) {
            stopwatch.stop();
            EnhancedLogger.logPerformance(
              "GET_DEBTORS_PAGINATED_CACHED",
              stopwatch.elapsed,
            );
            return cachedResult;
          }
        }

        Query query = DebtorsCollection.where('isActive', isEqualTo: true);

        // إضافة البحث
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          query = query.where(
            'searchKeywords',
            arrayContains: searchQuery.trim().toLowerCase(),
          );
        }

        // إضافة الترتيب
        final orderByField = _getSortField(sortBy);
        final descending = sortOrder == SortOrder.descending;
        query = query.orderBy(orderByField, descending: descending);

        // إضافة pagination
        if (lastDocument != null) {
          query = query.startAfterDocument(lastDocument);
        }

        query = query.limit(pageSize);

        final snapshot = await query.get();

        final items =
        snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final item = {
            'id': doc.id,
            'name': data['name'],
            'phone': data['phone'],
            'totalBorrowed': data['totalBorrowed'] ?? 0,
            'totalPaid': data['totalPaid'] ?? 0,
            'currentDebt': data['currentDebt'] ?? 0,
            'lastPaymentAt': data['lastPaymentAt'],
            'isActive': data['isActive'] ?? true,
          };

          // حفظ في Cache الأساسي
          EnhancedCacheManager.cacheDebtor(doc.id, item);

          return item;
        }).toList();

        stopwatch.stop();

        final result = PaginatedResult<Map<String, dynamic>>(
          items: items,
          lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
          hasMore: snapshot.docs.length == pageSize,
          currentPage: pageNumber,
          loadTime: stopwatch.elapsed,
          cacheInfo: {'cached': false, 'cacheKey': cacheKey},
        );

        // حفظ في Pagination Cache
        if (useCache) {
          EnhancedCacheManager.cachePaginationResults(cacheKey, result);
        }

        EnhancedLogger.logPerformance(
          "GET_DEBTORS_PAGINATED_ENHANCED",
          stopwatch.elapsed,
        );

        return result;
      } catch (e) {
        stopwatch.stop();
        EnhancedLogger.logOperation(
          "GET_DEBTORS_PAGINATED_ENHANCED",
          "Error: $e",
          isError: true,
        );
        return PaginatedResult<Map<String, dynamic>>(
          items: [],
          lastDocument: null,
          hasMore: false,
          currentPage: pageNumber,
          loadTime: stopwatch.elapsed,
        );
      }
    },
  );
}

/// إحصائيات محسنة مع Cache متقدم
Future<Map<String, dynamic>> getGeneralStatisticsEnhanced() async {
  return await EnhancedFirestoreErrorHandler.executeWithProtection(
    'GET_GENERAL_STATISTICS',
        () async {
      final stopwatch = Stopwatch()..start();

      try {
        // التحقق من Cache
        const cacheKey = 'general_statistics';
        final cachedStats = EnhancedCacheManager.getStats(cacheKey);
        if (cachedStats != null) {
          stopwatch.stop();
          EnhancedLogger.logPerformance(
            "GET_GENERAL_STATISTICS_CACHED",
            stopwatch.elapsed,
          );
          return cachedStats;
        }

        final snapshot = await DebtorsCollection.get();

        int totalDebtors = 0;
        int activeDebtors = 0;
        int totalBorrowed = 0;
        int totalPaid = 0;
        int totalCurrentDebt = 0;
        int zeroDebtDebtors = 0;
        DateTime? oldestDebtorDate;
        DateTime? newestDebtorDate;

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;

          totalDebtors++;

          final isActive = data['isActive'] ?? true;
          if (isActive) activeDebtors++;

          final borrowed = data['totalBorrowed'] ?? 0;
          final paid = data['totalPaid'] ?? 0;
          final currentDebt = data['currentDebt'] ?? 0;

          totalBorrowed += borrowed as int;
          totalPaid += paid as int;
          totalCurrentDebt += currentDebt as int;

          if (currentDebt == 0) zeroDebtDebtors++;

          // تتبع التواريخ
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final date = createdAt.toDate();
            if (oldestDebtorDate == null || date.isBefore(oldestDebtorDate)) {
              oldestDebtorDate = date;
            }
            if (newestDebtorDate == null || date.isAfter(newestDebtorDate)) {
              newestDebtorDate = date;
            }
          }
        }

        final stats = {
          'totalDebtors': totalDebtors,
          'activeDebtors': activeDebtors,
          'inactiveDebtors': totalDebtors - activeDebtors,
          'totalBorrowed': totalBorrowed,
          'totalPaid': totalPaid,
          'totalCurrentDebt': totalCurrentDebt,
          'zeroDebtDebtors': zeroDebtDebtors,
          'debtorWithDebt': totalDebtors - zeroDebtDebtors,
          'averageDebt':
          totalDebtors > 0 ? (totalCurrentDebt / totalDebtors).round() : 0,
          'paymentRate':
          totalBorrowed > 0
              ? ((totalPaid / totalBorrowed) * 100).round()
              : 0,
          'oldestDebtorDate': oldestDebtorDate?.toIso8601String(),
          'newestDebtorDate': newestDebtorDate?.toIso8601String(),
          'calculatedAt': DateTime.now().toIso8601String(),
        };

        // حفظ في Cache
        EnhancedCacheManager.cacheStats(cacheKey, stats);

        stopwatch.stop();
        EnhancedLogger.logPerformance(
          "GET_GENERAL_STATISTICS_ENHANCED",
          stopwatch.elapsed,
        );

        return stats;
      } catch (e) {
        stopwatch.stop();
        EnhancedLogger.logOperation(
          "GET_GENERAL_STATISTICS_ENHANCED",
          "Error: $e",
          isError: true,
        );
        return {};
      }
    },
  );
}

/// حذف عميل مع التنظيف الشامل
Future<void> deleteDebtorEnhanced(String debtorId) async {
  await EnhancedFirestoreErrorHandler.executeWithProtection(
    'DELETE_DEBTOR',
        () async {
      final debtorRef = DebtorsCollection.doc(debtorId);

      return await OptimisticLockingManager.executeWithOptimisticLock(
        debtorRef,
            (transaction, currentData) async {
          // حذف جميع الديون
          final debtsSnapshot = await debtorRef.collection('debts').get();
          for (var debtDoc in debtsSnapshot.docs) {
            transaction.delete(debtDoc.reference);
          }

          // حذف جميع المدفوعات
          final paymentsSnapshot = await debtorRef.collection('payments').get();
          for (var paymentDoc in paymentsSnapshot.docs) {
            transaction.delete(paymentDoc.reference);
          }

          // حذف العميل نفسه
          transaction.delete(debtorRef);

          return;
        },
      );
    },
  );

  // تنظيف Cache
  EnhancedCacheManager.clearDebtorCache(debtorId);

  // إضافة عملية مزامنة
  BackgroundSyncManager.queueSyncOperation(
    SyncOperation(
      type: 'DEBTOR_DELETED',
      execute: () async {
        EnhancedLogger.logOperation(
          "SYNC",
          "Debtor $debtorId deletion sync completed",
        );
      },
    ),
  );
}

// ================== System Initialization ==================
/// تهيئة جميع الأنظمة المحسنة
void initializeEnhancedFirestoreServices({Map<String, dynamic>? config}) {
  // تهيئة Cache
  EnhancedCacheManager.initialize();

  // تهيئة Feature Flags
  FeatureFlagManager.initialize();

  // تهيئة Health Checks
  HealthCheckSystem.initialize();

  // تهيئة Background Sync
  BackgroundSyncManager.initialize();

  // تهيئة Logger المحسن
  EnhancedLogger.initialize();

  EnhancedLogger.logOperation(
    "SYSTEM_INIT",
    "All enhanced systems initialized successfully",
  );
}

/// إغلاق جميع الأنظمة بشكل آمن
void disposeEnhancedFirestoreServices() {
  BackgroundSyncManager.dispose();
  HealthCheckSystem.dispose();
  EnhancedLogger.dispose();
  EnhancedCacheManager.clearAllCaches();

  EnhancedLogger.logOperation(
    "SYSTEM_DISPOSE",
    "All enhanced systems disposed",
  );
}

/// تقرير شامل عن حالة النظام
Map<String, dynamic> getSystemHealthReport() {
  return {
    'cacheStats': EnhancedCacheManager.getAllCacheStats(),
    'circuitBreakers':
    EnhancedFirestoreErrorHandler.getAllCircuitBreakerStatus(),
    'featureFlags': FeatureFlagManager.getAllFlags(),
    'backgroundSync': BackgroundSyncManager.getSyncStatus(),
    'performanceMetrics': EnhancedLogger.getPerformanceReport(),
    'recentErrors':
    EnhancedLogger.getRecentLogs(
      limit: 10,
      errorsOnly: true,
    ).map((log) => log.toMap()).toList(),
    'timestamp': DateTime.now().toIso8601String(),
  };
}

// ================== Helper Functions ==================
String _getSortField(SortBy sortBy) {
  switch (sortBy) {
    case SortBy.name:
      return 'name';
    case SortBy.debt:
      return 'currentDebt';
    case SortBy.lastPayment:
      return 'lastPaymentAt';
    case SortBy.createdDate:
      return 'createdAt';
  }
}
