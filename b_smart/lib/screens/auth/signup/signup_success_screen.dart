import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../../../theme/instagram_theme.dart';
import '../../../widgets/clay_container.dart';
import '../../../models/auth/auth_user_model.dart';
import '../../../services/session_reset_service.dart';
import '../../../state/app_state.dart';
import '../../../state/auth_actions.dart';
import '../../home_dashboard.dart';

class SignupSuccessScreen extends StatelessWidget {
  final AuthUser user;

  const SignupSuccessScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: InstagramTheme.responsivePadding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ClayContainer(
                  width: 120,
                  height: 120,
                  borderRadius: 60,
                  child: Center(
                    child: Icon(
                      LucideIcons.circleCheck,
                      size: 60,
                      color: InstagramTheme.primaryPink,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome to b Smart!',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your account has been successfully created.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                if (user.username.isNotEmpty)
                  Text(
                    '@${user.username}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: InstagramTheme.primaryPink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                const SizedBox(height: 48),
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: ClayButton(
                    onPressed: () async {
                      await SessionResetService.instance.clearUserSessionState();
                      if (user.id.isNotEmpty) {
                        StoreProvider.of<AppState>(context)
                            .dispatch(SetAuthenticated(user.id));
                      }
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const HomeDashboard(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text('GET STARTED'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
