import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:frontend/common/providers/auth_provider.dart';
import 'package:frontend/common/providers/product_provider.dart';
import 'package:frontend/common/providers/cart_provider.dart';

class ShopWebApp extends StatelessWidget {
  const ShopWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProductProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CartProvider(),
        ),
        BlocProvider(
          create: (_) => sl<AuthBloc>()..add(const CheckAuthEvent()),
        ),
      ],
      child: MaterialApp.router(
        title: 'ShopWeb',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}

