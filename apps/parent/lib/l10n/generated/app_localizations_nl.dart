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
}
