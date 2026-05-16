import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tour_model.dart';
import '../../data/repositories/tour_repository.dart';

final propertyTourProvider =
    FutureProvider.family<PropertyTourModel, String>((ref, propertyId) {
  return ref.watch(tourRepositoryProvider).fetchPropertyTour(propertyId);
});
