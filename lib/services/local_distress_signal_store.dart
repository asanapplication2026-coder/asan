import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// A row saved on-device the moment a distress SMS arrives — independent of
/// whether we could resolve the sender to a roster entry, find an active
/// drill, or reach Supabase at all. `synced` tracks whether it has made it
/// into the remote `distress_signals` table yet.
class LocalDistressSignal {
  LocalDistressSignal({
    required this.localId,
    required this.sender,
    required this.rawBody,
    required this.receivedAt,
    required this.synced,
    this.remoteId,
    this.identifier,
    this.latitude,
    this.longitude,
    this.building,
    this.floor,
    this.message,
  });

  final int localId;
  final String sender;
  final String rawBody;
  final DateTime receivedAt;
  final bool synced;
  final String? remoteId;

  /// School ID number or full name the student typed into the SMS, used to
  /// resolve a roster entry when the sender's phone isn't a claimed
  /// profile (see DistressSignalService.resolveRosterId).
  final String? identifier;

  final double? latitude;
  final double? longitude;
  final String? building;
  final String? floor;
  final String? message;

  factory LocalDistressSignal.fromMap(Map<String, dynamic> m) {
    return LocalDistressSignal(
      localId: m['local_id'] as int,
      sender: m['sender'] as String,
      rawBody: m['raw_body'] as String,
      receivedAt: DateTime.parse(m['received_at'] as String),
      synced: (m['synced'] as int) == 1,
      remoteId: m['remote_id'] as String?,
      identifier: m['identifier'] as String?,
      latitude: m['latitude'] as double?,
      longitude: m['longitude'] as double?,
      building: m['building'] as String?,
      floor: m['floor'] as String?,
      message: m['message'] as String?,
    );
  }
}

/// Owns a single sqflite database file for locally-cached distress signals.
/// This is deliberately separate from Supabase — it exists so an SOS SMS
/// survives on the device even if the app can't reach the network or
/// resolve the sender/drill at the moment it arrives.
class LocalDistressSignalStore {
  LocalDistressSignalStore._();
  static final LocalDistressSignalStore instance = LocalDistressSignalStore._();

  static const _dbName = 'distress_signals_local.db';
  // Bumped 1 -> 2 to add the `identifier` column (school ID / name parsed
  // from the SMS body, used to resolve a roster entry when the sender's
  // phone isn't a claimed profile).
  static const _dbVersion = 2;
  static const _table = 'local_distress_signals';

  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            local_id      INTEGER PRIMARY KEY AUTOINCREMENT,
            remote_id     TEXT,
            sender        TEXT NOT NULL,
            raw_body      TEXT NOT NULL,
            identifier    TEXT,
            latitude      REAL,
            longitude     REAL,
            building      TEXT,
            floor         TEXT,
            message       TEXT,
            received_at   TEXT NOT NULL,
            synced        INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN identifier TEXT');
        }
      },
    );
    _db = db;
    return db;
  }

  /// Saves a freshly-received SMS payload immediately, before any attempt
  /// to resolve the sender or push to Supabase. Returns the local row id.
  Future<int> insertPending({
    required String sender,
    required String rawBody,
    String? identifier,
    double? latitude,
    double? longitude,
    String? building,
    String? floor,
    String? message,
  }) async {
    final db = await _database;
    return db.insert(_table, {
      'sender': sender,
      'raw_body': rawBody,
      'identifier': identifier,
      'latitude': latitude,
      'longitude': longitude,
      'building': building,
      'floor': floor,
      'message': message,
      'received_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<LocalDistressSignal?> getById(int localId) async {
    final db = await _database;
    final rows = await db.query(_table, where: 'local_id = ?', whereArgs: [localId]);
    if (rows.isEmpty) return null;
    return LocalDistressSignal.fromMap(rows.first);
  }

  /// All signals still waiting to reach Supabase — call this after
  /// connectivity is restored, on app start, or on pull-to-refresh.
  Future<List<LocalDistressSignal>> getUnsynced() async {
    final db = await _database;
    final rows = await db.query(_table, where: 'synced = 0', orderBy: 'received_at ASC');
    return rows.map(LocalDistressSignal.fromMap).toList();
  }

  /// Every locally-cached signal, synced or not — useful for an on-device
  /// "SMS log" screen independent of what made it to Supabase.
  Future<List<LocalDistressSignal>> getAll() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'received_at DESC');
    return rows.map(LocalDistressSignal.fromMap).toList();
  }

  Future<void> markSynced(int localId, String remoteId) async {
    final db = await _database;
    await db.update(
      _table,
      {'synced': 1, 'remote_id': remoteId},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }
}