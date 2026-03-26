import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/add_to_cart_feedback.dart';
import '../../widgets/product_card.dart';
import '../../widgets/smart_image.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openDetail(BuildContext context, Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.id),
      ),
    );
  }

  void _addToCart(BuildContext context, Product product, {String size = 'M'}) {
    context.read<CartProvider>().addToCart(product, size: size);
    showAddToCartFeedback(context, productName: product.name);
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final favoritesProvider = context.watch<FavoritesProvider>();
    final allProducts = productProvider.products;
    final filteredProducts = productProvider.filteredProducts;
    final trendingProducts = allProducts.take(8).toList();
    final justDroppedProducts = allProducts
        .where((p) => p.category.toLowerCase().contains('new'))
        .take(8)
        .toList();
    final bestSellerProducts = List<Product>.from(allProducts)
      ..sort((a, b) => b.reviewsCount.compareTo(a.reviewsCount));
    final categories = [
      'All',
      'Men',
      'Women',
      'Kids',
      'Shoes',
      'Sale',
      'New Arrival',
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discover Outfits',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            _SaleCountdownBanner(
              onTapShop: () => productProvider.setCategory('Sale'),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: productProvider.search,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final selected = category == productProvider.selectedCategory;

                  return ChoiceChip(
                    selected: selected,
                    label: Text(category),
                    onSelected: (_) => productProvider.setCategory(category),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productProvider.isLoading
                  ? const _HomeLoadingSkeleton()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount =
                            constraints.maxWidth > 700 ? 3 : 2;
                        final showRetailSections =
                            productProvider.selectedCategory == 'All' &&
                                !productProvider.hasActiveSearch;

                        return ListView(
                          children: [
                            if (showRetailSections) ...[
                              _ProductRowSection(
                                title: 'Trending Now',
                                products: trendingProducts,
                                onTapProduct: (product) =>
                                    _openDetail(context, product),
                                onAddProduct: (product) => _addToCart(
                                  context,
                                  product,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ProductRowSection(
                                title: 'Just Dropped',
                                products: justDroppedProducts,
                                onTapProduct: (product) =>
                                    _openDetail(context, product),
                                onAddProduct: (product) => _addToCart(
                                  context,
                                  product,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ProductRowSection(
                                title: 'Best Seller',
                                products: bestSellerProducts.take(8).toList(),
                                onTapProduct: (product) =>
                                    _openDetail(context, product),
                                onAddProduct: (product) => _addToCart(
                                  context,
                                  product,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            Text(
                              showRetailSections
                                  ? 'All Products'
                                  : (productProvider.hasActiveSearch
                                      ? 'Search Results'
                                      : 'Filtered Products'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            if (filteredProducts.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'No products match this filter.',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredProducts.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.62,
                                ),
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];

                                  return ProductCard(
                                    product: product,
                                    isFavorite: favoritesProvider
                                        .isFavorite(product.id),
                                    onToggleFavorite: () {
                                      context
                                          .read<FavoritesProvider>()
                                          .toggleFavorite(product.id);
                                    },
                                    onTap: () => _openDetail(context, product),
                                    onAddToCart: () =>
                                        _addToCart(context, product),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleCountdownBanner extends StatelessWidget {
  final VoidCallback onTapShop;

  const _SaleCountdownBanner({required this.onTapShop});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final remaining = end.difference(now);
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flash Sale',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ends in $hours:$minutes:$seconds',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onTapShop,
            child: const Text('Shop Sale'),
          ),
        ],
      ),
    );
  }
}

class _ProductRowSection extends StatelessWidget {
  final String title;
  final List<Product> products;
  final ValueChanged<Product> onTapProduct;
  final ValueChanged<Product> onAddProduct;

  const _ProductRowSection({
    required this.title,
    required this.products,
    required this.onTapProduct,
    required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    final items = products.isEmpty ? <Product>[] : products;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 252,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = items[index];
              final imageSource = product.imageUrls.isNotEmpty
                  ? product.imageUrls.first
                  : 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800';

              return SizedBox(
                width: 152,
                child: Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onTapProduct(product),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SmartImage(
                            source: imageSource,
                            width: double.infinity,
                            height: 128,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCurrency(product.finalPrice),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton(
                            onPressed: () => onAddProduct(product),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(34),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomeLoadingSkeleton extends StatelessWidget {
  const _HomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _SkeletonBox(height: 96, borderRadius: 16),
        const SizedBox(height: 12),
        _SkeletonBox(height: 34, borderRadius: 12),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, __) =>
                const _SkeletonBox(width: 80, borderRadius: 18),
          ),
        ),
        const SizedBox(height: 12),
        const _SkeletonBox(height: 20, width: 140, borderRadius: 8),
        const SizedBox(height: 8),
        SizedBox(
          height: 252,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => const _SkeletonBox(
              width: 152,
              borderRadius: 12,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _SkeletonBox(height: 20, width: 120, borderRadius: 8),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.62,
          ),
          itemBuilder: (_, __) => const _SkeletonBox(borderRadius: 18),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const _SkeletonBox({
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
