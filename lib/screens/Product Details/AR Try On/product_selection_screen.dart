import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'ar_tryon_screen.dart';

class ProductSelectionScreen extends StatefulWidget {
  final String frontImageUrl;
  final String backImageUrl;
  final ClothingCategory category;

  const ProductSelectionScreen({
    Key? key,
    required this.frontImageUrl,
    required this.backImageUrl,
    required this.category,
  }) : super(key: key);

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _startTryOn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // flutter_cache_manager handles caching automatically
      // Ek baar download hoga, baad mein local cache se milega
      final frontFile = await DefaultCacheManager().getSingleFile(widget.frontImageUrl);
      final backFile = await DefaultCacheManager().getSingleFile(widget.backImageUrl);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ARTryOnScreen(
            frontImagePath: frontFile.path,
            backImagePath: backFile.path,
            category: widget.category,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Image load nahi hui: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Try On'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF111111),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category display (read-only, passed from constructor)
            Text(
              'Category: ${_categoryLabel(widget.category)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 28),
            const Text(
              'Clothing Preview',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildNetworkPreview('Front', widget.frontImageUrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildNetworkPreview('Back', widget.backImageUrl)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startTryOn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
                    : const Text(
                  'Try On Karo →',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkPreview(String label, String url) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        // CachedNetworkImage directly for UI preview
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white38,
              ),
            );
          },
          errorBuilder: (_, __, ___) => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, color: Colors.white24, size: 32),
              SizedBox(height: 6),
              Text('Load failed', style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(ClothingCategory cat) {
    return switch (cat) {
      ClothingCategory.tshirt => '👕 T-Shirt',
      ClothingCategory.hoodie => '🧥 Hoodie',
      ClothingCategory.pant   => '👖 Pant',
    };
  }
}