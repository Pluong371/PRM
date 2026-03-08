import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/utils/currency_formatter.dart';
import 'package:frontend/core/widgets/loading_widget.dart';
import 'package:frontend/core/widgets/error_widget.dart';
import 'package:frontend/injection_container.dart';
import 'package:frontend/common/providers/auth_provider.dart';
import 'package:frontend/common/widgets/review_section.dart';
import 'package:frontend/features/product/presentation/bloc/product_bloc.dart';
import 'package:frontend/features/product/data/models/product_model.dart';

class ProductDetailPage extends StatelessWidget {
  final int productId;

  const ProductDetailPage({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ProductBloc>()..add(LoadProductDetailEvent(productId: productId)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
        body: BlocBuilder<ProductBloc, ProductState>(
          builder: (context, state) {
            if (state is ProductLoading) {
              return const LoadingWidget();
            }
            if (state is ProductError) {
              return AppErrorWidget(
                message: state.message,
                onRetry: () => context.read<ProductBloc>().add(
                  LoadProductDetailEvent(productId: productId),
                ),
              );
            }
            if (state is ProductDetailLoaded) {
              return _ProductDetailBody(product: state.product);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _ProductDetailBody extends StatelessWidget {
  final ProductModel product;

  const _ProductDetailBody({required this.product});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          AspectRatio(
            aspectRatio: 1,
            child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.background,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.background,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 80,
                        color: AppColors.textHint,
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.background,
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 80,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Price
                Text(
                  CurrencyFormatter.format(product.price),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),

                // Brand & Stock
                Row(
                  children: [
                    if (product.brand != null && product.brand!.isNotEmpty) ...[
                      Chip(
                        label: Text(product.brand!),
                        backgroundColor: AppColors.primaryLight,
                        labelStyle: const TextStyle(
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: product.inStock
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.inStock
                            ? 'Còn ${product.stockQuantity} sản phẩm'
                            : 'Hết hàng',
                        style: TextStyle(
                          color: product.inStock
                              ? AppColors.success
                              : AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Categories
                if (product.categories.isNotEmpty) ...[
                  const Text(
                    'Danh mục',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: product.categories
                        .map(
                          (c) => Chip(
                            label: Text(c.name),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Attributes
                if (product.attributes.isNotEmpty) ...[
                  const Text(
                    'Thông số kỹ thuật',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: product.attributes
                            .map(
                              (attr) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        attr.attributeName,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        attr.attributeValue,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Description
                if (product.description != null &&
                    product.description!.isNotEmpty) ...[
                  const Text(
                    'Mô tả sản phẩm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                ReviewSection(
                  productId: product.id.toString(),
                  currentUserId: context.read<AuthProvider>().user?.id,
                  currentUserRole: context.read<AuthProvider>().user?.role,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
