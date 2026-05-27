import 'package:flutter/material.dart';

import '../../features/home/role_selection_page.dart';
import '../../features/live/live_host_page.dart';
import '../../features/live/live_invite_parser.dart';
import '../../features/live/live_support_page.dart';

class ConnectRoutes {
  const ConnectRoutes._();

  static const String home = '/';
  static const String host = '/host';
  static const String support = '/support';
}

class ConnectRouter {
  const ConnectRouter._();

  static Route<void> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name?.trim();

    if (routeName == null ||
        routeName.isEmpty ||
        routeName == ConnectRoutes.home) {
      return _pageRoute(settings, const RoleSelectionPage());
    }

    final uri = Uri.tryParse(routeName);
    if (uri != null && uri.path == ConnectRoutes.support) {
      final invite = uri.queryParameters['invite']?.trim();
      return _pageRoute(
        settings,
        LiveSupportPage(
          initialInvite: invite == null || invite.isEmpty ? null : invite,
        ),
      );
    }

    if (routeName == ConnectRoutes.host) {
      return _pageRoute(settings, const LiveHostPage());
    }

    if (routeName == ConnectRoutes.support) {
      return _pageRoute(settings, const LiveSupportPage());
    }

    if (InviteTarget.tryParseLink(routeName) != null) {
      return _pageRoute(
        settings,
        LiveSupportPage(initialInvite: routeName),
      );
    }

    return _pageRoute(settings, const RoleSelectionPage());
  }

  static MaterialPageRoute<void> _pageRoute(
    RouteSettings settings,
    Widget page,
  ) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => page,
    );
  }
}
