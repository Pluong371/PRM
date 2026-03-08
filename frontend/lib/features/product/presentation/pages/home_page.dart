import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/widgets/loading_widget.dart';
import 'package:frontend/core/widgets/error_widget.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:frontend/features/product/presentation/bloc/product_bloc.dart';
import 'package:frontend/features/product/presentation/widgets/product_card.dart';
import 'package:frontend/features/product/presentation/widgets/filter_dialog.dart';
import 'package:frontend/features/product/data/models/product_model.dart';
import 'package:frontend/common/providers/product_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductBloc>()..add(const LoadProductsEvent()),
      child: const _HomePageView(),
    );
  }
}

class _HomePageView extends StatefulWidget {
  const _HomePageView();

  @override
  State<_HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends State<_HomePageView> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<ProductBloc>().add(SearchProductsEvent(query: query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShopWeb'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(const LogoutEvent());
              context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar with Filter
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm sản phẩm...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                context.read<ProductBloc>().add(
                                  const SearchProductsEvent(query: ''),
                                );
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune, color: AppColors.primary),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => FilterDialog(
                          onApply: (filters) {
                            // Trigger advanced search with filters
                            context.read<ProductProvider>().searchAdvanced(
                              query: _searchController.text,
                              minPrice: filters['minPrice'],
                              maxPrice: filters['maxPrice'],
                              inStockOnly: filters['inStockOnly'],
                              sortBy: filters['sortBy'],
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Category Chips
          BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              if (state is ProductsLoaded && state.categories.isNotEmpty) {
                return _CategoryChips(
                  categories: state.categories,
                  selectedId: state.selectedCategoryId,
                  onSelected: (id) {
                    context.read<ProductBloc>().add(
                      FilterByCategoryEvent(categoryId: id),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Products Grid
          Expanded(
            child: BlocBuilder<ProductBloc, ProductState>(
              builder: (context, state) {
                if (state is ProductLoading) {
                  return const LoadingWidget(message: 'Đang tải sản phẩm...');
                }
                if (state is ProductError) {
                  return AppErrorWidget(
                    message: state.message,
                    onRetry: () {
                      context.read<ProductBloc>().add(
                        const LoadProductsEvent(),
                      );
                    },
                  );
                }
                if (state is ProductsLoaded) {
                  if (state.products.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: AppColors.textHint,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Không tìm thấy sản phẩm',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<ProductBloc>().add(
                        const LoadProductsEvent(),
                      );
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: state.products.length,
                      itemBuilder: (context, index) {
                        final product = state.products[index];
                        return ProductCard(
                          product: product,
                          onTap: () => context.push('/product/${product.id}'),
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Chips Widget ───
class _CategoryChips extends StatelessWidget {
  final List<CategoryModel> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _CategoryChips({
    required this.categories,
    this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Tất cả'),
              selected: selectedId == null,
              onSelected: (_) => onSelected(null),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selectedId == null
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: selectedId == null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          // Category chips
          ...categories
              .where((c) => c.isActive != false)
              .map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.name),
                    selected: selectedId == cat.id,
                    onSelected: (_) => onSelected(cat.id),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selectedId == cat.id
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selectedId == cat.id
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
