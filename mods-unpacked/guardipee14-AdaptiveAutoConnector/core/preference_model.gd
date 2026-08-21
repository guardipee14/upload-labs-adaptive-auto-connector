extends Node

signal preference_changed(event: String, semantic_key: String, score: float)

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Preference]"
const STORE_LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][PreferenceStore]"
const ACCEPT_DELTA := 4.0
const MANUAL_CHOICE_DELTA := 6.0
const ALTERNATE_DELTA := -1.5
const REJECTION_DELTA := -5.0
const QUICK_UNDO_DELTA := -8.0
const LATE_UNDO_DELTA := -4.0
const MIN_PAIR_SCORE := -8.0
const MAX_PAIR_SCORE := 8.0
const QUICK_UNDO_WINDOW_MSEC := 30000
const PERSISTENCE_SCHEMA_VERSION := 1
const STORAGE_DIR := "user://AdaptiveAutoConnector"
const STORAGE_PATH := STORAGE_DIR + "/preferences.json"
const BACKUP_PATH := STORAGE_DIR + "/preferences.backup.json"
const STALE_AFTER_DAYS := 180
const STALE_AFTER_SECONDS := STALE_AFTER_DAYS * 86400

var _entries: Dictionary = {}
var _event_index := 0
var _last_accept_key := ""
var _last_accept_msec := 0
var _persistence_loaded := false
var _persistence_writable := true
var _recovered_from_backup := false
var _loaded_entry_count := 0
var _pruned_entry_count := 0
var _sanitized_entry_count := 0


func _ready() -> void:
    _load_persistent_preferences()


func get_candidate_preference(candidate: Dictionary) -> Dictionary:
    var semantic_key := semantic_key_for(candidate)
    var entry: Dictionary = _entries.get(semantic_key, {})
    return {
        "semantic_key": semantic_key,
        "adjustment": float(entry.get("score", 0.0)),
        "events": entry.get("events", {}).duplicate(true),
        "persistent": true,
        "session_only": false,
        "schema_version": PERSISTENCE_SCHEMA_VERSION
    }


func record_accept(record: Dictionary) -> Dictionary:
    var result: Dictionary = _record("accept", record, ACCEPT_DELTA)
    _last_accept_key = str(result.get("semantic_key", ""))
    _last_accept_msec = Time.get_ticks_msec()
    return result


func record_manual_choice(record: Dictionary, metadata: Dictionary = {}) -> Dictionary:
    return _record("manual_choice", record, MANUAL_CHOICE_DELTA, metadata)


func record_alternate(record: Dictionary) -> Dictionary:
    return _record("alternate", record, ALTERNATE_DELTA)


func record_rejection(record: Dictionary) -> Dictionary:
    return _record("no_thanks", record, REJECTION_DELTA)


func record_undo(record: Dictionary) -> Dictionary:
    var semantic_key := semantic_key_for(record)
    var elapsed_msec: int = 0
    var delta: float = LATE_UNDO_DELTA
    var timing := "late_or_unknown"

    if semantic_key == _last_accept_key and _last_accept_msec > 0:
        elapsed_msec = maxi(0, Time.get_ticks_msec() - _last_accept_msec)
        if elapsed_msec <= QUICK_UNDO_WINDOW_MSEC:
            delta = QUICK_UNDO_DELTA
            timing = "quick"

    var result: Dictionary = _record("undo", record, delta, {
        "timing": timing,
        "elapsed_msec": elapsed_msec
    })

    if semantic_key == _last_accept_key:
        _last_accept_key = ""
        _last_accept_msec = 0

    return result


func get_session_snapshot() -> Dictionary:
    return _entries.duplicate(true)


func get_persistence_status() -> Dictionary:
    return {
        "schema_version": PERSISTENCE_SCHEMA_VERSION,
        "path": STORAGE_PATH,
        "backup_path": BACKUP_PATH,
        "loaded": _persistence_loaded,
        "writable": _persistence_writable,
        "recovered_from_backup": _recovered_from_backup,
        "entry_count": _entries.size(),
        "loaded_entry_count": _loaded_entry_count,
        "pruned_entry_count": _pruned_entry_count,
        "sanitized_entry_count": _sanitized_entry_count,
        "stale_after_days": STALE_AFTER_DAYS
    }


