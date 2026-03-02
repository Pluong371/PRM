import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:frontend/core/errors/exceptions.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';
import 'package:frontend/features/auth/domain/repositories/auth_repository.dart';

// ─── Events ───
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class LoginEvent extends AuthEvent {
  final String username;
  final String password;
  const LoginEvent({required this.username, required this.password});
  @override
  List<Object?> get props => [username, password];
}

class SendOtpEvent extends AuthEvent {
  final String email;
  const SendOtpEvent({required this.email});
  @override
  List<Object?> get props => [email];
}

class RegisterEvent extends AuthEvent {
  final String username;
  final String email;
  final String password;
  final String fullName;
  final String otpCode;
  const RegisterEvent({
    required this.username,
    required this.email,
    required this.password,
    required this.fullName,
    required this.otpCode,
  });
  @override
  List<Object?> get props => [username, email, password, fullName, otpCode];
}

class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

class CheckAuthEvent extends AuthEvent {
  const CheckAuthEvent();
}

// ─── States ───
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated({required this.user});
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});
  @override
  List<Object?> get props => [message];
}

class OtpSent extends AuthState {
  final String message;
  const OtpSent({required this.message});
  @override
  List<Object?> get props => [message];
}

class RegisterSuccess extends AuthState {
  final String message;
  const RegisterSuccess({required this.message});
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ───
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthInitial()) {
    on<CheckAuthEvent>(_onCheckAuth);
    on<LoginEvent>(_onLogin);
    on<SendOtpEvent>(_onSendOtp);
    on<RegisterEvent>(_onRegister);
    on<LogoutEvent>(_onLogout);
  }

  Future<void> _onCheckAuth(
    CheckAuthEvent event,
    Emitter<AuthState> emit,
  ) async {
    final user = await authRepository.getStoredUser();
    if (user != null) {
      emit(AuthAuthenticated(user: user));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final user = await authRepository.login(event.username, event.password);
      emit(AuthAuthenticated(user: user));
    } on ServerException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: 'Đã xảy ra lỗi: ${e.toString()}'));
    }
  }

  Future<void> _onSendOtp(SendOtpEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final message = await authRepository.sendRegisterOtp(event.email);
      emit(OtpSent(message: message));
    } on ServerException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: 'Gửi OTP thất bại'));
    }
  }

  Future<void> _onRegister(RegisterEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final message = await authRepository.register(
        username: event.username,
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        otpCode: event.otpCode,
      );
      emit(RegisterSuccess(message: message));
    } on ServerException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: 'Đăng ký thất bại'));
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    await authRepository.logout();
    emit(const AuthUnauthenticated());
  }
}
