extends "res://mods-unpacked/guardipee14-AdaptiveAutoConnector/ui/suggestion_presenter.gd"

const CONNECTOR_MARKER_SCRIPT = preload("res://mods-unpacked/guardipee14-AdaptiveAutoConnector/ui/connector_marker.gd")

var _connector_marker: Control = null


func _exit_tree() -> void:
    _clear_connector_highlight()
    super._exit_tree()


func _on_native_hud_exiting() -> void:
    _clear_connector_highlight()
    super._on_native_hud_exiting()


func _on_locate_target_pressed() -> void:
    var recommendation := _current_recommendation()
    if recommendation.is_empty():
        return

    var window_name := str(recommendation.get("target_window", ""))
    super._locate_runtime_window(window_name, "target")
    _highlight_connector(
        str(recommendation.get("target_id", "")),
        window_name,
        str(recommendation.get("target_name", "")),
        str(recommendation.get("resource", "")),
        "target"
    )


func _on_locate_source_pressed() -> void:
    var recommendation := _current_recommendation()
    if recommendation.is_empty():
        return

    var window_name := str(recommendation.get("source_window", ""))
    super._locate_runtime_window(window_name, "source")
    _highlight_connector(
        str(recommendation.get("source_id", "")),
        window_name,
        str(recommendation.get("source_name", "")),
        str(recommendation.get("resource", "")),
        "source"
    )


func _clear_connector_highlight() -> void:
    if is_instance_valid(_connector_marker):
        _connector_marker.queue_free()
    _connector_marker = null


func _highlight_connector(
    container_id: String,
    window_name: String,
    container_name: String,
    resource: String,
    role: String
) -> bool:
    _clear_connector_highlight()

    if Globals.desktop == null:
        return false

    var container = null
    var resolution := "exact_id"

    if not container_id.is_empty():
        container = Globals.desktop.get_resource(container_id)

    if not is_instance_valid(container):
        container = _find_fallback_container(window_name, container_name, resource, role)
        resolution = "window_container_fallback"

    if not is_instance_valid(container):
        push_warning("%s Connector highlight %s failed; requested container='%s' window='%s' name='%s' resource='%s' could not be resolved uniquely." % [
            LOG_PREFIX,
            role,
            container_id,
            window_name,
            container_name,
            resource
        ])
        return false

    var connector_node_name := "InputConnector" if role == "target" else "OutputConnector"
    var connector: Node = container.get_node_or_null(connector_node_name)
    if connector == null or not connector is Control:
        push_warning("%s Connector highlight %s failed; resolved container '%s' has no Control '%s'." % [
            LOG_PREFIX,
            role,
            str(container.get("id")),
            connector_node_name
        ])
        return false

    var marker_instance = CONNECTOR_MARKER_SCRIPT.new()
    if marker_instance == null or not marker_instance is Control:
        push_warning("%s Connector highlight %s failed; marker could not be created." % [
            LOG_PREFIX,
            role
        ])
        return false

    var marker := marker_instance as Control
    marker.call("configure", role)
    (connector as Control).add_child(marker)
    _connector_marker = marker

    print("%s Connector highlight role='%s' requested_container='%s' resolved_container='%s' resolution='%s' node='%s' class='%s' attached=true" % [
        LOG_PREFIX,
        role,
        container_id,
        str(container.get("id")),
        resolution,
        connector_node_name,
        connector.get_class()
    ])
    return true


func _find_fallback_container(
    window_name: String,
    container_name: String,
    resource: String,
    role: String
):
    if window_name.is_empty() or container_name.is_empty():
        return null

    var runtime_window: Node = _find_window_by_runtime_name(window_name)
    if runtime_window == null or not "containers" in runtime_window:
        return null

    var raw_containers = runtime_window.get("containers")
    if not raw_containers is Array:
        return null

    var connector_node_name := "InputConnector" if role == "target" else "OutputConnector"
    var matches: Array[Node] = []

    for raw_container in raw_containers:
        if not is_instance_valid(raw_container) or not raw_container is Node:
            continue

        var candidate := raw_container as Node
        if str(candidate.name) != container_name:
            continue
        if not resource.is_empty() and str(candidate.get("resource")) != resource:
            continue

        var connector: Node = candidate.get_node_or_null(connector_node_name)
        if connector == null or not connector is Control:
            continue

        matches.append(candidate)

    if matches.size() != 1:
        if matches.size() > 1:
            push_warning("%s Connector highlight %s fallback was ambiguous; window='%s' name='%s' resource='%s' matches=%d." % [
                LOG_PREFIX,
                role,
                window_name,
                container_name,
                resource,
                matches.size()
            ])
        return null

    return matches[0]