func reset_persistent_preferences() -> Dictionary:
    _entries.clear()
    _event_index = 0
    _last_accept_key = ""
    _last_accept_msec = 0
    _persistence_writable = true
    _recovered_from_backup = false
    _loaded_entry_count = 0
    _pruned_entry_count = 0
    _sanitized_entry_count = 0

    var saved := _save_persistent_preferences("explicit_reset", true)
    print("%s Reset requested saved=%s schema=%d path='%s'" % [
        STORE_LOG_PREFIX,
        str(saved),
        PERSISTENCE_SCHEMA_VERSION,
        STORAGE_PATH
    ])
    return get_persistence_status()


func semantic_key_for(record: Dictionary) -> String:
    return "%s|%s|%s|%s|%s" % [
        _semantic_window(str(record.get("target_window", ""))),
        _semantic_token(str(record.get("target_name", ""))),
        _semantic_token(str(record.get("resource", ""))),
        _semantic_window(str(record.get("source_window", ""))),
        _semantic_token(str(record.get("source_name", "")))
    ]


func _record(
    event: String,
    record: Dictionary,
    delta: float,
    metadata: Dictionary = {}
) -> Dictionary:
    var semantic_key := semantic_key_for(record)
    var entry: Dictionary = _entries.get(semantic_key, {
        "score": 0.0,
        "events": {},
        "last_event": "",
        "event_index": 0,
        "updated_unix": _now_unix()
    })

    var before := float(entry.get("score", 0.0))
    var after: float = clampf(before + delta, MIN_PAIR_SCORE, MAX_PAIR_SCORE)
    var events: Dictionary = entry.get("events", {})
    events[event] = int(events.get(event, 0)) + 1

    _event_index += 1
    entry["score"] = after
    entry["events"] = events
    entry["last_event"] = event
    entry["event_index"] = _event_index
    entry["last_metadata"] = metadata.duplicate(true)
    entry["updated_unix"] = _now_unix()
    _entries[semantic_key] = entry

    var persisted := _save_persistent_preferences("event:%s" % event)

    print("%s Event index=%d event='%s' key='%s' delta=%.2f before=%.2f after=%.2f session_only=false persisted=%s metadata=%s" % [
        LOG_PREFIX,
        _event_index,
        event,
        semantic_key,
        delta,
        before,
        after,
        str(persisted),
        str(metadata)
    ])

    preference_changed.emit(event, semantic_key, after)
    return {
        "event": event,
        "semantic_key": semantic_key,
        "delta": delta,
        "before": before,
        "after": after,
        "persistent": persisted,
        "metadata": metadata.duplicate(true)
    }


func _load_persistent_preferences() -> void:
    _persistence_loaded = true

    if not _ensure_storage_directory():
        _persistence_writable = false
        return

    if not FileAccess.file_exists(STORAGE_PATH):
        print("%s No persisted preferences schema=%d path='%s' stale_after_days=%d" % [
            STORE_LOG_PREFIX,
            PERSISTENCE_SCHEMA_VERSION,
            STORAGE_PATH,
            STALE_AFTER_DAYS
        ])
        return

    var primary := _read_payload(STORAGE_PATH)
    var primary_status := str(primary.get("status", "invalid"))

    if primary_status == "future_schema":
        _persistence_writable = false
        print("%s Refusing downgrade write path='%s' file_schema=%d supported_schema=%d mode='read_only'" % [
            STORE_LOG_PREFIX,
            STORAGE_PATH,
            int(primary.get("schema_version", -1)),
            PERSISTENCE_SCHEMA_VERSION
        ])
        return

    if primary_status == "ok":
        _hydrate_payload(primary.get("payload", {}), "primary")
        return

    var backup := _read_payload(BACKUP_PATH)
    if str(backup.get("status", "invalid")) == "ok":
        _recovered_from_backup = true
        _hydrate_payload(backup.get("payload", {}), "backup")
        _save_persistent_preferences("backup_recovery", false)
        return

    _persistence_writable = false
    print("%s Existing preference file could not be safely loaded and was preserved; persistence disabled for this session. primary_reason='%s' backup_reason='%s' reset_api='reset_persistent_preferences'" % [
        STORE_LOG_PREFIX,
        str(primary.get("reason", "unknown")),
        str(backup.get("reason", "missing_or_invalid"))
    ])


