extends Control
## Stage-C: timed goal run, high score, menu.

const PLOTS := 6
const GROW_NEED := 3.0
const TIME_LIMIT := 90.0
const GOAL_HARVESTS := 8
const COLORS := {
	"empty": Color(0.45, 0.35, 0.25),
	"seed": Color(0.55, 0.7, 0.35),
	"grow": Color(0.4, 0.85, 0.45),
	"ready": Color(0.95, 0.75, 0.3),
}

@onready var _hud: Label = $UI/HUD
@onready var _plots: GridContainer = $Center/Plots
@onready var _seed_btn: Button = $UI/Actions/Seed
@onready var _water_btn: Button = $UI/Actions/Water
@onready var _harvest_btn: Button = $UI/Actions/Harvest

var _money: int = 20
var _harvests: int = 0
var _selected: int = 0
var _time_left: float = TIME_LIMIT
var _alive: bool = false
var _in_menu: bool = true
var _states: Array[String] = []
var _progress: Array[float] = []
var _buttons: Array[Button] = []
var _menu: ColorRect
var _overlay: ColorRect
var _over_msg: Label
var _retry: Button
var _to_menu: Button

func _ready() -> void:
	_plots.columns = 3
	_seed_btn.pressed.connect(func() -> void: _act("seed"))
	_water_btn.pressed.connect(func() -> void: _act("water"))
	_harvest_btn.pressed.connect(func() -> void: _act("harvest"))
	_states.clear()
	_progress.clear()
	_buttons.clear()
	for i in PLOTS:
		_states.append("empty")
		_progress.append(0.0)
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 96)
		var idx := i
		b.pressed.connect(func() -> void: _select(idx))
		_plots.add_child(b)
		_buttons.append(b)
	_build_shell()
	_show_menu()

func _build_shell() -> void:
	_menu = ColorRect.new()
	_menu.color = Color(0.1, 0.14, 0.12, 1)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -140
	vb.offset_top = -130
	vb.offset_right = 140
	vb.offset_bottom = 130
	vb.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "米库种植"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
	vb.add_child(title)
	var hi := Label.new()
	hi.name = "High"
	hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hi)
	var start := Button.new()
	start.text = "开始挑战（%ds 收 %d 次）" % [int(TIME_LIMIT), GOAL_HARVESTS]
	start.custom_minimum_size = Vector2(280, 44)
	start.pressed.connect(_begin)
	vb.add_child(start)
	var tip := Label.new()
	tip.text = "播种 5 币 · 浇水 3 次成熟 · 收获 +18"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 12)
	vb.add_child(tip)
	_menu.add_child(vb)
	$UI.add_child(_menu)
	_overlay = ColorRect.new()
	_overlay.visible = false
	_overlay.color = Color(0, 0, 0, 0.62)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var ovb := VBoxContainer.new()
	ovb.set_anchors_preset(Control.PRESET_CENTER)
	ovb.offset_left = -120
	ovb.offset_top = -90
	ovb.offset_right = 120
	ovb.offset_bottom = 90
	ovb.add_theme_constant_override("separation", 12)
	_over_msg = Label.new()
	_over_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_msg.add_theme_font_size_override("font_size", 18)
	_over_msg.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	ovb.add_child(_over_msg)
	_retry = Button.new()
	_retry.text = "再来一局"
	_retry.pressed.connect(_restart_play)
	ovb.add_child(_retry)
	_to_menu = Button.new()
	_to_menu.text = "返回菜单"
	_to_menu.pressed.connect(_show_menu)
	ovb.add_child(_to_menu)
	_overlay.add_child(ovb)
	$UI.add_child(_overlay)

func _show_menu() -> void:
	_alive = false
	_in_menu = true
	_overlay.visible = false
	_menu.visible = true
	$Center.visible = false
	$UI/Actions.visible = false
	(_menu.get_node("VBoxContainer/High") as Label).text = "最高收获分 %d" % SaveData.high_score
	_hud.text = "米库种植"

func _begin() -> void:
	_in_menu = false
	_menu.visible = false
	$Center.visible = true
	$UI/Actions.visible = true
	_restart_play()

func _restart_play() -> void:
	_money = 20
	_harvests = 0
	_selected = 0
	_time_left = TIME_LIMIT
	_alive = true
	_overlay.visible = false
	for i in PLOTS:
		_states[i] = "empty"
		_progress[i] = 0.0
	_select(0)
	_refresh()

func _process(delta: float) -> void:
	if not _alive or _in_menu:
		return
	_time_left -= delta
	_refresh()
	if _time_left <= 0.0:
		_end(false)
	elif _harvests >= GOAL_HARVESTS:
		_end(true)

func _select(i: int) -> void:
	if not _alive and not _in_menu:
		return
	_selected = i
	_refresh()

func _act(kind: String) -> void:
	if not _alive or _in_menu:
		return
	var s: String = _states[_selected]
	match kind:
		"seed":
			if s == "empty" and _money >= 5:
				_money -= 5
				_states[_selected] = "seed"
				_progress[_selected] = 0.0
		"water":
			if s == "seed" or s == "grow":
				_progress[_selected] += 1.0
				if _progress[_selected] >= GROW_NEED:
					_states[_selected] = "ready"
					_progress[_selected] = GROW_NEED
				else:
					_states[_selected] = "grow"
		"harvest":
			if s == "ready":
				_money += 18
				_harvests += 1
				_states[_selected] = "empty"
				_progress[_selected] = 0.0
	_refresh()

func _run_score() -> int:
	return _harvests * 20 + _money

func _refresh() -> void:
	if _in_menu:
		return
	_hud.text = "金币 %d  收获 %d/%d  最高分 %d\n剩余 %.0fs\n地块 #%d · %s" % [
		_money, _harvests, GOAL_HARVESTS, SaveData.high_score, maxf(0.0, _time_left),
		_selected + 1, _label(_states[_selected])
	]
	for i in PLOTS:
		var style := StyleBoxFlat.new()
		var st: String = _states[i]
		style.bg_color = COLORS[st]
		style.set_corner_radius_all(12)
		if i == _selected:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
		_buttons[i].add_theme_stylebox_override("normal", style)
		_buttons[i].text = _short(st)

func _end(won: bool) -> void:
	_alive = false
	var sc := _run_score()
	var best: int = SaveData.record(sc)
	var title := "目标达成！" if won else "时间到"
	_over_msg.text = "%s\n收获 %d · 金币 %d\n得分 %d\n最高 %d" % [title, _harvests, _money, sc, best]
	_overlay.visible = true

func _label(s: String) -> String:
	match s:
		"empty":
			return "空地"
		"seed":
			return "已播种"
		"grow":
			return "生长中"
		"ready":
			return "可收获"
		_:
			return s

func _short(s: String) -> String:
	match s:
		"empty":
			return "空"
		"seed":
			return "种"
		"grow":
			return "长"
		"ready":
			return "熟"
		_:
			return "?"
