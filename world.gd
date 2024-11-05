extends Node

# 定义玩家和allin的属性
var player = {
	"hp": 100,
	"mp": 50,
	"attack": 6,
	"skip_turn":false,
	
}

var enemy = {
	"hp": 80,
	"mp": 30,
	"attack": 8,
	"skip_turn": false,
	"attack_multiplier":false,
	"min_damage":0,
}

# 回合状态
var is_player_turn = true
var game_over = false

# 引用TextEdit节点
@onready var text_edit = $MainTextEdit #主窗口
@onready var playerArea2D = $Player #玩家
@onready var enemyArea2D = $Monster #玩家
@onready var animation_player = $Player/AnimationPlayer
@onready var animation_monster = $Monster/AnimationPlayer
@onready var monsterTimer = $MonsterTime #allin回合延时
@onready var playerHeath = $PlayerMsg/HP/HpBar #玩家血量
@onready var monsterHeath = $MonsterMsg/HP/HpBar #allin血量
@onready var playerMp = $PlayerMsg/MP/MpBar #玩家蓝量
@onready var monsterMp = $MonsterMsg/MP/MpBar #allin蓝量
@onready var backGroundMusic = $Music/BackGroundMusic #背景音乐
@onready var monsterAttackMusic = $Music/MonsterAttack #allin攻击音效
@onready var playerAttackMusic = $Music/PlayerAttack #玩家攻击音效
@onready var attackEffect = $Effects/AttackEffect # 拳头攻击特效
@onready var trail  = $Effects/Trail # 拖尾特效

# 游戏初始化
func _ready():
	
	attackEffect.visible = false
	trail.width = 10
	trail.default_color = Color(1, 1, 1, 0.5)
	
	display_stats()
	add_text("你遇到了一个allin！\n")
	display_enemy_stats()
	add_text("你要攻击还是使用技能？ ")
	backGroundMusic.play()

func _process(delta):
	if trail.visible:
		trail.add_point(attackEffect.position)
		if trail.get_point_count() > 10:  # 限制拖尾长度
			trail.remove_point(0)

# 显示玩家和allin的属性
func display_stats():
	text_edit.clear()
	#add_text("玩家状态:\n")
	#add_text("HP: %d | MP: %d | Attack: %d\n" % [player["hp"], player["mp"], player["attack"]])
	playerHeath.value = player["hp"]
	playerMp.value = player["mp"]
	
	
func display_enemy_stats():
	#add_text("\nallin状态:\n")
	#add_text("HP: %d | MP: %d | Attack: %d\n" % [enemy["hp"], enemy["mp"], enemy["attack"]])
	monsterHeath.value = enemy["hp"]
	monsterMp.value = enemy["mp"]
 
# 添加文本到TextEdit
func add_text(text):
	text_edit.text += text + "\n"

func shake_camera(camera: Camera2D):
	var shake_strength = 8.0
	var shake_duration = 0.2
	
	var shake_tween = create_tween()
	for i in range(5):
		var random_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		shake_tween.tween_property(camera, "offset", random_offset, 0.05)
	
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)	

func frame_freeze(duration: float):
	Engine.time_scale = 0.05  # 将时间缩放设为很小的值
	await get_tree().create_timer(duration * 0.05).timeout  # 需要考虑时间缩放
	Engine.time_scale = 1.0  # 恢复正常时间流速

