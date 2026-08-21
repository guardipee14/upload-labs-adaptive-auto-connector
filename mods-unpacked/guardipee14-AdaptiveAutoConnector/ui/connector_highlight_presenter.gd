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

    super._locate_runtime_window(str(recommendation.get("target_window", "")), "target")
    _highlight_connector(str(recommendation.get("target_id", "")), "target")


func _on_locate_source_pressed() -> void:
    var recommendation := _current_recommendation()
    if recommendation.is_empty():
        return

    super._locate_runtime_window(str(recommendation.get("source_window", "")), "source")
    _highlight_connector(str(recommendation.get("source_id", "")), "source")


func _clear_connector_highlight() -> void:
    if is_instance_valid(_connector_marker):
        _connector_marker.queue_free()
    _connector_marker = null


func _highlight_connector(container_id: String, role: String) -> bool:
    _clear_connector_highlight()

    if container_id.is_empty() or Globals.desktop == null:
        return false

    var container = Globals.desktop.get_resource(container_id)
    if not is_instance_valid(container):
        push_warning("%s Connector highlight %s failed; container '%s' was not found." % [
            LOG_PREFIX,
            role,
            container_id
        ])
        return false

    var connector_node_name := "InputConnector" if role == "target" else "OutputConnector"
    var connector: Node = container.get_node_or_null(connector_node_name)
    if connector == null or not connector is Control:
        push_warning("%s Connector highlight %s failed; container '%s' has no Control '%s'." % [
            LOG_PREFIX,
            role,
            container_id,
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

    print("%s Connector highlight role='%s' container='%s' node='%s' class='%s' attached=true" % [
        LOG_PREFIX,
        role,
        container_id,
        connector_node_name,
        connector.get_class()
    ])
    return true
