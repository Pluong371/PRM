import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/presentation/pages/login_page.dart';
import 'package:frontend/features/auth/presentation/pages/register_page.dart';
import 'package:frontend/features/product/presentation/pages/home_page.dart';
import 'package:frontend/features/product/presentation/pages/product_detail_page.dart';
import 'package:frontend/features/admin/presentation/pages/admin_dashboard_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;
    final isAuthenticated = authState is AuthAuthenticated;
    final isAdmin = authState is AuthAuthenticated &&
        (authState.user.isAdmin ||
            authState.user.roles.any((role) => role.toLowerCase() == 'admin'));
    final isOnAuth =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';
    final isOnAdmin = state.matchedLocation == '/admin';

    if (!isAuthenticated && !isOnAuth) return '/login';
    if (isOnAdmin && !isAdmin) return '/home';
    if (isAuthenticated && isOnAuth) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardPage()),
    GoRoute(
      path: '/product/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ProductDetailPage(productId: id);
      },
    ),
  ],
);
