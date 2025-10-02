import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? address;
  final String? city;
  final String? province;
  final String? postalCode;
  final String? country;
  final DateTime? installationDate;
  final bool registerForWarranty;

  AuthRegisterRequested({
    required this.email,
    required this.password,
    this.firstName,
    this.lastName,
    this.phone,
    this.address,
    this.city,
    this.province,
    this.postalCode,
    this.country,
    this.installationDate,
    required this.registerForWarranty,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    firstName,
    lastName,
    phone,
    address,
    city,
    province,
    postalCode,
    country,
    installationDate,
    registerForWarranty,
  ];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthCheckStoredUser extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthUnauthenticated extends AuthState {
  final DateTime timestamp;

  AuthUnauthenticated() : timestamp = DateTime.now();

  @override
  List<Object?> get props => [timestamp];
}

class AuthAuthenticating extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;

  AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  final String message;

  AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  AuthBloc() : super(AuthUnauthenticated()) {
    print('🔐 AUTH: AuthBloc constructor called');
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckStoredUser>(_onCheckStoredUser);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthAuthenticating());

    try {
      final user = await _authService.login(
        email: event.email,
        password: event.password,
      );

      // Save user data for persistent login
      await _storageService.saveUser(user);

      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthAuthenticating());

    try {
      final user = await _authService.register(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
        address: event.address,
        city: event.city,
        province: event.province,
        postalCode: event.postalCode,
        country: event.country,
        installationDate: event.installationDate,
        registerForWarranty: event.registerForWarranty,
      );

      // Save user data for persistent login
      await _storageService.saveUser(user);

      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    print('🔐 AUTH: AuthLogoutRequested event received');
    print('🔐 AUTH: Logout requested');
    try {
      // Clear stored user data
      print('🔐 AUTH: Clearing stored data');
      await _storageService.clearAll();
      print('🔐 AUTH: Data cleared successfully');

      print('🔐 AUTH: Emitting AuthUnauthenticated state');
      final newState = AuthUnauthenticated();
      print('🔐 AUTH: New state instance: $newState');
      emit(newState);
      print('🔐 AUTH: Logout completed successfully');
    } catch (e) {
      print('🔐 AUTH: Error during logout: $e');
      // Even if clearing fails, still emit unauthenticated state
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onCheckStoredUser(
    AuthCheckStoredUser event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final user = await _storageService.loadUser();

      if (user != null) {
        // Verify token is still valid
        final isValid = await _authService.verifyToken(user.jwtToken);

        if (isValid) {
          emit(AuthAuthenticated(user));
        } else {
          // Token is invalid, clear stored data
          await _storageService.clearAll();
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }
}
