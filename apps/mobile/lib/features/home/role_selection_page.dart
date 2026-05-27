import 'package:flutter/material.dart';

import '../live/live_host_page.dart';
import '../live/live_support_page.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Connect',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '라이브로 도움을 주고받는 접근성 커뮤니티',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              _RoleButton(
                title: '라이브 열기',
                subtitle: '카메라와 음성으로 도움을 요청하거나 방송합니다.',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LiveHostPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _RoleButton(
                title: '라이브 참여',
                subtitle: '화면을 보며 안내하거나 함께 이야기합니다.',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LiveSupportPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onPrimary;

    return FilledButton(
      style: FilledButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: textColor),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: textColor)),
        ],
      ),
    );
  }
}
