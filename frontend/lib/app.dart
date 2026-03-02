import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_bloc.dart';

class ShopWebApp extends StatelessWidget {
  const ShopWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>()..add(const CheckAuthEvent()),
      child: MaterialApp.router(
        title: 'ShopWeb',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
