class AppConfig {
  static const String scheduleCsvUrl =
      String.fromEnvironment('POC_SCHEDULE_CSV_URL');

  static const String discordInviteUrl =
      String.fromEnvironment('POC_DISCORD_INVITE_URL');

  static const String oneSignalAppId =
      String.fromEnvironment('POC_ONESIGNAL_APP_ID');

  static bool get hasScheduleUrl => scheduleCsvUrl.isNotEmpty;
  static bool get hasDiscordUrl => discordInviteUrl.isNotEmpty;
  static bool get hasOneSignalId => oneSignalAppId.isNotEmpty;
}
