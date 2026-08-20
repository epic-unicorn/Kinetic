// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get navTasks => 'Taken';

  @override
  String get navNotes => 'Notities';

  @override
  String get navSettings => 'Instellingen';

  @override
  String get commonCancel => 'Annuleren';

  @override
  String get commonSave => 'Opslaan';

  @override
  String get commonSaving => 'Opslaan…';

  @override
  String get commonDelete => 'Verwijderen';

  @override
  String get commonOk => 'OK';

  @override
  String get commonError => 'Fout';

  @override
  String get commonImport => 'Importeren';

  @override
  String get commonContinue => 'Doorgaan';

  @override
  String get commonClose => 'Sluiten';

  @override
  String get commonBack => 'Terug';

  @override
  String get commonCopy => 'Kopiëren';

  @override
  String get commonUnknown => '(onbekend)';

  @override
  String get themeLight => 'Licht';

  @override
  String get themeSand => 'Zand';

  @override
  String get themeDusk => 'Schemer';

  @override
  String get themeNight => 'Nacht';

  @override
  String get themeLightDesc => 'Helder blauw';

  @override
  String get themeSandDesc => 'Warm papier';

  @override
  String get themeDuskDesc => 'Blauw-grijs donker';

  @override
  String get themeNightDesc => 'OLED zwart';

  @override
  String get themeChoose => 'Thema kiezen';

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get settingsSectionAppearance => 'Uiterlijk';

  @override
  String get settingsTheme => 'Thema';

  @override
  String get settingsSectionSync => 'Synchronisatie';

  @override
  String get settingsWebDavConfigure => 'WebDAV configureren';

  @override
  String get settingsWebDavConnected => 'Verbonden';

  @override
  String get settingsWebDavConnectHint =>
      'Verbind met een Nextcloud- of WebDAV-server';

  @override
  String get settingsSectionFamily => 'Familie';

  @override
  String get settingsPartner => 'Partner';

  @override
  String get settingsPartnerPaired => 'Partner gekoppeld';

  @override
  String get settingsPartnerLinkHint => 'Koppel met je partner';

  @override
  String get settingsKids => 'Kinderen';

  @override
  String get settingsKidsLinkHint => 'Koppel de kinderenapp';

  @override
  String settingsKidsEnrolledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kinderen gekoppeld',
      one: '1 kind gekoppeld',
    );
    return '$_temp0';
  }

  @override
  String get settingsSectionVault => 'Kluis';

  @override
  String get settingsVerifyPhrase => 'Herstelzin controleren';

  @override
  String get settingsVerifyPhraseSubtitle =>
      'Controleer of je de 12 woorden nog kent. We tonen ze niet.';

  @override
  String get settingsShowPhrase => 'Herstelzin tonen';

  @override
  String get settingsShowPhraseSubtitle =>
      'Toon de 12 woorden op dit apparaat (schermvergrendeling).';

  @override
  String get settingsSectionBackup => 'Back-up & Herstel';

  @override
  String get settingsExportBackup => 'Back-up exporteren';

  @override
  String get settingsExportBackupSubtitle =>
      'Versleuteld .kvault-bestand. De herstelzin zit er niet in.';

  @override
  String get settingsImportBackup => 'Back-up importeren';

  @override
  String get settingsImportBackupSubtitle =>
      'Herstel vanuit .kvault met je 12 woorden';

  @override
  String notifServiceFailed(String error) {
    return 'Meldingenservice kon niet starten: $error';
  }

  @override
  String get notifDisabledBanner =>
      'Meldingen zijn uitgeschakeld. Zet ze aan in Instellingen om herinneringen te ontvangen.';

  @override
  String get notifExactAlarmBanner =>
      'Precieze herinneringen zijn uitgeschakeld. Sta \"Alarmen & herinneringen\" toe voor exacte tijden.';

  @override
  String get familyKeyScanTitle => 'Familiesleutel scannen';

  @override
  String get familyKeyScanHint => 'Richt op de QR-code van je partner';

  @override
  String get familyKeyEnterPhrase => 'Zin invoeren';

  @override
  String get familyKeyFound => 'Sleutel gevonden';

  @override
  String get familyKeyPartner => 'Partner';

  @override
  String get familyKeyServer => 'Server';

  @override
  String get familyKeyFingerprint => 'Vingerafdruk';

  @override
  String familyKeyServerMismatch(String scanned, String current) {
    return 'De server in de QR-code ($scanned) komt niet overeen met jouw server ($current). Weet je zeker dat je doorgaat?';
  }

  @override
  String get familyKeyConfirmPartner =>
      'Is dit de juiste partner? Controleer de gebruikersnaam hierboven.';

  @override
  String get familyKeyAlreadyPairedWarning =>
      'Je hebt al een familiesleutel. Als je een nieuwe importeert, wordt data die al met de huidige sleutel is versleuteld onleesbaar totdat je opnieuw synchroniseert.';

  @override
  String get familyKeyEnterTitle => 'Familiesleutel invoeren';

  @override
  String get familyKeyEnterSubtitle =>
      'Vul de 12 woorden van je partner in. Daarna zie je de vingerafdruk ter controle.';

  @override
  String get familyKeySaved => 'Familiesleutel opgeslagen.';

  @override
  String familyKeySaveError(String error) {
    return 'Fout bij opslaan: $error';
  }

  @override
  String familyKeyInvalidQr(String error) {
    return 'Ongeldige QR-code: $error';
  }

  @override
  String get familyKeyShareTitle => 'Familiesleutel delen';

  @override
  String get familyKeyShareLegacyBody =>
      'Laat je partner deze QR-code scannen. Deze familiesleutel is van vóór de herstelzin en heeft geen 12 woorden.';

  @override
  String get familyKeyShareBody =>
      'Laat je partner deze QR-code scannen, of de 12 woorden typen.';

  @override
  String get familyKeyShareNoPassword =>
      'De code bevat geen WebDAV-wachtwoord. Controleer samen de vingerafdruk.';

  @override
  String get familyKeyShareNoEntropy =>
      'Geen herstelzin-gegevens op dit apparaat. Maak een nieuwe familiesleutel.';

  @override
  String familyKeyShareFingerprint(String fingerprint) {
    return 'Vingerafdruk  $fingerprint';
  }

  @override
  String get familyKeyPartnerScanned => 'Partner heeft gescand';

  @override
  String get familyKeyShared => 'Familiesleutel gedeeld';

  @override
  String get vaultWelcomeTitle => 'Jouw kluis';

  @override
  String get vaultWelcomeBody =>
      'Kinetic Link bewaart taken en notities met een herstelzin van 12 woorden. Schrijf die zin op papier. Op dit apparaat kun je hem later opnieuw tonen (met schermvergrendeling).';

  @override
  String get vaultNewVault => 'Nieuwe kluis';

  @override
  String get vaultRestoreVault => 'Kluis herstellen';

  @override
  String get vaultLegacyBackup => 'Oude back-up (.kbak2)';

  @override
  String get vaultCreateVault => 'Kluis aanmaken';

  @override
  String get vaultRecoveryPhrase => 'Herstelzin';

  @override
  String get vaultConfirm => 'Bevestigen';

  @override
  String get vaultWriteWords =>
      'Schrijf deze 12 woorden op papier en bewaar ze veilig. Zonder deze zin kun je de kluis niet op een nieuw apparaat herstellen.';

  @override
  String get vaultPhraseCopied => 'Herstelzin gekopieerd';

  @override
  String get vaultIWroteThemDown => 'Ik heb ze opgeschreven';

  @override
  String get vaultQuizPrompt =>
      'Vul de gevraagde woorden in om te bevestigen dat je de zin hebt bewaard.';

  @override
  String vaultWordN(int n) {
    return 'Woord $n';
  }

  @override
  String get vaultBackToWords => 'Terug naar de woorden';

  @override
  String get vaultQuizMismatch => 'Niet alle woorden kloppen. Probeer opnieuw.';

  @override
  String vaultCreateFailed(String error) {
    return 'Kon de kluis niet aanmaken: $error';
  }

  @override
  String get vaultCouldNotReadFile => 'Kon het bestand niet lezen.';

  @override
  String vaultInvalidLegacyBackup(String error) {
    return 'Ongeldige oude back-up: $error';
  }

  @override
  String get vaultRestoreTitle => 'Kluis herstellen';

  @override
  String get vaultRestoreIntro =>
      'Kies hoe je de kluis terugzet. De herstelzin is in beide gevallen dezelfde.';

  @override
  String get vaultRestoreFromFile => 'Vanaf bestand';

  @override
  String get vaultRestoreFromWebDav => 'Vanaf WebDAV';

  @override
  String get vaultRestoreFromWebDavSubtitle =>
      'Server, inloggegevens en 12 woorden. Geen bestand nodig.';

  @override
  String get vaultRestoreFileTitle => 'Herstellen vanaf bestand';

  @override
  String get vaultRestoreFileBody =>
      'Vul je herstelzin in en kies daarna het .kvault-bestand.';

  @override
  String get vaultChooseFileAndRestore => 'Bestand kiezen en herstellen';

  @override
  String get vaultNoVaultOnServer =>
      'Geen kluis op deze server. Maak een nieuwe kluis of kies een andere server.';

  @override
  String get vaultPhraseMismatchServer =>
      'Deze herstelzin hoort niet bij de kluis op deze server.';

  @override
  String get vaultRestoreWebDavTitle => 'Herstellen vanaf WebDAV';

  @override
  String get vaultRestoreWebDavBody =>
      'Log in op je server en vul dezelfde 12 woorden in als bij het aanmaken van de kluis.';

  @override
  String get vaultServerUrl => 'Server-URL';

  @override
  String get vaultUsername => 'Gebruikersnaam';

  @override
  String get vaultPassword => 'Wachtwoord';

  @override
  String get vaultUnlock => 'Kluis ontgrendelen';

  @override
  String get vaultPhraseFieldLabel => 'Herstelzin (12 woorden)';

  @override
  String get vaultMigrateTitle => 'Nieuwe herstelzin';

  @override
  String get vaultMigrateBody =>
      'Je huidige sleutel is willekeurig (versie 0.2) en kan niet in 12 woorden. Taken en notities op dit apparaat blijven staan. We maken een nieuwe herstelzin. Bij de volgende sync worden persoonlijke bestanden opnieuw versleuteld. De familiesleutel blijft hetzelfde — partner en kinderen hoeven niet opnieuw te koppelen.';

  @override
  String get vaultMigrateActivate => 'Nieuwe herstelzin activeren';

  @override
  String get vaultMigrateHeadline =>
      'Schrijf deze nieuwe 12 woorden op. De oude sleutel werkt daarna niet meer voor WebDAV of een .kvault.';

  @override
  String get vaultRestoreFromFileSubtitle =>
      '12 woorden + versleuteld .kvault-bestand. Geen internet nodig.';

  @override
  String get vaultBiometricsReason => 'Toon de herstelzin op dit apparaat';

  @override
  String get vaultNoScreenLockTitle => 'Geen schermvergrendeling';

  @override
  String get vaultNoScreenLockBody =>
      'Dit apparaat heeft geen Face ID, vingerafdruk of pincode. Iedereen met toegang tot de app kan de woorden zien. Doorgaan?';

  @override
  String get vaultShowAnyway => 'Toch tonen';

  @override
  String get vaultRevealWarning =>
      'Schrijf de woorden opnieuw op papier als je de kopie kwijt bent. Laat dit scherm niet openstaan.';

  @override
  String get familyCreateTitle => 'Familiesleutel';

  @override
  String get familyCreateWriteWords =>
      'Schrijf deze 12 woorden op. Ze horen bij de familiesleutel die je deelt met je partner. We slaan de woorden niet op.';

  @override
  String familyCreateFailed(String error) {
    return 'Kon de familiesleutel niet aanmaken: $error';
  }

  @override
  String get commonVerify => 'Controleren';

  @override
  String get commonLeave => 'Verlaten';

  @override
  String get relativeJustNow => 'zojuist';

  @override
  String relativeMinutesAgo(int count) {
    return '$count minuten geleden';
  }

  @override
  String relativeHoursAgo(int count) {
    return '$count uur geleden';
  }

  @override
  String get relativeYesterday => 'gisteren';

  @override
  String relativeDaysAgo(int count) {
    return '$count dagen geleden';
  }

  @override
  String get partnerVerifyTitle => 'Familiesleutel controleren';

  @override
  String get partnerVerifyBody =>
      'Vul de 12 woorden in. We tonen ze niet; we controleren alleen of ze kloppen.';

  @override
  String get partnerVerifyOk => 'De familiesleutel klopt.';

  @override
  String get partnerVerifyMismatch =>
      'Deze herstelzin hoort niet bij deze familiesleutel.';

  @override
  String get partnerRevealMissing =>
      'Deze familiesleutel is van voor de herstelzin (0.2) of kwam binnen als ruwe sleutel. We kunnen de woorden niet tonen. Maak een nieuwe familiesleutel en laat partner en kinderen opnieuw koppelen.';

  @override
  String get partnerUnlinkTitle => 'Partner ontkoppelen?';

  @override
  String get partnerUnlinkBody =>
      'Alle gedeelde notities worden van dit apparaat verwijderd. Je eigen taken en privé-notities blijven behouden. Je partner verliest de verbinding niet — alleen jij verlaat de gedeelde werkruimte.';

  @override
  String get partnerShareViaQr => 'Familiesleutel delen via QR';

  @override
  String get partnerShareViaQrSubtitle =>
      'Laat je partner de QR-code scannen om samen te werken.';

  @override
  String get partnerScanKey => 'Familiesleutel scannen';

  @override
  String get partnerScanKeySubtitle =>
      'Scan de QR of typ de 12 woorden van je partner.';

  @override
  String get partnerReshareKey => 'Familiesleutel opnieuw delen';

  @override
  String get partnerReshareKeySubtitle =>
      'Deel de sleutel met een nieuw apparaat van je partner.';

  @override
  String get partnerVerifyPhrase => 'Herstelzin controleren';

  @override
  String get partnerVerifyPhraseSubtitle =>
      'Controleer of je de 12 woorden van de familiesleutel nog kent.';

  @override
  String get partnerShowKey => 'Familiesleutel tonen';

  @override
  String get partnerShowKeySubtitle =>
      'Toon de 12 woorden op dit apparaat (schermvergrendeling).';

  @override
  String get partnerUnlink => 'Partner ontkoppelen';

  @override
  String get partnerUnlinkSubtitle =>
      'Verwijder de familiesleutel en gedeelde notities van dit apparaat.';

  @override
  String get partnerStatusPaired =>
      'Partner gekoppeld — familiesleutel aanwezig';

  @override
  String get partnerStatusUnpaired =>
      'Partner niet gekoppeld — scan of deel de QR-code om te koppelen';

  @override
  String partnerLastSeen(String when) {
    return 'Partner voor het laatst gezien $when';
  }

  @override
  String partnerLastSeenWarning(String when) {
    return 'Waarschuwing: partner voor het laatst gezien $when';
  }

  @override
  String partnerFingerprint(String fingerprint) {
    return 'Vingerafdruk $fingerprint';
  }

  @override
  String get kidsLinkApp => 'Kinderenapp koppelen';

  @override
  String get kidsLinkAppSubtitle => 'Laat de kinderenapp de QR-code scannen.';

  @override
  String get kidsEnrolledSection => 'GEKOPPELDE KINDEREN';

  @override
  String get kidsNoneEnrolled => 'Nog geen kinderen gekoppeld.';

  @override
  String get kidsRemoveTooltip => 'Verwijder uit familie';

  @override
  String kidsRemoveTitle(String name) {
    return '$name verwijderen?';
  }

  @override
  String kidsRemoveBody(String name) {
    return '$name wordt uit de familielijst verwijderd. De kinderenapp kan daarna geen familietaken meer ontvangen tenzij opnieuw gekoppeld.';
  }

  @override
  String kidsEnrolledOn(String date) {
    return 'Gekoppeld op $date';
  }

  @override
  String kidsLastSeen(String when) {
    return 'Voor het laatst gezien $when';
  }

  @override
  String kidsLastSeenWarning(String when) {
    return 'Waarschuwing: voor het laatst gezien $when';
  }

  @override
  String get kidsEnrollTitle => 'Kinderenapp koppelen';

  @override
  String get kidsEnrollNameTitle => 'Naam van het kind';

  @override
  String get kidsEnrollNameBody =>
      'Voer de naam in van het kind dat je wilt koppelen.';

  @override
  String get kidsEnrollNameLabel => 'Naam kind';

  @override
  String get kidsEnrollContinueToQr => 'Doorgaan naar QR-code';

  @override
  String kidsEnrollQrTitle(String name) {
    return 'QR-code voor $name';
  }

  @override
  String kidsEnrollQrBody(String name) {
    return 'Open de kinderenapp op het toestel van $name en scan deze code.';
  }

  @override
  String get kidsEnrollWhatShared => 'Wat wordt er gedeeld?';

  @override
  String get kidsEnrollWhatSharedBody =>
      'Deze QR-code bevat de server, het account en de familiesleutel — niet het WebDAV-wachtwoord. Typ dat wachtwoord één keer op het kindertoestel. Deel de code alleen met de kinderenapp op een vertrouwd apparaat.';

  @override
  String get settingsLanguage => 'Taal';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageDutch => 'Nederlands';

  @override
  String get settingsLanguageChoose => 'Taal kiezen';

  @override
  String get commonAdd => 'Toevoegen';

  @override
  String get commonSend => 'Sturen';

  @override
  String get commonRetry => 'Opnieuw proberen';

  @override
  String get commonDismiss => 'Afwijzen';

  @override
  String get commonCloseAction => 'Sluiten';

  @override
  String get commonExporting => 'Exporteren…';

  @override
  String get commonImporting => 'Importeren…';

  @override
  String get commonNone => 'Geen';

  @override
  String get commonEveryone => 'Iedereen';

  @override
  String get commonTitle => 'Titel';

  @override
  String get commonNotes => 'Notities';

  @override
  String get commonContent => 'Inhoud';

  @override
  String get commonLow => 'Laag';

  @override
  String get commonMedium => 'Middel';

  @override
  String get commonHigh => 'Hoog';

  @override
  String get commonPrivate => 'Privé';

  @override
  String get commonShared => 'Gedeeld';

  @override
  String get commonKids => 'Kinderen';

  @override
  String get commonPartner => 'Partner';

  @override
  String get commonReminder => 'Herinnering';

  @override
  String get commonTime => 'Tijd';

  @override
  String get commonCategory => 'Categorie';

  @override
  String get commonPriority => 'Prioriteit';

  @override
  String get commonNoCategory => 'Geen categorie';

  @override
  String commonSaveError(String error) {
    return 'Fout bij opslaan: $error';
  }

  @override
  String commonDeleteError(String error) {
    return 'Fout bij verwijderen: $error';
  }

  @override
  String relativeWeeksAgo(int count) {
    return '$count weken geleden';
  }

  @override
  String get dateToday => 'Vandaag';

  @override
  String get dateTomorrow => 'Morgen';

  @override
  String get dateYesterday => 'Gisteren';

  @override
  String dateDaysOverdue(int count) {
    return '${count}d te laat';
  }

  @override
  String dateInDays(int count) {
    return 'Over $count dagen';
  }

  @override
  String get dateWeekdayMonday => 'Maandag';

  @override
  String get dateWeekdayTuesday => 'Dinsdag';

  @override
  String get dateWeekdayWednesday => 'Woensdag';

  @override
  String get dateWeekdayThursday => 'Donderdag';

  @override
  String get dateWeekdayFriday => 'Vrijdag';

  @override
  String get dateWeekdaySaturday => 'Zaterdag';

  @override
  String get dateWeekdaySunday => 'Zondag';

  @override
  String get dateMonthJan => 'jan';

  @override
  String get dateMonthFeb => 'feb';

  @override
  String get dateMonthMar => 'mrt';

  @override
  String get dateMonthApr => 'apr';

  @override
  String get dateMonthMay => 'mei';

  @override
  String get dateMonthJun => 'jun';

  @override
  String get dateMonthJul => 'jul';

  @override
  String get dateMonthAug => 'aug';

  @override
  String get dateMonthSep => 'sep';

  @override
  String get dateMonthOct => 'okt';

  @override
  String get dateMonthNov => 'nov';

  @override
  String get dateMonthDec => 'dec';

  @override
  String get connNotConnected => 'Niet verbonden';

  @override
  String connNotConnectedSince(String when) {
    return 'Niet verbonden sinds $when';
  }

  @override
  String get connUnknownNoSync => 'Verbinding onbekend (geen sync)';

  @override
  String connStale(String when) {
    return 'Verbinding verouderd ($when)';
  }

  @override
  String get connConnected => 'Verbonden';

  @override
  String connConnectedSince(String when) {
    return 'Verbonden ($when)';
  }

  @override
  String get notifChannelName => 'Taakherinneringen';

  @override
  String get notifChannelDesc => 'Herinneringen voor taken en opdrachten';

  @override
  String get notifReminderTitle => 'Herinnering';

  @override
  String get backupNoVault => 'Geen kluis op dit apparaat.';

  @override
  String backupSaved(String path) {
    return 'Back-up opgeslagen: $path';
  }

  @override
  String backupExportError(String error) {
    return 'Fout bij exporteren: $error';
  }

  @override
  String get backupVerifyTitle => 'Herstelzin controleren';

  @override
  String get backupVerifyBody =>
      'Vul je 12 woorden in. We tonen de zin niet; we controleren alleen of hij klopt.';

  @override
  String get backupVerifyOk => 'De herstelzin klopt.';

  @override
  String get backupVerifyMismatch =>
      'Deze herstelzin hoort niet bij deze kluis.';

  @override
  String get backupRevealTitle => 'Herstelzin';

  @override
  String get backupRevealMissing =>
      'We kunnen de woorden op dit apparaat niet opnieuw tonen. Gebruik je papieren kopie, of herstel de kluis met de 12 woorden.';

  @override
  String get backupImportTitle => 'Back-up importeren';

  @override
  String get backupImportBody =>
      'Vul de 12 woorden in van de kluis die in het .kvault-bestand zit. Dit vervangt je huidige taken en notities.';

  @override
  String get backupCouldNotReadFile => 'Kon het bestand niet lezen.';

  @override
  String get backupRestored => 'Back-up succesvol hersteld.';

  @override
  String backupInvalidFile(String error) {
    return 'Ongeldig back-upbestand: $error';
  }

  @override
  String backupImportError(String error) {
    return 'Fout bij importeren: $error';
  }

  @override
  String get backupRestoring => 'Back-up herstellen…';

  @override
  String get webdavSetupTitle => 'WebDAV instellen';

  @override
  String get webdavUrlRequired => 'Vul de server-URL in';

  @override
  String get webdavUsernameRequired => 'Vul de gebruikersnaam in';

  @override
  String get webdavPasswordRequired => 'Vul het wachtwoord in';

  @override
  String get webdavTestConnection => 'Verbinding testen';

  @override
  String get webdavTestingConnection => 'Verbinding testen…';

  @override
  String get webdavConnectionOk => 'Verbinding geslaagd';

  @override
  String get webdavTestFirst => 'Test de verbinding eerst voordat je opslaat.';

  @override
  String get webdavCreateVaultFirst =>
      'Maak eerst een kluis voordat je WebDAV koppelt.';

  @override
  String get webdavPhraseMismatchServer =>
      'Op deze server staat al een kluis die niet bij jouw herstelzin past.';

  @override
  String get webdavConfigSaved => 'WebDAV-configuratie opgeslagen.';

  @override
  String webdavSaveError(String error) {
    return 'Fout bij opslaan: $error';
  }

  @override
  String get webdavMigrationTitle => 'Bestaande gegevens gevonden';

  @override
  String get webdavMigrationIntro =>
      'Op de WebDAV-server staan al versleutelde bestanden:';

  @override
  String webdavMigrationTaskFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '  • $count taakbestanden',
      one: '  • 1 taakbestand',
    );
    return '$_temp0';
  }

  @override
  String webdavMigrationNoteFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '  • $count notitiebestanden',
      one: '  • 1 notitiebestand',
    );
    return '$_temp0';
  }

  @override
  String get webdavMigrationChoose =>
      'Deze bestanden zijn versleuteld met een kluis. Kies hoe je verder wilt gaan:';

  @override
  String get webdavMigrationCleanOption =>
      '1. Schone installatie — verwijder de oude bestanden op de server en begin opnieuw.';

  @override
  String get webdavMigrationImportOption =>
      '2. Back-up importeren — selecteer een .kvault-bestand. De herstelzin van deze kluis ontsleutelt het bestand.';

  @override
  String get webdavMigrationClean => 'Schone installatie';

  @override
  String get webdavMigrationImport => 'Back-up importeren';

  @override
  String get webdavBackupRestoredSync =>
      'Back-up hersteld. De app synchroniseert nu met de server.';

  @override
  String webdavRestoreError(String error) {
    return 'Fout bij herstellen van back-up: $error';
  }

  @override
  String webdavMigrationCheckFailed(String error) {
    return 'Migratiecontrole mislukt: $error';
  }

  @override
  String webdavFilesDeleted(int count) {
    return '$count bestanden verwijderd.';
  }

  @override
  String webdavCleanupError(String error) {
    return 'Fout bij opschonen: $error';
  }

  @override
  String get tasksTitle => 'Taken';

  @override
  String get tasksCompletedTooltip => 'Voltooide taken';

  @override
  String get tasksTabPrivate => 'Privé';

  @override
  String get tasksTabSuggestions => 'Voorstellen';

  @override
  String get tasksTabKids => 'Kinderen';

  @override
  String get tasksSyncFailed => 'Sync mislukt, tap om opnieuw te proberen.';

  @override
  String get tasksSyncing => 'Synchroniseren';

  @override
  String get tasksForYou => 'Voor jou';

  @override
  String get tasksForPartner => 'Voor partner';

  @override
  String get tasksFromPartner => 'Van partner';

  @override
  String get tasksRefreshSuggestions => 'Vernieuw voorstellen';

  @override
  String get tasksAddReminder => 'Herinnering';

  @override
  String get tasksAddTask => 'Toevoegen';

  @override
  String get tasksToPartner => 'Naar partner';

  @override
  String get tasksNoPartnerSuggestions => 'Geen partnervoorstellen';

  @override
  String get tasksNoPartnerSuggestionsHint =>
      'Je partner heeft nog geen taken voorgesteld';

  @override
  String get tasksViaSuggestion => 'Via suggestie';

  @override
  String get tasksReject => 'Afwijzen';

  @override
  String get tasksAccept => 'Accepteren';

  @override
  String get tasksProposalAccepted => 'Voorstel geaccepteerd';

  @override
  String get tasksProposalRejected => 'Voorstel afgewezen';

  @override
  String get tasksLoadProposalsError => 'Fout bij laden van voorstellen';

  @override
  String tasksXpResetTitle(String name) {
    return 'XP resetten voor $name?';
  }

  @override
  String get tasksXpResetBody =>
      'Dit stelt de XP-teller terug naar 0. De opdrachten blijven bewaard.';

  @override
  String get tasksXpResetAction => 'Resetten';

  @override
  String tasksXpResetDone(String name) {
    return 'XP gereset voor $name';
  }

  @override
  String tasksXpResetError(String error) {
    return 'Fout bij resetten: $error';
  }

  @override
  String get tasksLoadKidsError => 'Fout bij laden van kinderopdrachten';

  @override
  String get tasksNoKidsAssignments => 'Geen kinderopdrachten';

  @override
  String get tasksNoKidsAssignmentsHint =>
      'Stuur een taak naar de kinderenapp om hem hier te zien.';

  @override
  String get tasksResetXp => 'Reset XP';

  @override
  String tasksDoneOn(int day, int month) {
    return 'Gedaan op $day/$month';
  }

  @override
  String get tasksCompletedTitle => 'Voltooide taken';

  @override
  String get tasksDeleteAll => 'Verwijder alles';

  @override
  String get tasksDeleteCompletedTitle => 'Voltooide taken verwijderen';

  @override
  String get tasksDeleteCompletedBody =>
      'Weet je zeker dat je alle voltooide taken wilt verwijderen? Dit kan niet ongedaan worden gemaakt.';

  @override
  String get tasksEmptySuggestionsPartner =>
      'Hier verschijnen suggesties van de slimme planner en voorstellen van je partner';

  @override
  String get tasksEmptySuggestionsSolo =>
      'Hier verschijnen suggesties van de slimme planner op basis van je gewoonten';

  @override
  String get tasksNoSuggestions => 'Geen voorstellen';

  @override
  String get tasksAllDone => 'Alles klaar!';

  @override
  String get tasksNoOpenTasks => 'Je hebt geen openstaande taken';

  @override
  String get tasksNoCompleted => 'Geen voltooide taken';

  @override
  String get tasksNoCompletedHint => 'Voltooide taken verschijnen hier';

  @override
  String get tasksAssignment => 'Opdracht';

  @override
  String get taskDeleteTitle => 'Taak verwijderen?';

  @override
  String taskDeleteBody(String title) {
    return '\"$title\" wordt definitief verwijderd. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String get taskForwardTitle => 'Taak doorsturen';

  @override
  String get taskAssignmentCreated => 'Opdracht aangemaakt ✓';

  @override
  String get taskNoConnectedFamily => 'Geen verbonden partner of kinderen';

  @override
  String get taskStaleConnectionTitle => 'Verbinding verouderd';

  @override
  String taskStalePartnerBody(String status) {
    return 'Je partner is voor het laatst gezien $status. Toch sturen?';
  }

  @override
  String taskStaleKidBody(String name, String status) {
    return '$name is voor het laatst gezien $status. Toch sturen?';
  }

  @override
  String get taskSendAnyway => 'Toch sturen';

  @override
  String get taskSendToPartnerTitle => 'Stuur naar partner?';

  @override
  String taskSendToPartnerBody(String title) {
    return '\"$title\" wordt als voorstel naar je partner gestuurd en verdwijnt uit jouw lijst zodra zij/hij het accepteert.';
  }

  @override
  String taskSendToKidTitle(String name) {
    return 'Stuur naar $name?';
  }

  @override
  String get taskSendToKidBody =>
      'De taak verdwijnt uit jouw lijst zodra het kind hem afrondt.';

  @override
  String taskSendToKidLead(String title, String name) {
    return '\"$title\" wordt als opdracht naar $name gestuurd.';
  }

  @override
  String get taskXpReward => 'XP beloning:';

  @override
  String get taskNameHint => 'Taaknaam';

  @override
  String get taskAddTime => 'Tijd toevoegen';

  @override
  String get taskAddCategory => 'Categorie toevoegen';

  @override
  String get taskRepeat => 'Herhalen';

  @override
  String get taskForward => 'Doorsturen';

  @override
  String get taskRecurrenceNone => 'Geen herhaling';

  @override
  String get taskRecurrenceDaily => 'Dagelijks';

  @override
  String get taskRecurrenceWeekdays => 'Werkdagen';

  @override
  String get taskRecurrenceWeekly => 'Wekelijks';

  @override
  String get taskRecurrenceBiweekly => 'Tweewekelijks';

  @override
  String get taskRecurrenceMonthly => 'Maandelijks';

  @override
  String get notesTitle => 'Notities';

  @override
  String get notesTabPrivate => 'Privé';

  @override
  String get notesTabShared => 'Gedeeld';

  @override
  String get notesNewTooltip => 'Nieuwe notitie';

  @override
  String get notesLoadError => 'Fout bij laden notities';

  @override
  String get notesEmptyShared => 'Geen gedeelde notities';

  @override
  String get notesEmptyPrivate => 'Geen privé notities';

  @override
  String get notesEmptySharedHint =>
      'Notities gedeeld met je partner verschijnen hier';

  @override
  String get notesEmptyPrivateHint => 'Je privé notities verschijnen hier';

  @override
  String get notesSaved => 'Notitie opgeslagen';

  @override
  String get notesSharedBadge => 'Gedeeld';

  @override
  String get notesTitleRequired => 'Titel is verplicht';

  @override
  String get notesDeleteTitle => 'Notitie verwijderen?';

  @override
  String get notesDeleteBody => 'Je kunt dit niet ongedaan maken.';

  @override
  String get notesSharedWithPartner => 'Gedeeld met partner';

  @override
  String get suggestWebDavRequired =>
      'Koppel eerst WebDAV om een voorstel te sturen.';

  @override
  String get suggestPartnerSeesTitle => 'Dit ziet je partner';

  @override
  String get suggestPartnerSeesGeneric =>
      'Bewust algemeen — geen privé-titels of notities.';

  @override
  String get suggestPartnerSeesFull =>
      'Titel en eventuele notities van deze suggestie gaan mee.';

  @override
  String get suggestSend => 'Versturen';

  @override
  String get suggestSent => 'Voorstel naar partner gestuurd';

  @override
  String get suggestSnoozeTitle => 'Uitstellen';

  @override
  String get suggestSnoozeBody => 'Suggestie 7 dagen uitstellen?';

  @override
  String get suggestSnoozeAction => 'Uitstellen';

  @override
  String get suggestAdd => 'Toevoegen';

  @override
  String get suggestReasonHabit => 'Gewoonte';

  @override
  String get suggestReasonPartner => 'Partner-aanvulling';

  @override
  String get suggestReasonSeasonal => 'Seizoensgebonden';

  @override
  String get suggestReasonLoadBalance => 'Taakverdeling';

  @override
  String get suggestReasonStale => 'Open taak';

  @override
  String get suggestReasonCalendar => 'Kalender';

  @override
  String get categoryTitle => 'Categorie';

  @override
  String get categoryNewHint => 'Nieuwe categorie';

  @override
  String get categoryNewAction => 'Nieuwe categorie…';

  @override
  String get quickAddHint => 'Nieuwe taak…';

  @override
  String get quickAddMoreOptions => 'Meer opties';

  @override
  String get timeInvalid => 'Voer een geldige tijd in (00:00 – 23:59).';

  @override
  String get timeOk => 'OK';
}
