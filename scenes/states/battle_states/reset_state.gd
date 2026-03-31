extends BaseState

var _inactive_unit_pool: Array[Unit] = []

func _on_enter() -> void:
	_reset_units()

func _reset_units() -> void:
	if battle._backup_all_units == null:
		push_warning("ResetState: No backup available")
		parent_fsm.change_state("StartState")
		return
	var all_units = battle._all_units.get_all_units()
	_collect_inactive_units(all_units)
	_collect_inactive_units(battle.dying_units)
	battle.dying_units.clear()
	
	_restore_units_from_backup()
	_cleanup_inactive_pool()
	_finalize_reset()



func _restore_units_from_backup() -> void:
	var backup = battle._backup_all_units
	var backup_count = backup.get_count()
	
	for i in range(backup_count):
		var b_unit = backup.get_b_unit_by_index(i)
		if b_unit == null:
			continue
		
		var unit = _get_or_create_unit(b_unit)
		if unit:
			unit.restore_from_b_unit(b_unit)
			unit.global_position = battle.game_area.get_global_from_tile(\
			b_unit.cell_pos) + Unit.DEFAULT_OFFSET
			unit.show()
			unit.play_idle(b_unit.direction)
			battle.game_area.game_grid.add_unit(unit, b_unit.cell_pos)
			backup.set_unit_at_index(i, unit, b_unit)

func _collect_inactive_units(all_units: Array[Unit]) -> void:
	for unit in all_units:
		unit.hide()
		unit.animated_sprite.stop()
		if unit.animated_sprite.animation_finished.is_connected(unit.queue_free):
			unit.animated_sprite.animation_finished.disconnect(unit.queue_free)
		if unit.tree_exited.is_connected(battle._on_dying_unit_freed):
			unit.tree_exited.disconnect(battle._on_dying_unit_freed)
		
		var cell_pos = battle.game_area.game_grid.get_unit_position(unit)
		if cell_pos != Vector2i(-999, -999):
			battle.game_area.game_grid.remove_unit(cell_pos)
		_inactive_unit_pool.append(unit)

func _get_or_create_unit(b_unit: BUnit) -> Unit:
	for i in range(_inactive_unit_pool.size()):
		var pool_unit = _inactive_unit_pool[i]
		if pool_unit.unit_stat == b_unit.unit_stat:
			_inactive_unit_pool.remove_at(i)
			return pool_unit
	
	return battle.unit_spawner.spawn_unit_in_cell(
		b_unit.cell_pos, 
		b_unit.unit_stat, 
		b_unit.faction
	)

func _cleanup_inactive_pool() -> void:
	for unit in _inactive_unit_pool:
		unit.queue_free()
	_inactive_unit_pool.clear()

func _finalize_reset() -> void:
	battle._all_units = battle._backup_all_units
	battle.clear_backup()
	parent_fsm.change_state("StartState")
