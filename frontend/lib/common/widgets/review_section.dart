import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/review_provider.dart';
import '../models/review_model.dart';

class ReviewSection extends StatefulWidget {
  final String productId;
  final String? currentUserId;
  final String? currentUserRole;

  const ReviewSection({
    super.key,
    required this.productId,
    this.currentUserId,
    this.currentUserRole,
  });

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final TextEditingController _commentController = TextEditingController();
  int _selectedRating = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ReviewProvider>();
      await provider.loadProductReviews(
        productId: widget.productId,
        userId: widget.currentUserId,
      );
      if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty) {
        await provider.checkCanReview(
          productId: widget.productId,
          userId: widget.currentUserId!,
        );
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewProvider>(
      builder: (context, provider, _) {
        final canWriteReview = widget.currentUserId != null &&
            widget.currentUserId!.isNotEmpty &&
            provider.canReview;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Danh gia san pham',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: provider.sortBy,
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Moi nhat')),
                    DropdownMenuItem(value: 'rating', child: Text('Diem cao')),
                    DropdownMenuItem(value: 'helpful', child: Text('Huu ich nhat')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    provider.setSortBy(value);
                    await provider.loadProductReviews(
                      productId: widget.productId,
                      userId: widget.currentUserId,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (canWriteReview && !provider.hasReviewed)
              _buildReviewForm(context, provider)
            else if (widget.currentUserId != null && !provider.canReview)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ban chi co the danh gia sau khi da mua san pham nay.',
                  style: TextStyle(color: Colors.black87),
                ),
              ),

            const SizedBox(height: 16),

            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (provider.reviews.isEmpty)
              const Text(
                'Chua co danh gia nao.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...provider.reviews.map(
                (review) => _ReviewTile(
                  review: review,
                  currentUserId: widget.currentUserId,
                  currentUserRole: widget.currentUserRole,
                  onHelpful: () async {
                    if (widget.currentUserId == null ||
                        widget.currentUserId!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui long dang nhap de danh dau huu ich')),
                      );
                      return;
                    }
                    await provider.toggleHelpful(
                      reviewId: review.id,
                      userId: widget.currentUserId!,
                      productId: widget.productId,
                    );
                  },
                  onDelete: () async {
                    if (widget.currentUserId == null ||
                        widget.currentUserId!.isEmpty) {
                      return;
                    }
                    final ok = await provider.deleteReview(
                      reviewId: review.id,
                      userId: widget.currentUserId!,
                      productId: widget.productId,
                    );
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Da xoa danh gia')),
                      );
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildReviewForm(BuildContext context, ReviewProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Viet danh gia cua ban',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                onPressed: () {
                  setState(() {
                    _selectedRating = value;
                  });
                },
                icon: Icon(
                  value <= _selectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Nhap nhan xet cua ban',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      if (widget.currentUserId == null ||
                          widget.currentUserId!.isEmpty) {
                        return;
                      }
                      final comment = _commentController.text.trim();
                      if (comment.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui long nhap noi dung danh gia')),
                        );
                        return;
                      }

                      final ok = await provider.submitReview(
                        productId: widget.productId,
                        userId: widget.currentUserId!,
                        rating: _selectedRating,
                        comment: comment,
                      );

                      if (!mounted) return;
                      if (ok) {
                        _commentController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gui danh gia thanh cong')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(provider.error ?? 'Gui danh gia that bai')),
                        );
                      }
                    },
              child: const Text('Gui danh gia'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  final String? currentUserId;
  final String? currentUserRole;
  final VoidCallback onHelpful;
  final VoidCallback onDelete;

  const _ReviewTile({
    required this.review,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onHelpful,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final canDelete = (currentUserId != null && currentUserId == review.userId) ||
        (currentUserRole ?? '').toLowerCase() == 'admin';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  review.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${review.rating}/5',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, color: Colors.amber, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(review.comment),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onHelpful,
                  icon: Icon(
                    review.isHelpfulByMe ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                    size: 18,
                  ),
                  label: Text('Huu ich (${review.helpfulCount})'),
                ),
                const Spacer(),
                if (canDelete)
                  TextButton(
                    onPressed: onDelete,
                    child: const Text('Xoa', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
