import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/auth_bloc.dart';
import 'blocs/device_bloc.dart';
import 'blocs/device_discovery_bloc.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'utils/theme.dart';

void main() {
  runApp(const StayLitApp());
}

class StayLitApp extends StatelessWidget {
  const StayLitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) {
            print('🔐 MAIN: Creating AuthBloc instance');
            return AuthBloc()..add(AuthCheckStoredUser());
          },
        ),
        BlocProvider<DeviceBloc>(create: (context) => DeviceBloc()),
        BlocProvider<DeviceDiscoveryBloc>(
          create: (context) => DeviceDiscoveryBloc(),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          print('🔐 MAIN: Auth state changed to: ${state.runtimeType}');
          print('🔐 MAIN: State details: $state');

          // Automatically sync devices from WordPress when user authenticates
          if (state is AuthAuthenticated) {
            print('🔐 MAIN: User authenticated, triggering device sync');
            context.read<DeviceBloc>().add(
              SyncWithWordPress(state.user.jwtToken),
            );
          }
        },
        child: MaterialApp(
          title: 'Stay Lit',
          theme: appTheme,
          home: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              print(
                '🔐 MAIN: BlocBuilder rebuilding with state: ${state.runtimeType}',
              );
              if (state is AuthAuthenticated) {
                print('🔐 MAIN: User authenticated, showing HomeScreen');
                return const HomeScreen();
              } else {
                print('🔐 MAIN: User not authenticated, showing WelcomeScreen');
                return const WelcomeScreen();
              }
            },
          ),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
