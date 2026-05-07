import 'package:get_it/get_it.dart';
import '../services/storage_service.dart';
import '../services/biometric_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Servicios Core
  sl.registerLazySingleton<StorageService>(() => StorageService());
  sl.registerLazySingleton<BiometricService>(() => BiometricService());
}
