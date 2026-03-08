import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/providers/auth_provider.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../core/utils/validators.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;

  const OTPVerificationPage({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  late TextEditingController _otpController;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  int _remainingTime = 300; // 5 minutes in seconds
  int _remainingAttempts = 3;
  late DateTime _otpSentTime;
  bool _canResendOtp = false;

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
    _otpSentTime = DateTime.now();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
        _startCountdown();
      } else if (mounted && _remainingTime == 0) {
        setState(() {
          _canResendOtp = true;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập mã OTP';
        _successMessage = null;
      });
      return;
    }

    if (_otpController.text.length != 6) {
      setState(() {
        _errorMessage = 'Mã OTP phải có 6 chữ số';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = AuthService();
      final result = await authService.verifyOtp(
        email: widget.email,
        otpCode: _otpController.text.trim(),
      );

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _successMessage = 'Xác nhận OTP thành công!';
          _isLoading = false;
        });

        // Store token and auto login
        if (result['token'] != null) {
          final authProvider = context.read<AuthProvider>();
          await authProvider.setTokenDirectly(result['token']);
          
          // Optional: Fetch user data if user info is available
          if (result['user'] != null) {
            authProvider.setUser(result['user']);
          }
        }

        // Navigate to home after short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/home');
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Xác nhận OTP thất bại';
          _remainingAttempts = result['remainingAttempts'] ?? _remainingAttempts;
          if (_remainingAttempts > 0) {
            _errorMessage = '$_errorMessage ($_remainingAttempts lần thử còn lại)';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = AuthService();
      final result = await authService.sendOtp(widget.email);

      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _successMessage = 'Đã gửi lại mã OTP. Kiểm tra email của bạn.';
          _remainingTime = 300;
          _remainingAttempts = 3;
          _canResendOtp = false;
          _otpSentTime = DateTime.now();
          _otpController.clear();
          _isLoading = false;
        });
        _startCountdown();
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Không thể gửi lại mã OTP';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận OTP'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mail_outline,
                  size: 40,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Xác nhận email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'Chúng tôi đã gửi mã xác nhận 6 chữ số đến\n${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Success Message
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null) const SizedBox(height: 16),

              // OTP Input Field
              TextFormField(
                controller: _otpController,
                maxLength: 6,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                enabled: !_isLoading,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(
                    fontSize: 32,
                    color: Colors.grey[300],
                    letterSpacing: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onChanged: (_) {
                  setState(() {
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Timer Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule,
                    color: _remainingTime < 60 ? Colors.red : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mã hết hạn sau: ${_formatTime(_remainingTime)}',
                    style: TextStyle(
                      color: _remainingTime < 60 ? Colors.red : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Xác nhận',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Resend Button
              TextButton(
                onPressed: _canResendOtp && !_isLoading ? _resendOtp : null,
                child: Text(
                  _canResendOtp
                      ? 'Gửi lại mã OTP'
                      : 'Gửi lại mã OTP (${_formatTime(_remainingTime)})',
                  style: TextStyle(
                    color: _canResendOtp
                        ? Colors.blue.shade600
                        : Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Back Button
              TextButton(
                onPressed: () {
                  context.pop();
                },
                child: Text(
                  'Quay lại đăng nhập',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
