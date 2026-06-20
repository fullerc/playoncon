import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/schedule_repository.dart';
import '../../theme/poc_theme.dart';

class InfoPage extends ConsumerWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scheduleRepositoryProvider);
    final lastSync = state.lastSyncAt;
    final lastSyncText = lastSync == null
        ? 'Never'
        : DateFormat('EEE MMM d, h:mm a').format(lastSync);

    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const _LogoHeader(),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Join the Discord'),
            subtitle: AppConfig.hasDiscordUrl
                ? const Text('Opens in Discord or browser')
                : const Text('Discord URL not configured'),
            enabled: AppConfig.hasDiscordUrl,
            onTap: AppConfig.hasDiscordUrl
                ? () => launchUrl(
                      Uri.parse(AppConfig.discordInviteUrl),
                      mode: LaunchMode.externalApplication,
                    )
                : null,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('Refresh schedule'),
            subtitle: Text('Last sync: $lastSyncText'),
            trailing: state.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onTap: state.isSyncing
                ? null
                : () =>
                    ref.read(scheduleRepositoryProvider.notifier).refresh(),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Play On Con'),
            subtitle: Text('Convention companion · v1.0'),
          ),
        ],
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/branding/poc-logo.png',
                width: 180,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Play On Con',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: PocColors.forestDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Alabama 4-H Center · Columbiana, AL',
            style: TextStyle(color: PocColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