func _hydrate_payload(payload: Dictionary, source: String) -> void:
    var raw_entries = payload.get("entries", {})
    if not raw_entries is Dictionary:
        _persistence_writable = false
        print("%s Load refused source='%s' reason='entries_not_dictionary'" % [STORE_LOG_PREFIX, source])
        return

    _entries.clear()
    _loaded_entry_count = 0
    _pruned_entry_count = 0
    _sanitized_entry_count = 0

    var now_unix := _now_unix()
    var saved_unix := int(payload.get("saved_unix", now_unix))
    var highest_event_index := maxi(0, int(payload.get("event_index", 0)))

    for raw_key in raw_entries.keys():
        var semantic_key := str(raw_key).strip_edges()
        var raw_entry = raw_entries[raw_key]

        if semantic_key.is_empty() or not raw_entry is Dictionary:
            _sanitized_entry_count += 1
            continue

        var score_value = raw_entry.get("score", 0.0)
        if not _is_number(score_value):
            _sanitized_entry_count += 1
            continue

        var updated_unix := int(raw_entry.get("updated_unix", saved_unix))
        if updated_unix <= 0:
            updated_unix = saved_unix
        if now_unix > 0 and updated_unix > now_unix:
            updated_unix = now_unix
            _sanitized_entry_count += 1

        if _is_stale(updated_unix, now_unix):
            _pruned_entry_count += 1
            continue

        var entry_event_index := maxi(0, int(raw_entry.get("event_index", 0)))
        highest_event_index = maxi(highest_event_index, entry_event_index)

        var score: float = clampf(float(score_value), MIN_PAIR_SCORE, MAX_PAIR_SCORE)
        if not is_equal_approx(score, float(score_value)):
            _sanitized_entry_count += 1

        var events := _sanitize_events(raw_entry.get("events", {}))
        var metadata: Dictionary = {}
        var raw_metadata = raw_entry.get("last_metadata", {})
        if raw_metadata is Dictionary:
            metadata = raw_metadata.duplicate(true)

        _entries[semantic_key] = {
            "score": score,
            "events": events,
            "last_event": str(raw_entry.get("last_event", "")),
            "event_index": entry_event_index,
            "last_metadata": metadata,
            "updated_unix": updated_unix
        }
        _loaded_entry_count += 1

    _event_index = highest_event_index
    _last_accept_key = ""
    _last_accept_msec = 0

    print("%s Loaded schema=%d source='%s' entries=%d pruned_stale=%d sanitized=%d event_index=%d path='%s'" % [
        STORE_LOG_PREFIX,
        PERSISTENCE_SCHEMA_VERSION,
        source,
        _loaded_entry_count,
        _pruned_entry_count,
        _sanitized_entry_count,
        _event_index,
        STORAGE_PATH
    ])

    if _pruned_entry_count > 0 or _sanitized_entry_count > 0 or source == "backup":
        _save_persistent_preferences("normalize_after_load", source != "backup")


