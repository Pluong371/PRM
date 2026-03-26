import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/vnpay_demo_service.dart';
import '../../utils/currency_formatter.dart';

class PaymentQrScreen extends StatefulWidget {
  final double amount;
  final String orderCode;
  final String paymentMethod;

  const PaymentQrScreen({
    super.key,
    required this.amount,
    required this.orderCode,
    required this.paymentMethod,
  });

  @override
  State<PaymentQrScreen> createState() => _PaymentQrScreenState();
}

class _PaymentQrScreenState extends State<PaymentQrScreen> {
  late final WebViewController _webViewController;
  bool _completed = false;
  bool _isLoading = true;
  String _currentUrl = '';
  Timer? _submitRetryTimer;
  int _submitAttempts = 0;

  @override
  void initState() {
    super.initState();

    final url = VnPayDemoService.buildDemoUrl(
      orderCode: widget.orderCode,
      amount: widget.amount.round(),
      paymentMethod: widget.paymentMethod,
    );

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (currentUrl) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            _currentUrl = currentUrl;

            if (widget.paymentMethod == 'VNPay' &&
                _isCreateOrderPage(currentUrl)) {
              _submitAttempts = 0;
              _submitCreateOrder();
              _startRetryAutoSubmit();
            }

            _handleAutoResult(currentUrl);
          },
          onNavigationRequest: (request) {
            _currentUrl = request.url;
            _handleAutoResult(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    _submitRetryTimer?.cancel();
    super.dispose();
  }

  bool _isCreateOrderPage(String url) {
    final lower = url.toLowerCase();
    return lower.contains('/tryitnow/home/createorder');
  }

  void _startRetryAutoSubmit() {
    _submitRetryTimer?.cancel();
    _submitRetryTimer = Timer.periodic(const Duration(milliseconds: 800), (
      timer,
    ) async {
      if (!mounted || _completed) {
        timer.cancel();
        return;
      }

      final lowerUrl = _currentUrl.toLowerCase();
      if (lowerUrl.contains('paymentmethod.html?token=')) {
        timer.cancel();
        return;
      }

      if (!_isCreateOrderPage(_currentUrl)) {
        timer.cancel();
        return;
      }

      _submitAttempts += 1;
      if (_submitAttempts > 8) {
        timer.cancel();
        return;
      }

      await _submitCreateOrder();
    });
  }

  Future<void> _submitCreateOrder() async {
    final amount = widget.amount.round();
    final orderCode = widget.orderCode;
    final description = 'Thanh toan don hang $orderCode';

    final javascript = '''
      (function() {
        var form = document.getElementById('frmCreateOrder');
        if (!form) return;

        var amountEl = document.getElementById('Amount');
        if (amountEl) amountEl.value = '$amount';

        var descEl = document.getElementById('OrderDescription');
        if (descEl) descEl.value = '$description';

        var langEl = document.getElementById('language');
        if (langEl) langEl.value = 'vn';

        var bankEl = document.getElementById('bankcode');
        if (bankEl) bankEl.value = '';

        var redirectButton = form.querySelector('button[type="submit"]');
        if (redirectButton) {
          redirectButton.click();
        } else {
          form.submit();
        }
      })();
    ''';

    await _webViewController.runJavaScript(javascript);
  }

  void _handleAutoResult(String url) {
    if (widget.paymentMethod != 'VNPay') return;
    if (_completed || !mounted) return;

    if (VnPayDemoService.isSuccessUrl(url)) {
      _submitRetryTimer?.cancel();
      _finish(true);
    } else if (VnPayDemoService.isFailureUrl(url)) {
      _submitRetryTimer?.cancel();
      _finish(false);
    }
  }

  void _finish(bool success) {
    if (_completed || !mounted) return;
    _completed = true;
    Navigator.pop(context, success);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pay with ${widget.paymentMethod}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VNPay Sandbox Demo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text('Order: ${widget.orderCode}'),
            Text('Amount: ${formatCurrency(widget.amount, suffix: 'VND')}'),
            const SizedBox(height: 6),
            Text(
              _currentUrl.toLowerCase().contains('paymentmethod.html?token=')
                  ? 'Order created: redirected to PaymentMethod token URL'
                  : 'Auto filling amount and clicking Thanh toan Redirect...',
              style: TextStyle(
                color: _currentUrl
                        .toLowerCase()
                        .contains('paymentmethod.html?token=')
                    ? Colors.green
                    : Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: WebViewWidget(controller: _webViewController),
                  ),
                  if (_isLoading)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x66FFFFFF),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: VnPayDemoService.demoUrl),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('VNPay demo URL copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.link_outlined),
                    label: const Text('Copy demo URL'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _webViewController.reload(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _finish(false),
                child: const Text('Cancel payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
