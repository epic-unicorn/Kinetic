// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get leaveFamilyTitle => 'Leave family?';

  @override
  String get leaveFamilyMessage =>
      'The link with the family will be removed. Your local tasks will be kept.';

  @override
  String get cancel => 'Cancel';

  @override
  String get leave => 'Leave';

  @override
  String get linkFamilyTitle => 'Link family';

  @override
  String get scanQrCode => 'Scan the QR code';

  @override
  String get scanQrInstructions =>
      'Open your parent\'s Kinetic app, go to Settings → Family → Link kids app, scan the QR code, then enter the WebDAV password.';

  @override
  String invalidQrCode(Object error) {
    return 'Invalid QR code: $error';
  }

  @override
  String get qrCodeFoundConfirm =>
      'QR code found. Link this device to the family?';

  @override
  String get account => 'Account';

  @override
  String get server => 'Server';

  @override
  String get enterWebDavPassword =>
      'Enter your parent\'s WebDAV password. It is not in the QR code.';

  @override
  String get webDavPassword => 'WebDAV password';

  @override
  String get link => 'Link';

  @override
  String get myTasks => 'My Tasks';

  @override
  String get sync => 'Sync';

  @override
  String get leaveFamily => 'Leave family';

  @override
  String errorWithDetails(Object error) {
    return 'Error: $error';
  }

  @override
  String get allDone => 'All done!';

  @override
  String get noTasksRightNow => 'No tasks right now.';

  @override
  String get stillToDo => 'To do';

  @override
  String get completed => 'Completed';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityLow => 'Low';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get overdue => 'Overdue';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String taskNotFound(Object error) {
    return 'Task not found: $error';
  }

  @override
  String get taskDetails => 'Task details';

  @override
  String get details => 'Details';

  @override
  String get dueDate => 'Due date';

  @override
  String get noDueDate => 'No due date';

  @override
  String get priority => 'Priority';

  @override
  String get category => 'Category';

  @override
  String get experience => 'Experience';

  @override
  String get notes => 'Notes';

  @override
  String get delete => 'Delete';

  @override
  String get categoryHousehold => 'Household';

  @override
  String get categorySchool => 'School';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryOther => 'Other';

  @override
  String get notificationChannelName => 'Tasks';

  @override
  String get notificationChannelDescription =>
      'Notifications for new tasks from your parent.';

  @override
  String get newTaskNotificationTitle => 'New task';
}