func _read_payload(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {
            "status": "missing",
            "reason": "missing"
        }

    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {
            "status": "invalid",
            "reason": "open_error:%d" % FileAccess.get_open_error()
        }

    var text := file.get_as_text()
    file.close()

    var json := JSON.new()
    var parse_error := json.parse(text)
    if parse_error != OK:
        return {
            "status": "invalid",
            "reason": "json_parse_line_%d:%s" % [json.get_error_line(), json.get_error_message()]
        }

    var parsed = json.data
    if not parsed is Dictionary:
        return {
            "status": "invalid",
            "reason": "root_not_dictionary"
        }

    var schema_value = parsed.get("schema_version", null)
    if not _is_number(schema_value):
        return {
            "status": "invalid",
            "reason": "schema_missing_or_invalid"
        }

    var schema_version := int(schema_value)
    if schema_version > PERSISTENCE_SCHEMA_VERSION:
        return {
            "status": "future_schema",
            "schema_version": schema_version,
            "reason": "future_schema"
        }

    if schema_version != PERSISTENCE_SCHEMA_VERSION:
        return {
            "status": "invalid",
            "schema_version": schema_version,
            "reason": "unsupported_schema"
        }

    if not parsed.get("entries", {}) is Dictionary:
        return {
            "status": "invalid",
            "schema_version": schema_version,
            "reason": "entries_not_dictionary"
        }

    return {
        "status": "ok",
        "schema_version": schema_version,
        "payload": parsed
    }


func _save_persistent_preferences(reason: String, backup_existing: bool = true) -> bool:
    if not _persistence_writable:
        print("%s Save skipped reason='%s' mode='read_only'" % [STORE_LOG_PREFIX, reason])
        return false

    if not _ensure_storage_directory():
        _persistence_writable = false
        return false

    if backup_existing and FileAccess.file_exists(STORAGE_PATH):
        var existing_text := _read_text_file(STORAGE_PATH)
        if not existing_text.is_empty():
            if not _write_text_file(BACKUP_PATH, existing_text):
                print("%s Backup write failed path='%s'; preserving current primary and skipping save." % [
                    STORE_LOG_PREFIX,
                    BACKUP_PATH
                ])
                return false

    var payload := {
        "schema_version": PERSISTENCE_SCHEMA_VERSION,
        "mod_version": "0.1.12",
        "saved_unix": _now_unix(),
        "event_index": _event_index,
        "stale_after_days": STALE_AFTER_DAYS,
        "entries": _entries.duplicate(true)
    }
    var text := JSON.stringify(payload, "  ", true) + "\n"

    if not _write_text_file(STORAGE_PATH, text):
        return false

    print("%s Saved schema=%d entries=%d event_index=%d reason='%s' path='%s'" % [
        STORE_LOG_PREFIX,
        PERSISTENCE_SCHEMA_VERSION,
        _entries.size(),
        _event_index,
        reason,
        STORAGE_PATH
    ])
    return true


func _ensure_storage_directory() -> bool:
    var absolute_dir := ProjectSettings.globalize_path(STORAGE_DIR)
    var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
    if error != OK and error != ERR_ALREADY_EXISTS:
        print("%s Storage directory unavailable path='%s' error=%d" % [STORE_LOG_PREFIX, STORAGE_DIR, error])
        return false
    return true


func _read_text_file(path: String) -> String:
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    var text := file.get_as_text()
    file.close()
    return text


func _write_text_file(path: String, text: String) -> bool:
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        print("%s File write failed path='%s' error=%d" % [STORE_LOG_PREFIX, path, FileAccess.get_open_error()])
        return false

    file.store_string(text)
    file.flush()
    file.close()
    return true


func _sanitize_events(value) -> Dictionary:
    var result := {}
    if not value is Dictionary:
        return result

    for raw_key in value.keys():
        var key := str(raw_key).strip_edges()
        if key.is_empty():
            continue
        result[key] = maxi(0, int(value[raw_key]))
    return result


func _is_stale(updated_unix: int, now_unix: int) -> bool:
    if updated_unix <= 0 or now_unix <= updated_unix:
        return false
    return now_unix - updated_unix > STALE_AFTER_SECONDS


func _is_number(value) -> bool:
    var value_type := typeof(value)
    return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _now_unix() -> int:
    return int(Time.get_unix_time_from_system())


func _semantic_window(value: String) -> String:
    return _strip_trailing_digits(_semantic_token(value))


func _semantic_token(value: String) -> String:
    return value.strip_edges().to_lower().replace(" ", "_")


func _strip_trailing_digits(value: String) -> String:
    var result := value
    while not result.is_empty():
        var last_code := result.unicode_at(result.length() - 1)
        if last_code < 48 or last_code > 57:
            break
        result = result.left(result.length() - 1)
    return result