func create_hit_effect(pos: Vector2):
	var particles = GPUParticles2D.new()
	var material = ParticleProcessMaterial.new()
	
	# 设置粒子属性
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.spread = 180.0
	material.initial_velocity_min = 100
	material.initial_velocity_max = 200
	material.scale_min = 0.5
	material.scale_max = 2.0
	material.color = Color(1, 1, 1, 1)
	
	particles.process_material = material
	particles.amount = 15
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.position = pos
	
	$Effects.add_child(particles)
	particles.emitting = true
	
	# 自动清理粒子
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func perform_attack():
	attackEffect.visible = true
	# ... 在攻击开始时显示拖尾
	trail.visible = true
	trail.clear_points()
	
	# 确保特效初始不可见
	attackEffect.modulate.a = 0
	# 重置特效位置到左侧角色位置
	attackEffect.position = playerArea2D.position
	# 重置缩放和旋转
	attackEffect.scale = Vector2(1, 1)
	attackEffect.rotation = 0
	
	# 创建攻击动画序列
	var tween = create_tween()
	
	# 1. 特效出现
	tween.set_parallel(true)  # 允许并行动画
	tween.tween_property(attackEffect, "modulate:a", 1.0, 0.1)
	tween.tween_property(attackEffect, "scale", Vector2(1.2, 1.2), 0.1)
	
	# 2. 快速移动到目标
	tween.set_parallel(false)  # 后续动画按序执行
	var target_x = enemyArea2D.position.x - 50  # 停在角色前面一点
	tween.tween_property(attackEffect, "position:x", target_x, 0.15)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	# 3. 击打效果
	tween.tween_callback(func():
		# 创建击打时的缩放效果
		var hit_tween = create_tween()
		hit_tween.tween_property(attackEffect, "scale", Vector2(1.5, 0.8), 0.1)
	)
	
	# 4. 后退晃动
	tween.tween_property(attackEffect, "position:x", target_x - 30, 0.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	# 5. 消失效果
	tween.tween_property(attackEffect, "modulate:a", 0, 0.15)
	tween.tween_property(attackEffect, "scale", Vector2(0.8, 0.8), 0.15)
	
	# 6. 重置特效（可选）
	tween.tween_callback(func():
		attackEffect.position = playerArea2D.position
	)
	
	# 好像不起作用..
	# 在击打效果这里添加震动
	tween.tween_callback(func():
		#print(" 打击--震动效果")
		# 创建击打时的缩放效果
		var hit_tween = create_tween()
		hit_tween.tween_property(attackEffect, "scale", Vector2(1.5, 0.8), 0.1)
		
		# 添加屏幕震动
		var camera = get_node("Camera2D")
		if camera:
			shake_camera(camera)
	)
	
	# 好像...
	# 在击打时添加帧冻结
	tween.tween_callback(func():
		frame_freeze(0.1)  # 冻结0.1秒
		
		# 创建击打时的缩放效果
		var hit_tween = create_tween()
		hit_tween.tween_property(attackEffect, "scale", Vector2(1.5, 0.8), 0.1)
	)
	
	# 在击打时添加特效
	tween.tween_callback(func():
		create_hit_effect(attackEffect.position)
	)
	
	# ... 在攻击结束时隐藏拖尾
	tween.tween_callback(func():
		trail.visible = false
		trail.clear_points()
	)
	 	
# 玩家攻击
func player_attack():
	perform_attack() #攻击特效
	playerAttackMusic.play()
	player["mp"] += 10
	if player["mp"] > 100:
		player["mp"] = 100
	add_text("蓝量恢复 10 点")
	playerMp.value = player["mp"]
	#print("player-attack :",player["attack"])
	var dice_roll = randi() % 6 + 1
	var damage = player["attack"] + dice_roll
	add_text("你攻击了allin，造成了 %d 点伤害！" % damage)
	enemy["hp"] -= damage
	
	monsterTimer.start()
	#check_enemy_hp()

# 玩家使用技能
func player_use_skill():
	if player["mp"] < 10:
		add_text("玩家蓝量不足！")
		monsterTimer.start()
		#check_enemy_hp()
		return
	player["mp"] -= 10 # mp减少
	playerMp.value = player["mp"] # 显示更新
	var dice_roll = randi() % 6 + 1
	add_text("你使用了技能，骰子点数为 %d！" % dice_roll)
	player["mp"] -= 10
	match dice_roll:
		1:  # 恢复血量
			var heal_amount = randi() % 10 + 5
			player["hp"] += heal_amount 
			if player["hp"] > 100:
				player["hp"] = 100
			add_text("你恢复了 %d 点血量！" % heal_amount)
			
		2:  # 下回合攻击力翻倍
			player["attack"] *= 2
			add_text("你的攻击力在下回合翻倍(其实..)！")
			
		3:  # allin下回合被禁锢
			add_text("allin被禁锢，下回合无法行动！")
			# 将allin的攻击跳过
			enemy["skip_turn"] = true
			
		4:  # 下回合攻击两次
			add_text("没有什么逼效果...")
			#player["extra_attacks"] = 1
			
		5:  # 防御
			#player["defense"] = true
			add_text("恭喜你，技能发动成功，金币+1！")
			
		6:  # 终极攻击
			var ultimate_damage = player["attack"] * 2 + randi() % 10 + 5
			add_text("你发动了终极攻击，造成了 %d 点伤害！" % ultimate_damage)
			enemy["hp"] -= ultimate_damage
			
	monsterTimer.start()
	#check_enemy_hp()

# 检查allin血量
func check_enemy_hp():
	  
	if enemy["hp"] <= 0:
		add_text("allin被击败了！游戏结束！")
		game_over = true
	else:
		#add_text("allin剩余HP: %d" % enemy["hp"])
		enemy_turn()

func enemy_turn():
	if game_over:
		return
	
	animation_monster.play("stay")
	if enemy["skip_turn"] == true: # If the enemy was immobilized
		add_text("\nallin想要行动，但被禁锢了，什么都做不了！")
		enemy["skip_turn"] = false
		
		check_player_hp()
		return
	
	# Randomly decide between attacking or using a skill (50% chance)
	var action_roll = randi() % 2
	if action_roll == 0:
		enemy_attack() # Perform attack
	else:
		enemy_use_skill() # Use a random skill
		
	check_player_hp()

# Enemy attack logic
func enemy_attack():
	monsterAttackMusic.play()
	var dice_roll = randi() % 6 + 1
	var damage = enemy["attack"] + dice_roll
	
	if enemy["attack_multiplier"] == true:
		damage *= 2
		enemy["attack_multiplier"] = false 
		
	if enemy["min_damage"] > 0:
		if damage < enemy["min_damage"]:
			damage = enemy["min_damage"]
			
	add_text("\nallin狠狠地攻击了你，造成了 %d 点伤害！" % damage)
	player["hp"] -= damage
	if damage > 10:
		add_text("“这点痛苦你能忍住吗？”allin戏谑地嘲讽你。")
	else:
		add_text("allin轻蔑地笑了笑：'这就受不了了吗？'")
	 

# Enemy skill logic
func enemy_use_skill():
	var skill_roll = randi() % 6 + 1
	match skill_roll:
		1:
			add_text("\nallin突然用力跳起，恢复了 20 点 HP！")
			enemy["hp"] += 20
		2:
			add_text("\nallin发出凶狠的吼叫，接下来的攻击力将翻倍！")
			enemy["attack_multiplier"] = true
		3:
			add_text("\nallin甩动尾巴，你被吓得不敢动，下一回合无法行动！")
			player["skip_turn"] = true
		4:
			add_text("\nallin说：pass")
			#enemy["double_attack"] = true
		5:
			add_text("\nallin向天空大喊，恢复了 10 点 MP！")
			enemy["mp"] += 10
		6:
			add_text("\nallin发出疯狂的笑声，接下来回合中伤害不会低于 10 点！")
			enemy["min_damage"] = 10
		
	 

# 检查玩家血量
func check_player_hp():
	if player["hp"] <= 0:
		add_text("你被击败了！游戏结束！")
		game_over = true
	else:
		#add_text("玩家剩余HP: %d" % player["hp"])
		add_text("\n你的回合！你要攻击还是使用技能？  ")

# 攻击按钮按下
func _on_attack_pressed() -> void:
	if game_over:
		return
	
	animation_player.play("stay")
	animation_player.play("attack")
	
	text_edit.clear()  # 清空输入框 
	if player["skip_turn"] == true:
		add_text("玩家的回合被跳过")
		#check_enemy_hp()
		monsterTimer.start()
		
		player["skip_turn"] = false
	else:
		player_attack()
	monsterHeath.value = enemy["hp"]	 

# 技能按钮按下
func _on_skill_pressed() -> void: 
	if game_over:
		return
	
	animation_player.play("stay")
	text_edit.clear()  # 清空输入框 
	if player["skip_turn"] == true:
		add_text("玩家的回合被跳过")  
		monsterTimer.start()
		#check_enemy_hp()
		player["skip_turn"] = false
	else:
		player_use_skill() 
	monsterHeath.value = enemy["hp"]	 
	 
 
func _on_monster_time_timeout() -> void:
	monsterTimer.stop() 
	check_enemy_hp()
	playerHeath.value = player["hp"]
	monsterHeath.value = enemy["hp"]
	pass # Replace with function body.
