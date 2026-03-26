import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product_review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/add_to_cart_feedback.dart';
import '../../widgets/smart_image.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _reviewCommentController =
      TextEditingController();

  String _selectedSize = 'M';
  int _selectedColor = 0;
  int _selectedRating = 5;
  bool _isLoadingReviews = true;
  bool _canReview = false;
  bool _hasReviewed = false;
  bool _isSubmittingReview = false;
  List<ProductReview> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _loadReviewsAndPermission();
  }

  @override
  void dispose() {
    _reviewCommentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviewsAndPermission() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final productId = widget.productId;

    final reviews = await _apiService.fetchProductReviews(productId);
    var canReview = false;
    var hasReviewed = false;

    if (user != null) {
      final eligibility = await _apiService.canReviewProduct(
        productId: productId,
        userId: user.id,
      );
      canReview = eligibility.canReview;
      hasReviewed = eligibility.hasReviewed;
    }

    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _canReview = canReview;
      _hasReviewed = hasReviewed;
      _isLoadingReviews = false;
    });
  }

  Future<void> _submitReview() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    if (_reviewCommentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your comment.')),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);

    final ok = await _apiService.submitProductReview(
      productId: widget.productId,
      userId: user.id,
      rating: _selectedRating,
      comment: _reviewCommentController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmittingReview = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit review.')),
      );
      return;
    }

    _reviewCommentController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review submitted successfully.')),
    );
    await _loadReviewsAndPermission();
  }

  Set<String> _outOfStockSizes(List<String> sizes, String productId) {
    if (sizes.length <= 1) return {};
    final hash = productId.hashCode.abs();
    final out = <String>{sizes[hash % sizes.length]};
    if (sizes.length > 3) {
      out.add(sizes[(hash + 2) % sizes.length]);
    }
    if (out.length == sizes.length) {
      out.remove(sizes.first);
    }
    return out;
  }

  String _toHex(Color color) {
    final value = color.value.toRadixString(16).toUpperCase().padLeft(8, '0');
    return '#${value.substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final product = context.read<ProductProvider>().getById(widget.productId);
    final isFavorite =
        context.watch<FavoritesProvider>().isFavorite(product.id);
    final hasRealSizeStocks = product.sizeStocks.isNotEmpty;
    final unavailableSizes = hasRealSizeStocks
        ? product.sizes
            .where((size) => (product.sizeStocks[size] ?? 0) <= 0)
            .toSet()
        : _outOfStockSizes(product.sizes, product.id);
    final availableSizes = product.sizes
        .where((size) => !unavailableSizes.contains(size))
        .toList();
    final effectiveSize = availableSizes.contains(_selectedSize)
        ? _selectedSize
        : (availableSizes.isNotEmpty
            ? availableSizes.first
            : product.sizes.first);

    final colorHexKeys = product.colorImageMap.keys.toList();
    final safeColorIndex =
        _selectedColor < product.colors.length ? _selectedColor : 0;
    final selectedColorHex = colorHexKeys.isNotEmpty
        ? colorHexKeys[safeColorIndex.clamp(0, colorHexKeys.length - 1)]
        : _toHex(product.colors[safeColorIndex]);
    final galleryImages =
        (product.colorImageMap[selectedColorHex] ?? []).isNotEmpty
            ? product.colorImageMap[selectedColorHex]!
            : product.imageUrls;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            onPressed: () =>
                context.read<FavoritesProvider>().toggleFavorite(product.id),
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      formatCurrency(product.finalPrice),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: availableSizes.isEmpty
                    ? null
                    : () {
                        context
                            .read<CartProvider>()
                            .addToCart(product, size: effectiveSize);
                        showAddToCartFeedback(
                          context,
                          productName: product.name,
                        );
                      },
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: const Text('Add to cart'),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: galleryImages.length,
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SmartImage(
                    source: galleryImages[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              formatCurrency(product.finalPrice),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text('${product.reviewsCount} reviews'),
            const SizedBox(height: 14),
            const Text('Size'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: product.sizes.map(
                (size) {
                  final isAvailable = !unavailableSizes.contains(size);
                  final selected = effectiveSize == size;
                  final stock = product.sizeStocks[size];
                  final stockLabel = hasRealSizeStocks
                      ? 'Stock: ${stock ?? 0}'
                      : (isAvailable ? 'In stock' : 'Out of stock');

                  return ChoiceChip(
                    label: Text(
                      '$size • $stockLabel',
                    ),
                    selected: selected,
                    onSelected: isAvailable
                        ? (_) => setState(() => _selectedSize = size)
                        : null,
                  );
                },
              ).toList(),
            ),
            const SizedBox(height: 14),
            const Text('Color'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: List.generate(product.colors.length, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = index),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: product.colors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == index
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            const Text('Description'),
            const SizedBox(height: 6),
            Text(product.description),
            const SizedBox(height: 20),
            Text(
              'Ratings & Reviews',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            if (_canReview)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasReviewed
                            ? 'Update your review'
                            : 'Write your review',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () {
                              setState(() => _selectedRating = star);
                            },
                            icon: Icon(
                              star <= _selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reviewCommentController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Share your experience...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _isSubmittingReview ? null : _submitReview,
                          child: Text(
                            _isSubmittingReview
                                ? 'Submitting...'
                                : (_hasReviewed
                                    ? 'Update Review'
                                    : 'Submit Review'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                'Only customers who purchased this product can leave a review.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            if (_isLoadingReviews)
              const Center(child: CircularProgressIndicator())
            else if (_reviews.isEmpty)
              Text(
                'No reviews yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Column(
                children: _reviews
                    .map(
                      (review) => Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      review.userName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      5,
                                      (index) => Icon(
                                        index < review.rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (review.comment.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(review.comment),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                '${review.createdAt.day.toString().padLeft(2, '0')}/${review.createdAt.month.toString().padLeft(2, '0')}/${review.createdAt.year}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
