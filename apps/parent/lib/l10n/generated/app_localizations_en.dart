// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navTasks => 'Tasks';

  @override
  String get navNotes => 'Notes';

  @override
  String get navSettings => 'Settings';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonOk => 'OK';

  @override
  String get commonError => 'Error';

  @override
  String get commonImport => 'Import';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonUnknown => '(unknown)';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSand => 'Sand';

  @override
  String get themeDusk => 'Dusk';

  @override
  String get themeNight => 'Night';

  @override
  String get themeLightDesc => 'Bright blue';

  @override
  String get themeSandDesc => 'Warm paper';

  @override
  String get themeDuskDesc => 'Blue-grey dark';

  @override
  String get themeNightDesc => 'OLED black';

  @override
  String get themeChoose => 'Choose theme';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsSectionSync => 'Sync';

  @override
  String get settingsWebDavConfigure => 'Configure WebDAV';

  @override
  String get settingsWebDavConnected => 'Connected';

  @override
  String get settingsWebDavConnectHint =>
      'Connect to a Nextcloud or WebDAV server';

  @override
  String get settingsSectionFamily => 'Family';

  @override
  String get settingsPartner => 'Partner';

  @override
  String get settingsPartnerPaired => 'Partner linked';

  @override
  String get settingsPartnerLinkHint => 'Link with your partner';

  @override
  String get settingsKids => 'Kids';

  @override
  String get settingsKidsLinkHint => 'Link the kids app';

  @override
  String settingsKidsEnrolledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kids linked',
      one: '1 kid linked',
    );
    return '$_temp0';
  }

  @override
  String get settingsSectionVault => 'Vault';

  @override
  String get settingsVerifyPhrase => 'Verify recovery phrase';

  @override
  String get settingsVerifyPhraseSubtitle =>
      'Check that you still know the 12 words. We will not show them.';

  @override
  String get settingsShowPhrase => 'Show recovery phrase';

  @override
  String get settingsShowPhraseSubtitle =>
      'Show the 12 words on this device (screen lock).';

  @override
  String get settingsSectionBackup => 'Backup & Restore';

  @override
  String get settingsExportBackup => 'Export backup';

  @override
  String get settingsExportBackupSubtitle =>
      'Encrypted .kvault file. The recovery phrase is not included.';

  @override
  String get settingsImportBackup => 'Import backup';

  @override
  String get settingsImportBackupSubtitle =>
      'Restore from .kvault with your 12 words';

  @override
  String notifServiceFailed(String error) {
    return 'Notification service failed to start: $error';
  }

  @override
  String get notifDisabledBanner =>
      'Notifications are disabled. Turn them on in Settings to receive reminders.';

  @override
  String get notifExactAlarmBanner =>
      'Exact reminders are disabled. Allow \"Alarms & reminders\" for precise times.';

  @override
  String get familyKeyScanTitle => 'Scan family key';

  @override
  String get familyKeyScanHint => 'Point at your partner\'s QR code';

  @override
  String get familyKeyEnterPhrase => 'Enter phrase';

  @override
  String get familyKeyFound => 'Key found';

  @override
  String get familyKeyPartner => 'Partner';

  @override
  String get familyKeyServer => 'Server';

  @override
  String get familyKeyFingerprint => 'Fingerprint';

  @override
  String familyKeyServerMismatch(String scanned, String current) {
    return 'The server in the QR code ($scanned) does not match your server ($current). Are you sure you want to continue?';
  }

  @override
  String get familyKeyConfirmPartner =>
      'Is this the right partner? Check the username above.';

  @override
  String get familyKeyAlreadyPairedWarning =>
      'You already have a family key. Importing a new one will make data encrypted with the current key unreadable until you sync again.';

  @override
  String get familyKeyEnterTitle => 'Enter family key';

  @override
  String get familyKeyEnterSubtitle =>
      'Enter your partner\'s 12 words. You will then see the fingerprint to verify.';

  @override
  String get familyKeySaved => 'Family key saved.';

  @override
  String familyKeySaveError(String error) {
    return 'Error saving: $error';
  }

  @override
  String familyKeyInvalidQr(String error) {
    return 'Invalid QR code: $error';
  }

  @override
  String get familyKeyShareTitle => 'Share family key';

  @override
  String get familyKeyShareLegacyBody =>
      'Have your partner scan this QR code. This family key is from before the recovery phrase and has no 12 words.';

  @override
  String get familyKeyShareBody =>
      'Have your partner scan this QR code, or type the 12 words.';

  @override
  String get familyKeyShareNoPassword =>
      'The code does not include the WebDAV password. Check the fingerprint together.';

  @override
  String get familyKeyShareNoEntropy =>
      'No recovery-phrase data on this device. Create a new family key.';

  @override
  String familyKeyShareFingerprint(String fingerprint) {
    return 'Fingerprint  $fingerprint';
  }

  @override
  String get familyKeyPartnerScanned => 'Partner has scanned';

  @override
  String get familyKeyShared => 'Family key shared';

  @override
  String get vaultWelcomeTitle => 'Your vault';

  @override
  String get vaultWelcomeBody =>
      'Kinetic Link stores tasks and notes with a 12-word recovery phrase. Write that phrase on paper. On this device you can show it again later (with screen lock).';

  @override
  String get vaultNewVault => 'New vault';

  @override
  String get vaultRestoreVault => 'Restore vault';

  @override
  String get vaultLegacyBackup => 'Legacy backup (.kbak2)';

  @override
  String get vaultCreateVault => 'Create vault';

  @override
  String get vaultRecoveryPhrase => 'Recovery phrase';

  @override
  String get vaultConfirm => 'Confirm';

  @override
  String get vaultWriteWords =>
      'Write these 12 words on paper and keep them safe. Without this phrase you cannot restore the vault on a new device.';

  @override
  String get vaultPhraseCopied => 'Recovery phrase copied';

  @override
  String get vaultIWroteThemDown => 'I wrote them down';

  @override
  String get vaultQuizPrompt =>
      'Fill in the requested words to confirm you saved the phrase.';

  @override
  String vaultWordN(int n) {
    return 'Word $n';
  }

  @override
  String get vaultBackToWords => 'Back to the words';

  @override
  String get vaultQuizMismatch => 'Not all words match. Try again.';

  @override
  String vaultCreateFailed(String error) {
    return 'Could not create the vault: $error';
  }

  @override
  String get vaultCouldNotReadFile => 'Could not read the file.';

  @override
  String vaultInvalidLegacyBackup(String error) {
    return 'Invalid legacy backup: $error';
  }

  @override
  String get vaultRestoreTitle => 'Restore vault';

  @override
  String get vaultRestoreIntro =>
      'Choose how to restore the vault. The recovery phrase is the same in both cases.';

  @override
  String get vaultRestoreFromFile => 'From file';

  @override
  String get vaultRestoreFromWebDav => 'From WebDAV';

  @override
  String get vaultRestoreFromWebDavSubtitle =>
      'Server, credentials, and 12 words. No file needed.';

  @override
  String get vaultRestoreFileTitle => 'Restore from file';

  @override
  String get vaultRestoreFileBody =>
      'Enter your recovery phrase, then choose the .kvault file.';

  @override
  String get vaultChooseFileAndRestore => 'Choose file and restore';

  @override
  String get vaultNoVaultOnServer =>
      'No vault on this server. Create a new vault or choose a different server.';

  @override
  String get vaultPhraseMismatchServer =>
      'This recovery phrase does not match the vault on this server.';

  @override
  String get vaultRestoreWebDavTitle => 'Restore from WebDAV';

  @override
  String get vaultRestoreWebDavBody =>
      'Sign in to your server and enter the same 12 words used when creating the vault.';

  @override
  String get vaultServerUrl => 'Server URL';

  @override
  String get vaultUsername => 'Username';

  @override
  String get vaultPassword => 'Password';

  @override
  String get vaultUnlock => 'Unlock vault';

  @override
  String get vaultPhraseFieldLabel => 'Recovery phrase (12 words)';

  @override
  String get vaultMigrateTitle => 'New recovery phrase';

  @override
  String get vaultMigrateBody =>
      'Your current key is random (version 0.2) and cannot become 12 words. Tasks and notes on this device stay. We will create a new recovery phrase. On the next sync, personal files are re-encrypted. The family key stays the same — partner and kids do not need to re-link.';

  @override
  String get vaultMigrateActivate => 'Activate new recovery phrase';

  @override
  String get vaultMigrateHeadline =>
      'Write down these new 12 words. The old key will no longer work for WebDAV or a .kvault.';

  @override
  String get vaultRestoreFromFileSubtitle =>
      '12 words + encrypted .kvault file. No internet needed.';

  @override
  String get vaultBiometricsReason => 'Show the recovery phrase on this device';

  @override
  String get vaultNoScreenLockTitle => 'No screen lock';

  @override
  String get vaultNoScreenLockBody =>
      'This device has no Face ID, fingerprint, or PIN. Anyone with access to the app can see the words. Continue?';

  @override
  String get vaultShowAnyway => 'Show anyway';

  @override
  String get vaultRevealWarning =>
      'Write the words down again on paper if you lost your copy. Do not leave this screen open.';

  @override
  String get familyCreateTitle => 'Family key';

  @override
  String get familyCreateWriteWords =>
      'Write these 12 words down. They belong to the family key you share with your partner. We do not store the words.';

  @override
  String familyCreateFailed(String error) {
    return 'Could not create the family key: $error';
  }

  @override
  String get commonVerify => 'Verify';

  @override
  String get commonLeave => 'Leave';

  @override
  String get relativeJustNow => 'just now';

  @override
  String relativeMinutesAgo(int count) {
    return '$count minutes ago';
  }

  @override
  String relativeHoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String get relativeYesterday => 'yesterday';

  @override
  String relativeDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get partnerVerifyTitle => 'Verify family key';

  @override
  String get partnerVerifyBody =>
      'Enter the 12 words. We will not show them; we only check that they match.';

  @override
  String get partnerVerifyOk => 'The family key matches.';

  @override
  String get partnerVerifyMismatch =>
      'This recovery phrase does not match this family key.';

  @override
  String get partnerRevealMissing =>
      'This family key is from before the recovery phrase (0.2) or arrived as a raw key. We cannot show the words. Create a new family key and have partner and kids re-link.';

  @override
  String get partnerUnlinkTitle => 'Unlink partner?';

  @override
  String get partnerUnlinkBody =>
      'All shared notes will be removed from this device. Your own tasks and private notes stay. Your partner does not lose the connection — only you leave the shared workspace.';

  @override
  String get partnerShareViaQr => 'Share family key via QR';

  @override
  String get partnerShareViaQrSubtitle =>
      'Have your partner scan the QR code to collaborate.';

  @override
  String get partnerScanKey => 'Scan family key';

  @override
  String get partnerScanKeySubtitle =>
      'Scan the QR or type your partner\'s 12 words.';

  @override
  String get partnerReshareKey => 'Share family key again';

  @override
  String get partnerReshareKeySubtitle =>
      'Share the key with a new device of your partner.';

  @override
  String get partnerVerifyPhrase => 'Verify recovery phrase';

  @override
  String get partnerVerifyPhraseSubtitle =>
      'Check that you still know the 12 words of the family key.';

  @override
  String get partnerShowKey => 'Show family key';

  @override
  String get partnerShowKeySubtitle =>
      'Show the 12 words on this device (screen lock).';

  @override
  String get partnerUnlink => 'Unlink partner';

  @override
  String get partnerUnlinkSubtitle =>
      'Remove the family key and shared notes from this device.';

  @override
  String get partnerStatusPaired => 'Partner linked — family key present';

  @override
  String get partnerStatusUnpaired =>
      'Partner not linked — scan or share the QR code to link';

  @override
  String partnerLastSeen(String when) {
    return 'Partner last seen $when';
  }

  @override
  String partnerLastSeenWarning(String when) {
    return 'Warning: partner last seen $when';
  }

  @override
  String partnerFingerprint(String fingerprint) {
    return 'Fingerprint $fingerprint';
  }

  @override
  String get kidsLinkApp => 'Link kids app';

  @override
  String get kidsLinkAppSubtitle => 'Have the kids app scan the QR code.';

  @override
  String get kidsEnrolledSection => 'ENROLLED KIDS';

  @override
  String get kidsNoneEnrolled => 'No kids linked yet.';

  @override
  String get kidsRemoveTooltip => 'Remove from family';

  @override
  String kidsRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String kidsRemoveBody(String name) {
    return '$name will be removed from the family list. The kids app will no longer receive family tasks unless linked again.';
  }

  @override
  String kidsEnrolledOn(String date) {
    return 'Linked on $date';
  }

  @override
  String kidsLastSeen(String when) {
    return 'Last seen $when';
  }

  @override
  String kidsLastSeenWarning(String when) {
    return 'Warning: last seen $when';
  }

  @override
  String get kidsEnrollTitle => 'Link kids app';

  @override
  String get kidsEnrollNameTitle => 'Child\'s name';

  @override
  String get kidsEnrollNameBody =>
      'Enter the name of the child you want to link.';

  @override
  String get kidsEnrollNameLabel => 'Child name';

  @override
  String get kidsEnrollContinueToQr => 'Continue to QR code';

  @override
  String kidsEnrollQrTitle(String name) {
    return 'QR code for $name';
  }

  @override
  String kidsEnrollQrBody(String name) {
    return 'Open the kids app on $name\'s device and scan this code.';
  }

  @override
  String get kidsEnrollWhatShared => 'What is shared?';

  @override
  String get kidsEnrollWhatSharedBody =>
      'This QR code contains the server, account, and family key — not the WebDAV password. Type that password once on the kids device. Only share the code with the kids app on a trusted device.';
}
