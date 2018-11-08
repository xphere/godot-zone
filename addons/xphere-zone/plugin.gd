tool
extends EditorPlugin

const anchor_icon := preload("res://addons/xphere-zone/anchor.svg")

var node: Area2D
var handles: Array
var dragging_handle


func handles(object: Object) -> bool:
	return object is Area2D


func edit(object: Object) -> void:
	node = object


func make_visible(visible: bool) -> void:
	if not node:
		return

	for child in node.get_children():
		if child is CollisionShape2D and child.shape and child.shape is RectangleShape2D:
			child.visible = visible

	if not visible:
		node = null

	update_overlays()


func forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not node or not node.is_inside_tree():
		return

	var transform := node.get_viewport_transform() * node.get_global_transform()
	var tex_size := anchor_icon.get_size()

	var areas = []
	for child in node.get_children():

			areas.append(child)

	if areas.empty():
		return

	handles = []
	for child in node.get_children():
		if not child is CollisionShape2D:
			continue

		var shape = child.shape
		if not shape or not shape is RectangleShape2D:
			continue

		var position : Vector2
		var rect : Rect2

		position = transform.xform(child.position - shape.extents)
		rect = Rect2(position - tex_size / 2, tex_size)
		overlay.draw_texture(anchor_icon, rect.position)
		handles.append({
			area = child,
			position = position,
			rect = rect,
			top_left = true,
		})

		position = transform.xform(child.position + shape.extents)
		rect = Rect2(position - tex_size / 2, tex_size)
		overlay.draw_texture(anchor_icon, rect.position)
		handles.append({
			area = child,
			position = position,
			rect = rect,
			top_left = false,
		})


func drag_to(position: Vector2) -> void:
	if not dragging_handle:
		return

	var area : CollisionShape2D = dragging_handle.area
	var tl = position if dragging_handle.top_left else (area.position - area.shape.extents)
	var br = (area.position + area.shape.extents) if dragging_handle.top_left else position
	area.position = (br + tl) / 2
	area.shape.extents = (br - tl) / 2


func forward_canvas_gui_input(event: InputEvent) -> bool:
	if not node or not node.visible:
		return false

	if dragging_handle and event.is_action_pressed("ui_cancel"):
		var undo := get_undo_redo()
		undo.commit_action()
		undo.undo()
		dragging_handle = null
		return true

	if not event is InputEventMouse:
		return false

	if dragging_handle != null:
		if event is InputEventMouseMotion:
			var viewport_transform_inv := node.get_viewport().get_global_canvas_transform().affine_inverse()
			var viewport_position: Vector2 = viewport_transform_inv.xform(event.position)
			var transform_inv := node.get_global_transform().affine_inverse()
			var position: Vector2 = transform_inv.xform(viewport_position.round())
			drag_to(position)
			update_overlays()
			return true

		if is_mouse_button(event, BUTTON_LEFT, false):
			var undo := get_undo_redo()
			undo.add_do_property(dragging_handle.area.shape, "extents", dragging_handle.area.shape.extents)
			undo.add_do_property(dragging_handle.area, "position", dragging_handle.area.position)
			undo.commit_action()
			dragging_handle = null
			return true

	elif is_mouse_button(event, BUTTON_LEFT, true):
		for handle in handles:
			if handle.rect.has_point(event.position):
				var undo := get_undo_redo()
				undo.create_action("Move anchor")
				undo.add_undo_property(handle.area.shape, "extents", handle.area.shape.extents)
				undo.add_undo_property(handle.area, "position", handle.area.position)
				dragging_handle = handle
				return true

	return false


func is_mouse_button(event: InputEventMouse, button: int, pressed: bool) -> bool:
	return (
		event is InputEventMouseButton and
		event.button_index & button == button and
		event.is_pressed() == pressed
	)
