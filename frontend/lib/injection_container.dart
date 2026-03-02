import 'package:get_it/get_it.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/network/dio_client.dart';

// Auth
import 'package:frontend/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_bloc.dart';

// Product
import 'package:frontend/features/product/data/datasources/product_remote_datasource.dart';
import 'package:frontend/features/product/data/repositories/product_repository_impl.dart';
import 'package:frontend/features/product/domain/repositories/product_repository.dart';
import 'package:frontend/features/product/presentation/bloc/product_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ─── Core ───
  const storage = FlutterSecureStorage();
  sl.registerLazySingleton<FlutterSecureStorage>(() => storage);
  sl.registerLazySingleton<DioClient>(() => DioClient(sl()));

  // ─── Auth ───
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(dioClient: sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), storage: sl()),
  );
  sl.registerFactory<AuthBloc>(() => AuthBloc(authRepository: sl()));

  // ─── Product ───
  sl.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSource(dioClient: sl()),
  );
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerFactory<ProductBloc>(() => ProductBloc(productRepository: sl()));
}
