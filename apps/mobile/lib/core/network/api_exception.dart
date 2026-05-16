import 'package:dio/dio.dart';

String messageFromDioError(Object error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 401) {
      return 'Oturum süresi doldu veya geçersiz. Lütfen tekrar giriş yapın.';
    }
    if (code == 403) {
      return 'Bu işlem için yetkiniz yok.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Sunucuya bağlanılamadı. API çalışıyor mu? USB ile adb reverse ayarlı mı?';
    }
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      if (msg is List) return msg.join(', ');
      return msg.toString();
    }
    return error.message ?? 'Ağ hatası (${code ?? '?'})';
  }
  return error.toString();
}
