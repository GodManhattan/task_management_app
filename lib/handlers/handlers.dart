import 'package:task_management_app/core/routing/app_router.dart';
import 'package:app_links/app_links.dart';

Future<void> initDeepLinks() async {
  final appLinks = AppLinks();

  // Handle app startup case
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    _handleDeepLink(initialUri.toString());
  }

  // Handle case when app is already running
  appLinks.uriLinkStream.listen((uri) {
    _handleDeepLink(uri.toString());
  });
}

void _handleDeepLink(String link) {
  if (link.contains('reset-password')) {
    AppRouter.router.go('/reset-password');
  }
}
