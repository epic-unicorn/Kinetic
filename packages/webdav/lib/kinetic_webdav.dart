/// Kinetic WebDAV — sync, encryption, and iCal for Kinetic Link.
library kinetic_webdav;

// Secure storage abstraction
export 'src/secure_key_value_store.dart';
export 'src/flutter_secure_key_value_store.dart';

// Configuration
export 'src/sync_config.dart';

// WebDAV HTTP client
export 'src/webdav_client.dart';

// Encryption — AES-256-GCM + PBKDF2
export 'src/encryption/kinetic_encryption.dart';

// iCal wire format
export 'src/ical/ical_task.dart';
export 'src/ical/ical_note.dart';
export 'src/ical/ical_serializer.dart';

// Sync service + enrollment
export 'src/sync/webdav_sync_service.dart';
export 'src/sync/webdav_enrollment.dart';

// Presence tracking
export 'src/presence_info.dart';
