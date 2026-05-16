import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../models/tour_model.dart';

final tourRepositoryProvider = Provider<TourRepository>((ref) {
  return TourRepository(ref.watch(apiClientProvider));
});

class TourRepository {
  TourRepository(this._dio);

  final Dio _dio;

  Future<PropertyTourModel> fetchPropertyTour(String propertyId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/properties/$propertyId/tour',
    );
    return PropertyTourModel.fromJson(response.data!);
  }
}
