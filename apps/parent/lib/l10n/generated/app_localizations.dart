import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('nl'),
  ];

  /// No description provided for @navTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTasks;

  /// No description provided for @navNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get navNotes;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'(unknown)'**
  String get commonUnknown;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSand.
  ///
  /// In en, this message translates to:
  /// **'Sand'**
  String get themeSand;

  /// No description provided for @themeDusk.
  ///
  /// In en, this message translates to:
  /// **'Dusk'**
  String get themeDusk;

  /// No description provided for @themeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get themeNight;

  /// No description provided for @themeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Bright blue'**
  String get themeLightDesc;

  /// No description provided for @themeSandDesc.
  ///
  /// In en, this message translates to:
  /// **'Warm paper'**
  String get themeSandDesc;

  /// No description provided for @themeDuskDesc.
  ///
  /// In en, this message translates to:
  /// **'Blue-grey dark'**
  String get themeDuskDesc;

  /// No description provided for @themeNightDesc.
  ///
  /// In en, this message translates to:
  /// **'OLED black'**
  String get themeNightDesc;

  /// No description provided for @themeChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose theme'**
  String get themeChoose;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsSectionSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsSectionSync;

  /// No description provided for @settingsWebDavConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure WebDAV'**
  String get settingsWebDavConfigure;

  /// No description provided for @settingsWebDavConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsWebDavConnected;

  /// No description provided for @settingsWebDavConnectHint.
  ///
  /// In en, this message translates to:
  /// **'Connect to a Nextcloud or WebDAV server'**
  String get settingsWebDavConnectHint;

  /// No description provided for @settingsSectionFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get settingsSectionFamily;

  /// No description provided for @settingsPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get settingsPartner;

  /// No description provided for @settingsPartnerPaired.
  ///
  /// In en, this message translates to:
  /// **'Partner linked'**
  String get settingsPartnerPaired;

  /// No description provided for @settingsPartnerLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Link with your partner'**
  String get settingsPartnerLinkHint;

  /// No description provided for @settingsKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get settingsKids;

  /// No description provided for @settingsKidsLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Link the kids app'**
  String get settingsKidsLinkHint;

  /// No description provided for @settingsKidsEnrolledCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 kid linked} other{{count} kids linked}}'**
  String settingsKidsEnrolledCount(int count);

  /// No description provided for @settingsSectionVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get settingsSectionVault;

  /// No description provided for @settingsVerifyPhrase.
  ///
  /// In en, this message translates to:
  /// **'Verify recovery phrase'**
  String get settingsVerifyPhrase;

  /// No description provided for @settingsVerifyPhraseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check that you still know the 12 words. We will not show them.'**
  String get settingsVerifyPhraseSubtitle;

  /// No description provided for @settingsShowPhrase.
  ///
  /// In en, this message translates to:
  /// **'Show recovery phrase'**
  String get settingsShowPhrase;

  /// No description provided for @settingsShowPhraseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the 12 words on this device (screen lock).'**
  String get settingsShowPhraseSubtitle;

  /// No description provided for @settingsSectionBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsSectionBackup;

  /// No description provided for @settingsExportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get settingsExportBackup;

  /// No description provided for @settingsExportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted .kvault file. The recovery phrase is not included.'**
  String get settingsExportBackupSubtitle;

  /// No description provided for @settingsImportBackup.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get settingsImportBackup;

  /// No description provided for @settingsImportBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from .kvault with your 12 words'**
  String get settingsImportBackupSubtitle;

  /// No description provided for @notifServiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Notification service failed to start: {error}'**
  String notifServiceFailed(String error);

  /// No description provided for @notifDisabledBanner.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled. Turn them on in Settings to receive reminders.'**
  String get notifDisabledBanner;

  /// No description provided for @notifExactAlarmBanner.
  ///
  /// In en, this message translates to:
  /// **'Exact reminders are disabled. Allow \"Alarms & reminders\" for precise times.'**
  String get notifExactAlarmBanner;

  /// No description provided for @familyKeyScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan family key'**
  String get familyKeyScanTitle;

  /// No description provided for @familyKeyScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point at your partner\'s QR code'**
  String get familyKeyScanHint;

  /// No description provided for @familyKeyEnterPhrase.
  ///
  /// In en, this message translates to:
  /// **'Enter phrase'**
  String get familyKeyEnterPhrase;

  /// No description provided for @familyKeyFound.
  ///
  /// In en, this message translates to:
  /// **'Key found'**
  String get familyKeyFound;

  /// No description provided for @familyKeyPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get familyKeyPartner;

  /// No description provided for @familyKeyServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get familyKeyServer;

  /// No description provided for @familyKeyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get familyKeyFingerprint;

  /// No description provided for @familyKeyServerMismatch.
  ///
  /// In en, this message translates to:
  /// **'The server in the QR code ({scanned}) does not match your server ({current}). Are you sure you want to continue?'**
  String familyKeyServerMismatch(String scanned, String current);

  /// No description provided for @familyKeyConfirmPartner.
  ///
  /// In en, this message translates to:
  /// **'Is this the right partner? Check the username above.'**
  String get familyKeyConfirmPartner;

  /// No description provided for @familyKeyAlreadyPairedWarning.
  ///
  /// In en, this message translates to:
  /// **'You already have a family key. Importing a new one will make data encrypted with the current key unreadable until you sync again.'**
  String get familyKeyAlreadyPairedWarning;

  /// No description provided for @familyKeyEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter family key'**
  String get familyKeyEnterTitle;

  /// No description provided for @familyKeyEnterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your partner\'s 12 words. You will then see the fingerprint to verify.'**
  String get familyKeyEnterSubtitle;

  /// No description provided for @familyKeySaved.
  ///
  /// In en, this message translates to:
  /// **'Family key saved.'**
  String get familyKeySaved;

  /// No description provided for @familyKeySaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String familyKeySaveError(String error);

  /// No description provided for @familyKeyInvalidQr.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code: {error}'**
  String familyKeyInvalidQr(String error);

  /// No description provided for @familyKeyShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share family key'**
  String get familyKeyShareTitle;

  /// No description provided for @familyKeyShareLegacyBody.
  ///
  /// In en, this message translates to:
  /// **'Have your partner scan this QR code. This family key is from before the recovery phrase and has no 12 words.'**
  String get familyKeyShareLegacyBody;

  /// No description provided for @familyKeyShareBody.
  ///
  /// In en, this message translates to:
  /// **'Have your partner scan this QR code, or type the 12 words.'**
  String get familyKeyShareBody;

  /// No description provided for @familyKeyShareNoPassword.
  ///
  /// In en, this message translates to:
  /// **'The code does not include the WebDAV password. Check the fingerprint together.'**
  String get familyKeyShareNoPassword;

  /// No description provided for @familyKeyShareNoEntropy.
  ///
  /// In en, this message translates to:
  /// **'No recovery-phrase data on this device. Create a new family key.'**
  String get familyKeyShareNoEntropy;

  /// No description provided for @familyKeyShareFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint  {fingerprint}'**
  String familyKeyShareFingerprint(String fingerprint);

  /// No description provided for @familyKeyPartnerScanned.
  ///
  /// In en, this message translates to:
  /// **'Partner has scanned'**
  String get familyKeyPartnerScanned;

  /// No description provided for @familyKeyShared.
  ///
  /// In en, this message translates to:
  /// **'Family key shared'**
  String get familyKeyShared;

  /// No description provided for @vaultWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your vault'**
  String get vaultWelcomeTitle;

  /// No description provided for @vaultWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Kinetic Link stores tasks and notes with a 12-word recovery phrase. Write that phrase on paper. On this device you can show it again later (with screen lock).'**
  String get vaultWelcomeBody;

  /// No description provided for @vaultNewVault.
  ///
  /// In en, this message translates to:
  /// **'New vault'**
  String get vaultNewVault;

  /// No description provided for @vaultRestoreVault.
  ///
  /// In en, this message translates to:
  /// **'Restore vault'**
  String get vaultRestoreVault;

  /// No description provided for @vaultLegacyBackup.
  ///
  /// In en, this message translates to:
  /// **'Legacy backup (.kbak2)'**
  String get vaultLegacyBackup;

  /// No description provided for @vaultCreateVault.
  ///
  /// In en, this message translates to:
  /// **'Create vault'**
  String get vaultCreateVault;

  /// No description provided for @vaultRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase'**
  String get vaultRecoveryPhrase;

  /// No description provided for @vaultConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get vaultConfirm;

  /// No description provided for @vaultWriteWords.
  ///
  /// In en, this message translates to:
  /// **'Write these 12 words on paper and keep them safe. Without this phrase you cannot restore the vault on a new device.'**
  String get vaultWriteWords;

  /// No description provided for @vaultPhraseCopied.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase copied'**
  String get vaultPhraseCopied;

  /// No description provided for @vaultIWroteThemDown.
  ///
  /// In en, this message translates to:
  /// **'I wrote them down'**
  String get vaultIWroteThemDown;

  /// No description provided for @vaultQuizPrompt.
  ///
  /// In en, this message translates to:
  /// **'Fill in the requested words to confirm you saved the phrase.'**
  String get vaultQuizPrompt;

  /// No description provided for @vaultWordN.
  ///
  /// In en, this message translates to:
  /// **'Word {n}'**
  String vaultWordN(int n);

  /// No description provided for @vaultBackToWords.
  ///
  /// In en, this message translates to:
  /// **'Back to the words'**
  String get vaultBackToWords;

  /// No description provided for @vaultQuizMismatch.
  ///
  /// In en, this message translates to:
  /// **'Not all words match. Try again.'**
  String get vaultQuizMismatch;

  /// No description provided for @vaultCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the vault: {error}'**
  String vaultCreateFailed(String error);

  /// No description provided for @vaultCouldNotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file.'**
  String get vaultCouldNotReadFile;

  /// No description provided for @vaultInvalidLegacyBackup.
  ///
  /// In en, this message translates to:
  /// **'Invalid legacy backup: {error}'**
  String vaultInvalidLegacyBackup(String error);

  /// No description provided for @vaultRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore vault'**
  String get vaultRestoreTitle;

  /// No description provided for @vaultRestoreIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose how to restore the vault. The recovery phrase is the same in both cases.'**
  String get vaultRestoreIntro;

  /// No description provided for @vaultRestoreFromFile.
  ///
  /// In en, this message translates to:
  /// **'From file'**
  String get vaultRestoreFromFile;

  /// No description provided for @vaultRestoreFromWebDav.
  ///
  /// In en, this message translates to:
  /// **'From WebDAV'**
  String get vaultRestoreFromWebDav;

  /// No description provided for @vaultRestoreFromWebDavSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server, credentials, and 12 words. No file needed.'**
  String get vaultRestoreFromWebDavSubtitle;

  /// No description provided for @vaultRestoreFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from file'**
  String get vaultRestoreFileTitle;

  /// No description provided for @vaultRestoreFileBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery phrase, then choose the .kvault file.'**
  String get vaultRestoreFileBody;

  /// No description provided for @vaultChooseFileAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Choose file and restore'**
  String get vaultChooseFileAndRestore;

  /// No description provided for @vaultNoVaultOnServer.
  ///
  /// In en, this message translates to:
  /// **'No vault on this server. Create a new vault or choose a different server.'**
  String get vaultNoVaultOnServer;

  /// No description provided for @vaultPhraseMismatchServer.
  ///
  /// In en, this message translates to:
  /// **'This recovery phrase does not match the vault on this server.'**
  String get vaultPhraseMismatchServer;

  /// No description provided for @vaultRestoreWebDavTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from WebDAV'**
  String get vaultRestoreWebDavTitle;

  /// No description provided for @vaultRestoreWebDavBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your server and enter the same 12 words used when creating the vault.'**
  String get vaultRestoreWebDavBody;

  /// No description provided for @vaultServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get vaultServerUrl;

  /// No description provided for @vaultUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get vaultUsername;

  /// No description provided for @vaultPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get vaultPassword;

  /// No description provided for @vaultUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock vault'**
  String get vaultUnlock;

  /// No description provided for @vaultPhraseFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase (12 words)'**
  String get vaultPhraseFieldLabel;

  /// No description provided for @vaultMigrateTitle.
  ///
  /// In en, this message translates to:
  /// **'New recovery phrase'**
  String get vaultMigrateTitle;

  /// No description provided for @vaultMigrateBody.
  ///
  /// In en, this message translates to:
  /// **'Your current key is random (version 0.2) and cannot become 12 words. Tasks and notes on this device stay. We will create a new recovery phrase. On the next sync, personal files are re-encrypted. The family key stays the same — partner and kids do not need to re-link.'**
  String get vaultMigrateBody;

  /// No description provided for @vaultMigrateActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate new recovery phrase'**
  String get vaultMigrateActivate;

  /// No description provided for @vaultMigrateHeadline.
  ///
  /// In en, this message translates to:
  /// **'Write down these new 12 words. The old key will no longer work for WebDAV or a .kvault.'**
  String get vaultMigrateHeadline;

  /// No description provided for @vaultRestoreFromFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'12 words + encrypted .kvault file. No internet needed.'**
  String get vaultRestoreFromFileSubtitle;

  /// No description provided for @vaultBiometricsReason.
  ///
  /// In en, this message translates to:
  /// **'Show the recovery phrase on this device'**
  String get vaultBiometricsReason;

  /// No description provided for @vaultNoScreenLockTitle.
  ///
  /// In en, this message translates to:
  /// **'No screen lock'**
  String get vaultNoScreenLockTitle;

  /// No description provided for @vaultNoScreenLockBody.
  ///
  /// In en, this message translates to:
  /// **'This device has no Face ID, fingerprint, or PIN. Anyone with access to the app can see the words. Continue?'**
  String get vaultNoScreenLockBody;

  /// No description provided for @vaultShowAnyway.
  ///
  /// In en, this message translates to:
  /// **'Show anyway'**
  String get vaultShowAnyway;

  /// No description provided for @vaultRevealWarning.
  ///
  /// In en, this message translates to:
  /// **'Write the words down again on paper if you lost your copy. Do not leave this screen open.'**
  String get vaultRevealWarning;

  /// No description provided for @familyCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Family key'**
  String get familyCreateTitle;

  /// No description provided for @familyCreateWriteWords.
  ///
  /// In en, this message translates to:
  /// **'Write these 12 words down. They belong to the family key you share with your partner. We do not store the words.'**
  String get familyCreateWriteWords;

  /// No description provided for @familyCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the family key: {error}'**
  String familyCreateFailed(String error);

  /// No description provided for @commonVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get commonVerify;

  /// No description provided for @commonLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get commonLeave;

  /// No description provided for @relativeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeJustNow;

  /// No description provided for @relativeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String relativeMinutesAgo(int count);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String relativeHoursAgo(int count);

  /// No description provided for @relativeYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get relativeYesterday;

  /// No description provided for @relativeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String relativeDaysAgo(int count);

  /// No description provided for @partnerVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify family key'**
  String get partnerVerifyTitle;

  /// No description provided for @partnerVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 12 words. We will not show them; we only check that they match.'**
  String get partnerVerifyBody;

  /// No description provided for @partnerVerifyOk.
  ///
  /// In en, this message translates to:
  /// **'The family key matches.'**
  String get partnerVerifyOk;

  /// No description provided for @partnerVerifyMismatch.
  ///
  /// In en, this message translates to:
  /// **'This recovery phrase does not match this family key.'**
  String get partnerVerifyMismatch;

  /// No description provided for @partnerRevealMissing.
  ///
  /// In en, this message translates to:
  /// **'This family key is from before the recovery phrase (0.2) or arrived as a raw key. We cannot show the words. Create a new family key and have partner and kids re-link.'**
  String get partnerRevealMissing;

  /// No description provided for @partnerUnlinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlink partner?'**
  String get partnerUnlinkTitle;

  /// No description provided for @partnerUnlinkBody.
  ///
  /// In en, this message translates to:
  /// **'All shared notes will be removed from this device. Your own tasks and private notes stay. Your partner does not lose the connection — only you leave the shared workspace.'**
  String get partnerUnlinkBody;

  /// No description provided for @partnerShareViaQr.
  ///
  /// In en, this message translates to:
  /// **'Share family key via QR'**
  String get partnerShareViaQr;

  /// No description provided for @partnerShareViaQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Have your partner scan the QR code to collaborate.'**
  String get partnerShareViaQrSubtitle;

  /// No description provided for @partnerScanKey.
  ///
  /// In en, this message translates to:
  /// **'Scan family key'**
  String get partnerScanKey;

  /// No description provided for @partnerScanKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR or type your partner\'s 12 words.'**
  String get partnerScanKeySubtitle;

  /// No description provided for @partnerReshareKey.
  ///
  /// In en, this message translates to:
  /// **'Share family key again'**
  String get partnerReshareKey;

  /// No description provided for @partnerReshareKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share the key with a new device of your partner.'**
  String get partnerReshareKeySubtitle;

  /// No description provided for @partnerVerifyPhrase.
  ///
  /// In en, this message translates to:
  /// **'Verify recovery phrase'**
  String get partnerVerifyPhrase;

  /// No description provided for @partnerVerifyPhraseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check that you still know the 12 words of the family key.'**
  String get partnerVerifyPhraseSubtitle;

  /// No description provided for @partnerShowKey.
  ///
  /// In en, this message translates to:
  /// **'Show family key'**
  String get partnerShowKey;

  /// No description provided for @partnerShowKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the 12 words on this device (screen lock).'**
  String get partnerShowKeySubtitle;

  /// No description provided for @partnerUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink partner'**
  String get partnerUnlink;

  /// No description provided for @partnerUnlinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove the family key and shared notes from this device.'**
  String get partnerUnlinkSubtitle;

  /// No description provided for @partnerStatusPaired.
  ///
  /// In en, this message translates to:
  /// **'Partner linked — family key present'**
  String get partnerStatusPaired;

  /// No description provided for @partnerStatusUnpaired.
  ///
  /// In en, this message translates to:
  /// **'Partner not linked — scan or share the QR code to link'**
  String get partnerStatusUnpaired;

  /// No description provided for @partnerLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Partner last seen {when}'**
  String partnerLastSeen(String when);

  /// No description provided for @partnerLastSeenWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: partner last seen {when}'**
  String partnerLastSeenWarning(String when);

  /// No description provided for @partnerFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint {fingerprint}'**
  String partnerFingerprint(String fingerprint);

  /// No description provided for @kidsLinkApp.
  ///
  /// In en, this message translates to:
  /// **'Link kids app'**
  String get kidsLinkApp;

  /// No description provided for @kidsLinkAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Have the kids app scan the QR code.'**
  String get kidsLinkAppSubtitle;

  /// No description provided for @kidsEnrolledSection.
  ///
  /// In en, this message translates to:
  /// **'ENROLLED KIDS'**
  String get kidsEnrolledSection;

  /// No description provided for @kidsNoneEnrolled.
  ///
  /// In en, this message translates to:
  /// **'No kids linked yet.'**
  String get kidsNoneEnrolled;

  /// No description provided for @kidsRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from family'**
  String get kidsRemoveTooltip;

  /// No description provided for @kidsRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String kidsRemoveTitle(String name);

  /// No description provided for @kidsRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from the family list. The kids app will no longer receive family tasks unless linked again.'**
  String kidsRemoveBody(String name);

  /// No description provided for @kidsEnrolledOn.
  ///
  /// In en, this message translates to:
  /// **'Linked on {date}'**
  String kidsEnrolledOn(String date);

  /// No description provided for @kidsLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {when}'**
  String kidsLastSeen(String when);

  /// No description provided for @kidsLastSeenWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: last seen {when}'**
  String kidsLastSeenWarning(String when);

  /// No description provided for @kidsEnrollTitle.
  ///
  /// In en, this message translates to:
  /// **'Link kids app'**
  String get kidsEnrollTitle;

  /// No description provided for @kidsEnrollNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Child\'s name'**
  String get kidsEnrollNameTitle;

  /// No description provided for @kidsEnrollNameBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the name of the child you want to link.'**
  String get kidsEnrollNameBody;

  /// No description provided for @kidsEnrollNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Child name'**
  String get kidsEnrollNameLabel;

  /// No description provided for @kidsEnrollContinueToQr.
  ///
  /// In en, this message translates to:
  /// **'Continue to QR code'**
  String get kidsEnrollContinueToQr;

  /// No description provided for @kidsEnrollQrTitle.
  ///
  /// In en, this message translates to:
  /// **'QR code for {name}'**
  String kidsEnrollQrTitle(String name);

  /// No description provided for @kidsEnrollQrBody.
  ///
  /// In en, this message translates to:
  /// **'Open the kids app on {name}\'s device and scan this code.'**
  String kidsEnrollQrBody(String name);

  /// No description provided for @kidsEnrollWhatShared.
  ///
  /// In en, this message translates to:
  /// **'What is shared?'**
  String get kidsEnrollWhatShared;

  /// No description provided for @kidsEnrollWhatSharedBody.
  ///
  /// In en, this message translates to:
  /// **'This QR code contains the server, account, and family key — not the WebDAV password. Type that password once on the kids device. Only share the code with the kids app on a trusted device.'**
  String get kidsEnrollWhatSharedBody;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageDutch.
  ///
  /// In en, this message translates to:
  /// **'Nederlands'**
  String get settingsLanguageDutch;

  /// No description provided for @settingsLanguageChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get settingsLanguageChoose;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSend;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// No description provided for @commonCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonCloseAction;

  /// No description provided for @commonExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get commonExporting;

  /// No description provided for @commonImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get commonImporting;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get commonEveryone;

  /// No description provided for @commonTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commonTitle;

  /// No description provided for @commonNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotes;

  /// No description provided for @commonContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get commonContent;

  /// No description provided for @commonLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get commonLow;

  /// No description provided for @commonMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get commonMedium;

  /// No description provided for @commonHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get commonHigh;

  /// No description provided for @commonPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get commonPrivate;

  /// No description provided for @commonShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get commonShared;

  /// No description provided for @commonKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get commonKids;

  /// No description provided for @commonPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner'**
  String get commonPartner;

  /// No description provided for @commonReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get commonReminder;

  /// No description provided for @commonTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get commonTime;

  /// No description provided for @commonCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get commonCategory;

  /// No description provided for @commonPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get commonPriority;

  /// No description provided for @commonNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get commonNoCategory;

  /// No description provided for @commonSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String commonSaveError(String error);

  /// No description provided for @commonDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting: {error}'**
  String commonDeleteError(String error);

  /// No description provided for @relativeWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} weeks ago'**
  String relativeWeeksAgo(int count);

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// No description provided for @dateTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dateTomorrow;

  /// No description provided for @dateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dateYesterday;

  /// No description provided for @dateDaysOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count}d overdue'**
  String dateDaysOverdue(int count);

  /// No description provided for @dateInDays.
  ///
  /// In en, this message translates to:
  /// **'In {count} days'**
  String dateInDays(int count);

  /// No description provided for @dateWeekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get dateWeekdayMonday;

  /// No description provided for @dateWeekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get dateWeekdayTuesday;

  /// No description provided for @dateWeekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get dateWeekdayWednesday;

  /// No description provided for @dateWeekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get dateWeekdayThursday;

  /// No description provided for @dateWeekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get dateWeekdayFriday;

  /// No description provided for @dateWeekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get dateWeekdaySaturday;

  /// No description provided for @dateWeekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get dateWeekdaySunday;

  /// No description provided for @dateMonthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get dateMonthJan;

  /// No description provided for @dateMonthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get dateMonthFeb;

  /// No description provided for @dateMonthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get dateMonthMar;

  /// No description provided for @dateMonthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get dateMonthApr;

  /// No description provided for @dateMonthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get dateMonthMay;

  /// No description provided for @dateMonthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get dateMonthJun;

  /// No description provided for @dateMonthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get dateMonthJul;

  /// No description provided for @dateMonthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get dateMonthAug;

  /// No description provided for @dateMonthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get dateMonthSep;

  /// No description provided for @dateMonthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get dateMonthOct;

  /// No description provided for @dateMonthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get dateMonthNov;

  /// No description provided for @dateMonthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get dateMonthDec;

  /// No description provided for @connNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get connNotConnected;

  /// No description provided for @connNotConnectedSince.
  ///
  /// In en, this message translates to:
  /// **'Not connected since {when}'**
  String connNotConnectedSince(String when);

  /// No description provided for @connUnknownNoSync.
  ///
  /// In en, this message translates to:
  /// **'Connection unknown (no sync)'**
  String get connUnknownNoSync;

  /// No description provided for @connStale.
  ///
  /// In en, this message translates to:
  /// **'Connection stale ({when})'**
  String connStale(String when);

  /// No description provided for @connConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connConnected;

  /// No description provided for @connConnectedSince.
  ///
  /// In en, this message translates to:
  /// **'Connected ({when})'**
  String connConnectedSince(String when);

  /// No description provided for @notifChannelName.
  ///
  /// In en, this message translates to:
  /// **'Task reminders'**
  String get notifChannelName;

  /// No description provided for @notifChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Reminders for tasks and assignments'**
  String get notifChannelDesc;

  /// No description provided for @notifReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get notifReminderTitle;

  /// No description provided for @backupNoVault.
  ///
  /// In en, this message translates to:
  /// **'No vault on this device.'**
  String get backupNoVault;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved: {path}'**
  String backupSaved(String path);

  /// No description provided for @backupExportError.
  ///
  /// In en, this message translates to:
  /// **'Error exporting: {error}'**
  String backupExportError(String error);

  /// No description provided for @backupVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify recovery phrase'**
  String get backupVerifyTitle;

  /// No description provided for @backupVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your 12 words. We will not show the phrase; we only check that it matches.'**
  String get backupVerifyBody;

  /// No description provided for @backupVerifyOk.
  ///
  /// In en, this message translates to:
  /// **'The recovery phrase matches.'**
  String get backupVerifyOk;

  /// No description provided for @backupVerifyMismatch.
  ///
  /// In en, this message translates to:
  /// **'This recovery phrase does not belong to this vault.'**
  String get backupVerifyMismatch;

  /// No description provided for @backupRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase'**
  String get backupRevealTitle;

  /// No description provided for @backupRevealMissing.
  ///
  /// In en, this message translates to:
  /// **'We cannot show the words again on this device. Use your paper copy, or restore the vault with the 12 words.'**
  String get backupRevealMissing;

  /// No description provided for @backupImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get backupImportTitle;

  /// No description provided for @backupImportBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 12 words of the vault inside the .kvault file. This replaces your current tasks and notes.'**
  String get backupImportBody;

  /// No description provided for @backupCouldNotReadFile.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file.'**
  String get backupCouldNotReadFile;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored successfully.'**
  String get backupRestored;

  /// No description provided for @backupInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file: {error}'**
  String backupInvalidFile(String error);

  /// No description provided for @backupImportError.
  ///
  /// In en, this message translates to:
  /// **'Error importing: {error}'**
  String backupImportError(String error);

  /// No description provided for @backupRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring backup…'**
  String get backupRestoring;

  /// No description provided for @webdavSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up WebDAV'**
  String get webdavSetupTitle;

  /// No description provided for @webdavUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the server URL'**
  String get webdavUrlRequired;

  /// No description provided for @webdavUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the username'**
  String get webdavUsernameRequired;

  /// No description provided for @webdavPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the password'**
  String get webdavPasswordRequired;

  /// No description provided for @webdavTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get webdavTestConnection;

  /// No description provided for @webdavTestingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing connection…'**
  String get webdavTestingConnection;

  /// No description provided for @webdavConnectionOk.
  ///
  /// In en, this message translates to:
  /// **'Connection succeeded'**
  String get webdavConnectionOk;

  /// No description provided for @webdavTestFirst.
  ///
  /// In en, this message translates to:
  /// **'Test the connection before saving.'**
  String get webdavTestFirst;

  /// No description provided for @webdavCreateVaultFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a vault before linking WebDAV.'**
  String get webdavCreateVaultFirst;

  /// No description provided for @webdavPhraseMismatchServer.
  ///
  /// In en, this message translates to:
  /// **'This server already has a vault that does not match your recovery phrase.'**
  String get webdavPhraseMismatchServer;

  /// No description provided for @webdavConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'WebDAV configuration saved.'**
  String get webdavConfigSaved;

  /// No description provided for @webdavSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String webdavSaveError(String error);

  /// No description provided for @webdavMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Existing data found'**
  String get webdavMigrationTitle;

  /// No description provided for @webdavMigrationIntro.
  ///
  /// In en, this message translates to:
  /// **'The WebDAV server already has encrypted files:'**
  String get webdavMigrationIntro;

  /// No description provided for @webdavMigrationTaskFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{  • 1 task file} other{  • {count} task files}}'**
  String webdavMigrationTaskFiles(int count);

  /// No description provided for @webdavMigrationNoteFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{  • 1 note file} other{  • {count} note files}}'**
  String webdavMigrationNoteFiles(int count);

  /// No description provided for @webdavMigrationChoose.
  ///
  /// In en, this message translates to:
  /// **'These files are encrypted with a vault. Choose how to continue:'**
  String get webdavMigrationChoose;

  /// No description provided for @webdavMigrationCleanOption.
  ///
  /// In en, this message translates to:
  /// **'1. Clean install — remove the old files on the server and start fresh.'**
  String get webdavMigrationCleanOption;

  /// No description provided for @webdavMigrationImportOption.
  ///
  /// In en, this message translates to:
  /// **'2. Import backup — select a .kvault file. This vault\'s recovery phrase unlocks the file.'**
  String get webdavMigrationImportOption;

  /// No description provided for @webdavMigrationClean.
  ///
  /// In en, this message translates to:
  /// **'Clean install'**
  String get webdavMigrationClean;

  /// No description provided for @webdavMigrationImport.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get webdavMigrationImport;

  /// No description provided for @webdavBackupRestoredSync.
  ///
  /// In en, this message translates to:
  /// **'Backup restored. The app will now sync with the server.'**
  String get webdavBackupRestoredSync;

  /// No description provided for @webdavRestoreError.
  ///
  /// In en, this message translates to:
  /// **'Error restoring backup: {error}'**
  String webdavRestoreError(String error);

  /// No description provided for @webdavMigrationCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Migration check failed: {error}'**
  String webdavMigrationCheckFailed(String error);

  /// No description provided for @webdavFilesDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} files deleted.'**
  String webdavFilesDeleted(int count);

  /// No description provided for @webdavCleanupError.
  ///
  /// In en, this message translates to:
  /// **'Error cleaning up: {error}'**
  String webdavCleanupError(String error);

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTitle;

  /// No description provided for @tasksCompletedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks'**
  String get tasksCompletedTooltip;

  /// No description provided for @tasksTabPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get tasksTabPrivate;

  /// No description provided for @tasksTabSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get tasksTabSuggestions;

  /// No description provided for @tasksTabKids.
  ///
  /// In en, this message translates to:
  /// **'Kids'**
  String get tasksTabKids;

  /// No description provided for @tasksSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed, tap to retry.'**
  String get tasksSyncFailed;

  /// No description provided for @tasksSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get tasksSyncing;

  /// No description provided for @tasksForYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get tasksForYou;

  /// No description provided for @tasksForPartner.
  ///
  /// In en, this message translates to:
  /// **'For partner'**
  String get tasksForPartner;

  /// No description provided for @tasksFromPartner.
  ///
  /// In en, this message translates to:
  /// **'From partner'**
  String get tasksFromPartner;

  /// No description provided for @tasksRefreshSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Refresh suggestions'**
  String get tasksRefreshSuggestions;

  /// No description provided for @tasksAddReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get tasksAddReminder;

  /// No description provided for @tasksAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get tasksAddTask;

  /// No description provided for @tasksToPartner.
  ///
  /// In en, this message translates to:
  /// **'To partner'**
  String get tasksToPartner;

  /// No description provided for @tasksNoPartnerSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No partner suggestions'**
  String get tasksNoPartnerSuggestions;

  /// No description provided for @tasksNoPartnerSuggestionsHint.
  ///
  /// In en, this message translates to:
  /// **'Your partner has not suggested any tasks yet'**
  String get tasksNoPartnerSuggestionsHint;

  /// No description provided for @tasksViaSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Via suggestion'**
  String get tasksViaSuggestion;

  /// No description provided for @tasksReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get tasksReject;

  /// No description provided for @tasksAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get tasksAccept;

  /// No description provided for @tasksProposalAccepted.
  ///
  /// In en, this message translates to:
  /// **'Suggestion accepted'**
  String get tasksProposalAccepted;

  /// No description provided for @tasksProposalRejected.
  ///
  /// In en, this message translates to:
  /// **'Suggestion rejected'**
  String get tasksProposalRejected;

  /// No description provided for @tasksLoadProposalsError.
  ///
  /// In en, this message translates to:
  /// **'Error loading suggestions'**
  String get tasksLoadProposalsError;

  /// No description provided for @tasksXpResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset XP for {name}?'**
  String tasksXpResetTitle(String name);

  /// No description provided for @tasksXpResetBody.
  ///
  /// In en, this message translates to:
  /// **'This resets the XP counter to 0. The assignments stay.'**
  String get tasksXpResetBody;

  /// No description provided for @tasksXpResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get tasksXpResetAction;

  /// No description provided for @tasksXpResetDone.
  ///
  /// In en, this message translates to:
  /// **'XP reset for {name}'**
  String tasksXpResetDone(String name);

  /// No description provided for @tasksXpResetError.
  ///
  /// In en, this message translates to:
  /// **'Error resetting: {error}'**
  String tasksXpResetError(String error);

  /// No description provided for @tasksLoadKidsError.
  ///
  /// In en, this message translates to:
  /// **'Error loading kids assignments'**
  String get tasksLoadKidsError;

  /// No description provided for @tasksNoKidsAssignments.
  ///
  /// In en, this message translates to:
  /// **'No kids assignments'**
  String get tasksNoKidsAssignments;

  /// No description provided for @tasksNoKidsAssignmentsHint.
  ///
  /// In en, this message translates to:
  /// **'Send a task to the kids app to see it here.'**
  String get tasksNoKidsAssignmentsHint;

  /// No description provided for @tasksResetXp.
  ///
  /// In en, this message translates to:
  /// **'Reset XP'**
  String get tasksResetXp;

  /// No description provided for @tasksDoneOn.
  ///
  /// In en, this message translates to:
  /// **'Done on {day}/{month}'**
  String tasksDoneOn(int day, int month);

  /// No description provided for @tasksCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks'**
  String get tasksCompletedTitle;

  /// No description provided for @tasksDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get tasksDeleteAll;

  /// No description provided for @tasksDeleteCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete completed tasks'**
  String get tasksDeleteCompletedTitle;

  /// No description provided for @tasksDeleteCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all completed tasks? This cannot be undone.'**
  String get tasksDeleteCompletedBody;

  /// No description provided for @tasksEmptySuggestionsPartner.
  ///
  /// In en, this message translates to:
  /// **'Suggestions from the smart planner and proposals from your partner appear here'**
  String get tasksEmptySuggestionsPartner;

  /// No description provided for @tasksEmptySuggestionsSolo.
  ///
  /// In en, this message translates to:
  /// **'Suggestions from the smart planner based on your habits appear here'**
  String get tasksEmptySuggestionsSolo;

  /// No description provided for @tasksNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No suggestions'**
  String get tasksNoSuggestions;

  /// No description provided for @tasksAllDone.
  ///
  /// In en, this message translates to:
  /// **'All done!'**
  String get tasksAllDone;

  /// No description provided for @tasksNoOpenTasks.
  ///
  /// In en, this message translates to:
  /// **'You have no open tasks'**
  String get tasksNoOpenTasks;

  /// No description provided for @tasksNoCompleted.
  ///
  /// In en, this message translates to:
  /// **'No completed tasks'**
  String get tasksNoCompleted;

  /// No description provided for @tasksNoCompletedHint.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks appear here'**
  String get tasksNoCompletedHint;

  /// No description provided for @tasksAssignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get tasksAssignment;

  /// No description provided for @taskDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get taskDeleteTitle;

  /// No description provided for @taskDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be permanently deleted. This cannot be undone.'**
  String taskDeleteBody(String title);

  /// No description provided for @taskForwardTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward task'**
  String get taskForwardTitle;

  /// No description provided for @taskAssignmentCreated.
  ///
  /// In en, this message translates to:
  /// **'Assignment created ✓'**
  String get taskAssignmentCreated;

  /// No description provided for @taskNoConnectedFamily.
  ///
  /// In en, this message translates to:
  /// **'No connected partner or kids'**
  String get taskNoConnectedFamily;

  /// No description provided for @taskStaleConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection stale'**
  String get taskStaleConnectionTitle;

  /// No description provided for @taskStalePartnerBody.
  ///
  /// In en, this message translates to:
  /// **'Your partner was last seen {status}. Send anyway?'**
  String taskStalePartnerBody(String status);

  /// No description provided for @taskStaleKidBody.
  ///
  /// In en, this message translates to:
  /// **'{name} was last seen {status}. Send anyway?'**
  String taskStaleKidBody(String name, String status);

  /// No description provided for @taskSendAnyway.
  ///
  /// In en, this message translates to:
  /// **'Send anyway'**
  String get taskSendAnyway;

  /// No description provided for @taskSendToPartnerTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to partner?'**
  String get taskSendToPartnerTitle;

  /// No description provided for @taskSendToPartnerBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be sent as a proposal to your partner and removed from your list once they accept it.'**
  String taskSendToPartnerBody(String title);

  /// No description provided for @taskSendToKidTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to {name}?'**
  String taskSendToKidTitle(String name);

  /// No description provided for @taskSendToKidBody.
  ///
  /// In en, this message translates to:
  /// **'The task disappears from your list once the child completes it.'**
  String get taskSendToKidBody;

  /// No description provided for @taskSendToKidLead.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be sent as an assignment to {name}.'**
  String taskSendToKidLead(String title, String name);

  /// No description provided for @taskXpReward.
  ///
  /// In en, this message translates to:
  /// **'XP reward:'**
  String get taskXpReward;

  /// No description provided for @taskNameHint.
  ///
  /// In en, this message translates to:
  /// **'Task name'**
  String get taskNameHint;

  /// No description provided for @taskAddTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get taskAddTime;

  /// No description provided for @taskAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get taskAddCategory;

  /// No description provided for @taskRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get taskRepeat;

  /// No description provided for @taskForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get taskForward;

  /// No description provided for @taskRecurrenceNone.
  ///
  /// In en, this message translates to:
  /// **'No recurrence'**
  String get taskRecurrenceNone;

  /// No description provided for @taskRecurrenceDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get taskRecurrenceDaily;

  /// No description provided for @taskRecurrenceWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get taskRecurrenceWeekdays;

  /// No description provided for @taskRecurrenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get taskRecurrenceWeekly;

  /// No description provided for @taskRecurrenceBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Biweekly'**
  String get taskRecurrenceBiweekly;

  /// No description provided for @taskRecurrenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get taskRecurrenceMonthly;

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// No description provided for @notesTabPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get notesTabPrivate;

  /// No description provided for @notesTabShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get notesTabShared;

  /// No description provided for @notesNewTooltip.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get notesNewTooltip;

  /// No description provided for @notesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading notes'**
  String get notesLoadError;

  /// No description provided for @notesEmptyShared.
  ///
  /// In en, this message translates to:
  /// **'No shared notes'**
  String get notesEmptyShared;

  /// No description provided for @notesEmptyPrivate.
  ///
  /// In en, this message translates to:
  /// **'No private notes'**
  String get notesEmptyPrivate;

  /// No description provided for @notesEmptySharedHint.
  ///
  /// In en, this message translates to:
  /// **'Notes shared with your partner appear here'**
  String get notesEmptySharedHint;

  /// No description provided for @notesEmptyPrivateHint.
  ///
  /// In en, this message translates to:
  /// **'Your private notes appear here'**
  String get notesEmptyPrivateHint;

  /// No description provided for @notesSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get notesSaved;

  /// No description provided for @notesSharedBadge.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get notesSharedBadge;

  /// No description provided for @notesTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get notesTitleRequired;

  /// No description provided for @notesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete note?'**
  String get notesDeleteTitle;

  /// No description provided for @notesDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'You cannot undo this.'**
  String get notesDeleteBody;

  /// No description provided for @notesSharedWithPartner.
  ///
  /// In en, this message translates to:
  /// **'Shared with partner'**
  String get notesSharedWithPartner;

  /// No description provided for @suggestWebDavRequired.
  ///
  /// In en, this message translates to:
  /// **'Link WebDAV first to send a suggestion.'**
  String get suggestWebDavRequired;

  /// No description provided for @suggestPartnerSeesTitle.
  ///
  /// In en, this message translates to:
  /// **'What your partner sees'**
  String get suggestPartnerSeesTitle;

  /// No description provided for @suggestPartnerSeesGeneric.
  ///
  /// In en, this message translates to:
  /// **'Intentionally generic — no private titles or notes.'**
  String get suggestPartnerSeesGeneric;

  /// No description provided for @suggestPartnerSeesFull.
  ///
  /// In en, this message translates to:
  /// **'The title and any notes from this suggestion will be included.'**
  String get suggestPartnerSeesFull;

  /// No description provided for @suggestSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get suggestSend;

  /// No description provided for @suggestSent.
  ///
  /// In en, this message translates to:
  /// **'Suggestion sent to partner'**
  String get suggestSent;

  /// No description provided for @suggestSnoozeTitle.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get suggestSnoozeTitle;

  /// No description provided for @suggestSnoozeBody.
  ///
  /// In en, this message translates to:
  /// **'Snooze this suggestion for 7 days?'**
  String get suggestSnoozeBody;

  /// No description provided for @suggestSnoozeAction.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get suggestSnoozeAction;

  /// No description provided for @suggestAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get suggestAdd;

  /// No description provided for @suggestReasonHabit.
  ///
  /// In en, this message translates to:
  /// **'Habit'**
  String get suggestReasonHabit;

  /// No description provided for @suggestReasonPartner.
  ///
  /// In en, this message translates to:
  /// **'Partner complement'**
  String get suggestReasonPartner;

  /// No description provided for @suggestReasonSeasonal.
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get suggestReasonSeasonal;

  /// No description provided for @suggestReasonLoadBalance.
  ///
  /// In en, this message translates to:
  /// **'Load balance'**
  String get suggestReasonLoadBalance;

  /// No description provided for @suggestReasonStale.
  ///
  /// In en, this message translates to:
  /// **'Open task'**
  String get suggestReasonStale;

  /// No description provided for @suggestReasonCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get suggestReasonCalendar;

  /// No description provided for @categoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryTitle;

  /// No description provided for @categoryNewHint.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoryNewHint;

  /// No description provided for @categoryNewAction.
  ///
  /// In en, this message translates to:
  /// **'New category…'**
  String get categoryNewAction;

  /// No description provided for @quickAddHint.
  ///
  /// In en, this message translates to:
  /// **'New task…'**
  String get quickAddHint;

  /// No description provided for @quickAddMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get quickAddMoreOptions;

  /// No description provided for @timeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid time (00:00 – 23:59).'**
  String get timeInvalid;

  /// No description provided for @timeOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get timeOk;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
