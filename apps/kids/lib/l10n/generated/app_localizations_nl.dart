// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get leaveFamilyTitle => 'Familie verlaten?';

  @override
  String get leaveFamilyMessage =>
      'De koppeling met de familie wordt verwijderd. Je lokale opdrachten blijven bewaard.';

  @override
  String get cancel => 'Annuleren';

  @override
  String get leave => 'Verlaten';

  @override
  String get linkFamilyTitle => 'Familie koppelen';

  @override
  String get scanQrCode => 'Scan de QR-code';

  @override
  String get scanQrInstructions =>
      'Open de Kinetic-app van je ouder, ga naar Instellingen → Familie → Kinderenapp koppelen, scan de QR-code en typ daarna het WebDAV-wachtwoord.';

  @override
  String invalidQrCode(Object error) {
    return 'Ongeldige QR-code: $error';
  }

  @override
  String get qrCodeFoundConfirm =>
      'QR-code gevonden. Koppel dit apparaat aan de familie?';

  @override
  String get account => 'Account';

  @override
  String get server => 'Server';

  @override
  String get enterWebDavPassword =>
      'Typ het WebDAV-wachtwoord van je ouder. Dat staat niet in de QR-code.';

  @override
  String get webDavPassword => 'WebDAV-wachtwoord';

  @override
  String get link => 'Koppelen';

  @override
  String get myTasks => 'Mijn Opdrachten';

  @override
  String get sync => 'Synchroniseren';

  @override
  String get leaveFamily => 'Familie verlaten';

  @override
  String errorWithDetails(Object error) {
    return 'Fout: $error';
  }

  @override
  String get allDone => 'Alles klaar!';

  @override
  String get noTasksRightNow => 'Geen opdrachten op dit moment.';

  @override
  String get stillToDo => 'Nog te doen';

  @override
  String get completed => 'Afgerond';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get priorityHigh => 'Hoog';

  @override
  String get priorityNormal => 'Normaal';

  @override
  String get priorityLow => 'Laag';

  @override
  String get today => 'Vandaag';

  @override
  String get tomorrow => 'Morgen';

  @override
  String get overdue => 'Verlopen';

  @override
  String get loading => 'Laden...';

  @override
  String get error => 'Fout';

  @override
  String taskNotFound(Object error) {
    return 'Taak niet gevonden: $error';
  }

  @override
  String get taskDetails => 'Taakdetails';

  @override
  String get details => 'Gegevens';

  @override
  String get dueDate => 'Vervaldatum';

  @override
  String get noDueDate => 'Geen vervaldatum';

  @override
  String get priority => 'Prioriteit';

  @override
  String get category => 'Categorie';

  @override
  String get experience => 'Ervaring';

  @override
  String get notes => 'Opmerkingen';

  @override
  String get delete => 'Verwijderen';

  @override
  String get categoryHousehold => 'Huishouden';

  @override
  String get categorySchool => 'School';

  @override
  String get categoryHealth => 'Gezondheid';

  @override
  String get categoryShopping => 'Boodschappen';

  @override
  String get categoryEntertainment => 'Recreatie';

  @override
  String get categoryOther => 'Overig';

  @override
  String get notificationChannelName => 'Opdrachten';

  @override
  String get notificationChannelDescription =>
      'Meldingen voor nieuwe opdrachten van de ouder.';

  @override
  String get newTaskNotificationTitle => 'Nieuwe opdracht';
}
