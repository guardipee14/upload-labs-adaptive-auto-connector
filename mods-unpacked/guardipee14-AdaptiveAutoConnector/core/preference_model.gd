extends Node

signal preference_changed(event: String, semantic_key: String, score: float)

const LOG_PREFIX := "[guardipee14-AdaptiveAutoConnector][Preference]"
const ACCEPT_DELTA := 4.0
const MANUAL_CHOICE_DELTA := 6.0
const ALTERNATE_DELTA := -1.5
const REJECTION_DELTA := -5.0
const QUICK_UNDO_DELTA := -8.0
const LATE_UNDO_DELTA := -4.0
const MIN_PAIR_SCORE := -8.0
const MAX_PAIR_SCORE := 8.0
const QUICK_UNDO_WINDOW_MSEC := 30000

var _entries: Dictionary = {}
var _event_index := 0
var _last_accept_key := ""
var _last_accept_msec := 0


func get_candidate_preference(candidate: Dictionary) -> Dictionary:
    var semantic_key := semantic_key_for(candidate)
    var entry: Dictionary = _entries.get(semantic_key, {})
    return {
        "semantic_key": semantic_key,
        "adjustment": float(entry.get("score", 0.0)),
        "events": entry.get("events", {}).duplicate(true),
        "session_only": true
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
        "event_index": 0
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
    _entries[semantic_key] = entry

    print("%s Event index=%d event='%s' key='%s' delta=%.2f before=%.2f after=%.2f session_only=true metadata=%s" % [
        LOG_PREFIX,
        _event_index,
        event,
        semantic_key,
        delta,
        before,
        after,
        str(metadata)
    ])

    preference_changed.emit(event, semantic_key, after)
    return {
        "event": event,
        "semantic_key": semantic_key,
        "delta": delta,
        "before": before,
        "after": after,
        "metadata": metadata.duplicate(true)
    }


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
