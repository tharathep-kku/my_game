# All narrative + level data (maps, notes, chats, cutscenes). Pure data, no logic.
class_name Story

# Map legend (cell = 2m):
#  #  wall            .  floor          L  floor + ceiling light   u  emergency light (on when power is out)
#  =  cubicle panel   D  desk (also a hide spot: crawl under)   B  server rack / cabinet
#  k  counter         b  boxes          o  plant          Q  bed (endings)
#  P  player start    X  exit door (in outer wall)
#  d  document (goal) n  password post-it (goal, "postits")  K  PC (goal, needs post-its + power, "pc_code")
#  C  coffee (goal)   c  coffee (heal only)   Y  breaker (power back, loud)   F  exit fingerprint scanner (hold E)
#  f  fuse (goal)      p  fuse panel (goal, needs the fuse; until it's in, F is dead)
#  t  ringing phone (guard's creepy call = evidence)   T  guard's own phone (steal)
#  M/S/G/R  NPC start (Manager/Sweeper/Goblin/guaRd)   N/V  practice mannequin (walks / watches)   1-9  NPC route
#  A  friendly daytime coworker ("coworkers", reading order)   m  washroom mirror   i  thin wall (both run along x)
#  H  locker (hide)    W  toilet stall (hide)
#  s  throwable        e  readable note ("notes", reading order)   Z  dream clue
#  z  power bank       g  guard cameo spot      !  story trigger ("triggers", reading order)
#  J  scripted scare ("scares", reading order; "at" = cell where it appears / sounds)
#  r  room sign ("signs", reading order)
# Stage mechanics (copied to the stage scene's Inspector): dark_start, rage_on_goal, rage_line,
# flicker (Vector2 seconds between blackouts), finale.
#
# These maps only GENERATE the scenes (tools/bake_stages.tscn). After that the scenes are the
# truth: notes, triggers, scares, coworkers and the tutorial's texts are edited in the Inspector (see EDITING.md).
# Cutscene positions are Vector3(cell_x, height_m, cell_z); see cutscene.gd for step types.
const STAGES := [
	{
		"title": "ด่าน 1 : แผนกบัญชี",
		"clock": "23:47",
		"story": [   # black-screen text before the stage (first visit only)
			"ตอนเช้า หัวหน้าธนายังตบไหล่ชม \"งานต๋องเรียบร้อยดีนะจ๊ะ\"",
			"หัวค่ำ หลังทุกคนกลับบ้านไปแล้ว ต๋องเผลอกด\"ตอบกลับทั้งหมด\"\nส่งไฟล์งบดุลร่างแรก ที่ยังไม่เสร็จ ไปหาทุกคนในบริษัท",
			"ไม่กี่นาทีต่อมา หัวหน้าธนาที่กลับไปแล้ว ก็มายืนอยู่กลางออฟฟิศ\nรอยยิ้มค้างอยู่อย่างนั้น... ไม่หุบอีกเลย",
			"เขาอยากรู้ว่างานคืบหน้ากี่เปอร์เซ็นต์\nและอยากเรียกต๋องไป \"คุยกันหน่อย\" ...ประมาณสามชั่วโมงได้",
		],
		"objective": "เก็บเอกสารงบดุล %d/3 ชุด — ได้ยินเสียงรองเท้าเอี๊ยดอ๊าด ให้ก้มหลบ (C) · อ่านโน้ตบนโต๊ะ มีคำใบ้",
		"goal": 3,
		"floor": Color(0.32, 0.36, 0.42), "wall": Color(0.72, 0.7, 0.6), "light": Color(0.85, 1.0, 0.85),
		"map": [
			"##############################",
			"#P...L.....L....L..#..d....H.#",
			"#..!..............g#o..e...L.#",
			"#D=D=D.D=D=D.D=D=D.#...D.....#",
			"#.1.......J.......2.r........#",
			"#................!.#.s..3....#",
			"#D=D=D.D=D=D.D=D=D.#b.....L..#",
			"#..s.....t.........#.........#",
			"#.L.....L......L...###########",
			"#D=D=D.D=D=D.D=D=D.#..BB..BB.#",
			"#.5.......M.......4#.r.......#",
			"#...................J.BB..B.Z#",
			"#D=D=D.D=D=D.D=D=D.#....L...d#",
			"#.......z..........#..BB..B.H#",
			"#..L......L.....L..###########",
			"#####.#########.####c..H..s..#",
			"#..e..r....#r...b..#r........#",
			"#..kkkkkk6.#..L.......L....e.#",
			"#.Lkkkkkk.d...H.b..#kk...W.W.#",
			"#..........#.J.s.!.#o........#",
			"#H...o.....#.......#....J....#",
			"###############X##############",
		],
		"signs": ["ห้องหัวหน้าธนา", "ห้องเก็บเอกสาร", "ห้องประชุม", "ห้องถ่ายเอกสาร", "ห้องน้ำ"],
		"notes": [
			{"title": "ปฏิทินของหัวหน้าธนา", "reveal": "npc",
				"text": "ศุกร์ 22:00  ประชุมตัวต่อตัวกับต๋อง (3 ชม.)\nศุกร์ 23:00  ประชุมตัวต่อตัวกับต๋อง (3 ชม.)\nเสาร์ 00:00  ประชุมตัวต่อตัวกับต๋อง (3 ชม.)\n...ทุกช่องเขียนเหมือนกันหมด จนถึงสิ้นปี\n\nมุมล่าง: \"เดินตรวจโต๊ะลูกน้อง วนซ้าย-ขวา ทุก 10 นาที\nหยุดชะเง้อดูข้ามฉากกั้นเป็นระยะ\""},
			{"title": "ประกาศฝ่ายอาคาร", "evidence": true,
				"text": "ห้ามพนักงานอยู่ในอาคารหลัง 22:00 น.\nหากพบบุคคลในอาคารหลังเวลาดังกล่าว\nกรุณาแจ้ง รปภ. สมชาย ทันที\n\n(มีคนเขียนด้วยปากกาแดงไว้ข้างล่างว่า \"เขาไม่เคยกลับบ้าน\")"},
			{"title": "IT Ticket #4471", "evidence": true, "reveal": "goals",
				"text": "ผู้แจ้ง: เต้ (IT)\nเรื่อง: กล้อง CCTV ชั้น 4 ถูกหมุนไปทางโต๊ะคุณต๋องทุกคืน\nหมุนกลับแล้ว 12 ครั้ง\nสถานะ: รอ รปภ. ตอบกลับ\n\nป.ล. พี่ต๋องหาแฟ้มงบดุลอยู่ใช่ไหม ผมเห็นวางไว้\nห้องหัวหน้า · ห้องเก็บเอกสาร · ห้องประชุม"},
		],
		"triggers": [
			{"say": "ต๋อง: งบดุล 3 ชุด... น่าจะอยู่ห้องหัวหน้า ห้องเก็บเอกสาร แล้วก็ห้องประชุม"},
			{"say": "ต๋อง: ไฟห้องหัวหน้ายังเปิดอยู่...", "text": ["หัวหน้าธนา", "เห็นนะจ๊ะว่ายังไม่กลับ :)"]},
			{"text": ["เบอร์ไม่รู้จัก", "ประตูทางออกล็อกอยู่นะครับ ต้องเอาเอกสารไปให้ครบก่อน... ผมรออยู่ข้างล่าง"], "sfx": "whisper"},
		],
		"scares": [
			{"kind": "figure", "preset": "manager_long", "at": Vector2i(16, 12), "secs": 5.0, "sfx": "mutter"},
			{"kind": "lights_out", "secs": 3.5, "sfx": "door_slam", "line": "ต๋อง: ...ไฟดับ!? อย่าเพิ่งขยับ..."},
			{"kind": "behind", "preset": "guard", "secs": 4.0, "sfx": "whisper"},
			{"kind": "sound", "sfx": "knock", "at": Vector2i(25, 18), "line": "ต๋อง: ...มีคนอยู่ในห้องน้ำ? เคาะทำไม..."},
		],
		"texts": [
			[45.0, "เบอร์ไม่รู้จัก", "ทำงานดึกอีกแล้วนะครับ"],
			[100.0, "กลุ่ม IT", "เต้: ใครเห็นสาย LAN สีม่วงของผมบ้าง ผมจะมุดไปหาใต้โต๊ะทุกตัว"],
			[160.0, "แม่", "ลูก นอนที่ออฟฟิศเหรอ?"],
		],
		"clue_line": "ต๋อง: สายรัดข้อมือโรงพยาบาล...? ชื่อบนนี้... 'ต๋อง  เตียง 4'",
		"intro": [
			# Picks up from the tutorial's mirror: Tong jolts awake at a desk in the middle of the floor,
			# still working. The lights start to go, หัวหน้าธนา is there, his neck keeps coming... and
			# Tong runs for the corner where the stage starts (the spawn).
			["npc", Vector3(17, 0, 1.5), Vector3(9, 0, 6)],   # out of sight for now
			["cam", Vector3(9, 1.35, 6.58), Vector3(9, 1.0, 5.9), 0.0],
			["say", "ต๋อง: เฮือก—! ...เผลอหลับคาโต๊ะเหรอ เมื่อกี้ในกระจกนั่น... ฝันสินะ", 3.5],
			["say", "ต๋อง: 23:47 แล้ว... งบดุลยังไม่เสร็จเลย ทำต่อก่อน", 2.5],
			["say", "ต๋อง: ...เดี๋ยวนะ ทำไมจอคอมหันกลับด้านล่ะ? ตอนเย็นยังปกติอยู่เลย", 3.0],
			["cam", Vector3(9, 1.5, 6.7), Vector3(13, 1.0, 3.2), 1.6],   # looks up across the floor
			["say", "ต๋อง: ไม่ใช่แค่เครื่องเรา... หันกลับหมดทุกโต๊ะเลย ใครมาแกล้งหมุนเนี่ย น่ารำคาญชะมัด", 3.5],
			["cam", Vector3(9, 1.35, 6.58), Vector3(9, 1.0, 5.9), 0.8],
			["text", "แม่", "กลับกี่โมงลูก กับข้าวอยู่ในตู้เย็นนะ"],
			["wait", 1.5],
			["text", "หัวหน้าธนา", "ก่อนกลับ เอางบดุล 3 ชุดมาให้ผมด้วยนะจ๊ะ ^_^"],
			["say", "ต๋อง: ...หัวหน้ายังไม่กลับอีกเหรอ", 2.5],
			["lights", false], ["sfx", "metalClick"], ["wait", 0.2], ["lights", true], ["wait", 0.6],
			["lights", false], ["wait", 0.12], ["lights", true], ["wait", 0.9],
			["say", "ต๋อง: ...ไฟเป็นอะไรอีกล่ะ", 1.8],
			["lights", false], ["sfx", "squeak"], ["wait", 0.8],
			["npc", Vector3(13.6, 0, 4.6), Vector3(9, 0, 6.5)],
			["lights", true],
			["cam", Vector3(9, 1.55, 6.7), Vector3(13.6, 1.6, 4.6), 1.2],   # he stands up and looks
			["say", "ต๋อง: ...หัวหน้า? ยืนอยู่ตรงนั้นตั้งแต่เมื่อไหร่", 2.2],
			["lights", false], ["sfx", "squeak"], ["wait", 0.6],
			["npc", Vector3(10.8, 0, 5.3), Vector3(9, 0, 6.7)],   # closer. Nobody saw him walk.
			["lights", true],
			["cam", Vector3(9, 1.55, 6.7), Vector3(10.8, 1.7, 5.3), 0.3],
			["act", "cut_stretch"],
			["cam", Vector3(9, 1.55, 6.8), Vector3(10.8, 2.5, 5.3), 3.2],   # eyes follow the head up
			["say", "หัวหน้าธนา: งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ~?", 2.2],
			["sfx", "sting"], ["sfx", "gasp"],
			["cam", Vector3(8.2, 1.5, 7.0), Vector3(5, 1.4, 7.0), 0.4],   # he bolts: down the aisle...
			["sfx", "footstep00"],
			["cam", Vector3(6, 1.5, 7.0), Vector3(6, 1.4, 4), 0.6],
			["sfx", "footstep02"],
			["lights", false],
			["cam", Vector3(6, 1.5, 4.4), Vector3(6, 1.4, 1), 0.6],   # ...through the gap in the desks...
			["lights", true], ["sfx", "footstep01"],
			["cam", Vector3(5.5, 1.5, 1.6), Vector3(1, 1.2, 1), 0.6],
			["sfx", "footstep03"],
			["cam", Vector3(1.3, 0.95, 1.0), Vector3(6, 1.0, 2.5), 0.9],   # ...and down in the far corner, spinning to look back
			["say", "ต๋อง: (แฮ่ก... แฮ่ก... นั่นมันอะไรกัน...)", 2.0],
			["lights", false], ["sfx", "squeak"], ["wait", 0.4],
			["npc", Vector3(9, 0, 4), Vector3(2, 0, 2)],
			["act", "cut_peek"],
			["lights", true], ["fov", 42.0],
			["cam", Vector3(1.4, 0.95, 1.3), Vector3(9, 2.2, 4), 1.2],   # peeking back over the partitions
			["say", "หัวหน้าธนา: ต๋อง~ อยู่ไหนจ๊ะ... มาคุยกันหน่อย แค่ 3 ชั่วโมงเอง", 3.0],
			["say", "ต๋อง: (อย่าให้เขาเห็น... ก้มหลบหลังฉากกั้น แล้วค่อยๆ ไปเก็บงบดุลให้ครบ)", 3.0],
		],
	},
	{
		"title": "ด่าน 2 : โถงทางเดิน & โซนพักผ่อน",
		"clock": "00:31",
		"story": [   # black-screen text before the stage (first visit only)
			"ตอนเช้า ป้าพรยังร่าเริง เอากาแฟมาให้ตอนต๋องกำลังเหนื่อยๆ อยู่เลย",
			"ตอนเย็น ก่อนป้ากลับ มีคนเผลอไปเหยียบน้ำ ตรงที่ป้าเพิ่งถูพื้น\nได้ยินเสียงล้มดังโครม... แต่ไม่มีใครยอมรับว่าเป็นใคร",
			"คืนนี้ป้ากลับมา เหวี่ยงขึ้นเรื่อยๆ ถูพื้นวนไปทั้งชั้นจนเปียกไปหมด\nใครเหยียบรอยเปียก ป้าไล่ไม่เลิก",
			"ส่วนต๋อง... ปวดหัวตุบๆ มาตั้งแต่บ่าย\nตอนนี้อยากได้กาแฟสักแก้ว ที่โซนพัก",
		],
		"objective": "ชงกาแฟที่โซนพัก (%d/1) ห้ามเหยียบพื้นเปียก! — ชงเสร็จแล้ววิ่งไปลิฟต์ (ขวาล่าง)",
		"goal": 1,
		"rage_on_goal": true,
		"wet_start": 30,
		"rage_line": "ป้าพร: นั่นถ้วยกาแฟป้าาา!! ใครชงงง!! สาธุ... ไม่รอดแน่!!",
		"rage_objective": "หนี!! ป้าพรไล่มาแล้ว — วิ่งไปลิฟต์ (ตามลูกศรเขียว)",
		"floor": Color(0.5, 0.48, 0.44), "wall": Color(0.62, 0.68, 0.66), "light": Color(1.0, 0.95, 0.8),
		"map": [
			"##############################",
			"#o..L.....o....L.....o...L...#",
			"#P.!.....1..J.......r....2...#",
			"#............s..........t....#",
			"#####.########.##########...##",
			"#....r...L#...r..L...####...##",
			"#W.W.W....#bb.BB.BB.b####.o.##",
			"#....J...H#...J......####...##",
			"#s..o.....#bb.BB.BB.Z####.L.##",
			"#e.......L#H.......s.####.3.##",
			"################.########.J.##",
			"#L.....o.......L.....r..#...##",
			"#..kk....kk....kk....c.!..4.##",
			"#..kk..S.kk....kk.......#...##",
			"#......6........5.......#...##",
			"#o.kk....kk....kk....H..#.L.##",
			"#e....................s.#...##",
			"#C.........L..........zo#.!.##",
			"#########################..g##",
			"##########################X###",
		],
		"signs": ["โถงทางเดิน ชั้น 4", "ห้องน้ำ", "ห้องเก็บของ", "โซนพักผ่อน · กาแฟ"],
		"notes": [
			{"title": "กระดาษแปะกระจกห้องน้ำ", "reveal": "npc",
				"text": "ใครเหยียบพื้นที่ป้าเพิ่งถู\nป้าจะพรมน้ำมนต์ไล่ให้ถึงบ้าน\nสาธุ\n\n— ป้าพร\n\n(ลายมือคนอื่น: ป้าถูวนหน้าลิฟต์ → ห้องเก็บของ → โซนพัก\nรอยเปียกแห้งเองในไม่กี่วิ รอได้ก็รอ)"},
			{"title": "ใบแจ้งซ่อม", "evidence": true, "reveal": "hides",
				"text": "เครื่องชงกาแฟโซนพัก: ชงเองตอนตีสาม (ถ้วยใบนั้นของป้าพร ห้ามแตะ!)\nไฟทางเดินชั้น 4: กะพริบทุกคืน\nลิฟต์: จอดชั้น 4 เองทั้งที่ไม่มีใครกด\n\nผู้รับเรื่อง: รปภ. สมชาย  —  \"ไม่พบความผิดปกติ\"\n\nป.ล. ล็อกเกอร์โซนพัก ป้าพรไม่เคยเปิด"},
		],
		"triggers": [
			{"say": "ต๋อง: ได้กลิ่นน้ำยาถูพื้น... ป้าพรยังไม่กลับ"},
			{"say": "ต๋อง: เครื่องชงกาแฟอยู่สุดห้อง... ระวังรอยเปียก", "text": ["เบอร์ไม่รู้จัก", "กาแฟดำไม่ใส่น้ำตาล เหมือนทุกวันเลยนะครับ"]},
			{"say": "ต๋อง: ลิฟต์... ลงไปห้องเซิร์ฟเวอร์ได้", "sfx": "elevator_ding"},
		],
		"scares": [
			{"kind": "figure", "preset": "sweeper", "at": Vector2i(22, 3), "secs": 5.0, "sfx": "hum"},
			{"kind": "sound", "sfx": "knock", "at": Vector2i(3, 6), "line": "ต๋อง: (เสียงเคาะ... จากในห้องน้ำ)"},
			{"kind": "lights_out", "secs": 4.0, "sfx": "door_slam"},
			{"kind": "behind", "preset": "sweeper", "secs": 4.0, "sfx": "splash"},
		],
		"texts": [
			[30.0, "แม่", "แม่อุ่นกับข้าวให้แล้วนะ"],
			[90.0, "หัวหน้าธนา", "งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ"],
			[150.0, "เบอร์ไม่รู้จัก", "ป้าพรชอบคุณนะครับ ผมก็ชอบ"],
		],
		"clue_line": "ต๋อง: ถุงน้ำเกลือ...? ในห้องเก็บของออฟฟิศเนี่ยนะ ...ได้ยินเสียงเครื่องวัดหัวใจแว่วๆ",
		"intro": [
			# Out of แผนกบัญชี at the east end of the corridor, on foot: under the hallway sign, a glance
			# through the storeroom and washroom doors... then humming behind him. ป้าพร is mopping
			# right where he just walked. He backs off into the corner where the stage starts.
			["npc", Vector3(7, 0, 15), Vector3(7, 0, 12)],   # mopping the lounge for now: out of sight
			["cam", Vector3(23, 1.6, 2), Vector3(17, 2.0, 2), 0.0],
			["sfx", "doorOpen_1"],
			["sub", "ต๋อง: (หนีออกมาจากแผนกบัญชีได้แล้ว... หัวหน้าไม่ได้ตามมาใช่ไหม)", 3.5],
			["walk", Vector3(19.5, 1.6, 2), Vector3(14, 1.8, 2), 3.0],   # under the sign "โถงทางเดิน ชั้น 4"
			["walk", Vector3(14, 1.6, 3.3), Vector3(14, 2.1, 6), 4.0],   # up to the storeroom door: its sign
			["sub", "ต๋อง: (ห้องเก็บของ... ห้องน้ำ... โซนพักต้องอยู่ถัดไปอีก ขอกาแฟสักแก้วก่อน)", 4.5],
			["look", Vector3(6, 1.6, 2), 0.8],
			["walk", Vector3(7.5, 1.6, 2.3), Vector3(2, 1.6, 2.3), 3.5],   # on down the corridor...
			["walk", Vector3(5.4, 1.6, 2.4), Vector3(5, 1.9, 6), 2.0],   # ...and a look through the washroom door
			["npc", Vector3(11, 0, 2.6), Vector3(5.6, 0, 2.4)],   # ...and she's behind him
			["sfx", "hum", "npc"],
			["say", "(เสียงฮัมเพลงผิดคีย์... ดังมาจากข้างหลัง)", 2.2],
			["look", Vector3(11, 1.3, 2.6), 1.2],   # turns round
			["act", "cut_sprinkle"],
			["say", "ป้าพร: พื้นสะอาด~ ใครเหยียบ ป้าสาป~ สาธุ สาธุ~", 3.0],
			["say", "ต๋อง: (ตรงนั้นเราเพิ่งเดินผ่านมาเมื่อกี้... ไม่เห็นมีใครเลยนี่!)", 2.8],
			["walk", Vector3(2.2, 1.6, 2), Vector3(11, 1.3, 2.6), 2.4],   # backs off into the corner
			["player", 0.8],
			["say", "ต๋อง: ต้องไปชงกาแฟที่โซนพัก แล้วรีบไปลิฟต์... ห้ามเหยียบรอยเปียกเด็ดขาด", 3.0],
		],
	},
	{
		"title": "ด่าน 3 : ห้องเซิร์ฟเวอร์",
		"clock": "01:12",
		"story": [   # black-screen text before the stage (first visit only)
			"ตอนเช้า เต้ยังมาช่วยลงโปรแกรมให้ ไม่สบตาเหมือนเดิม แต่ก็ใจดี",
			"ตีหนึ่ง ต๋องเจอสายสีม่วงเส้นหนึ่งเสียบอยู่ใต้โต๊ะตัวเอง\nสาย LAN ที่เต้ตามหามาทั้งวัน... ต๋องดึงมันออก เพื่อเสียบชาร์จมือถือ",
			"สองนาทีต่อมา เซิร์ฟเวอร์ล่ม ไฟดับทั้งชั้น\nเต้มุดลงใต้โต๊ะ... แล้วก็ไม่ขึ้นมาอีกเลย",
			"งบดุลลับอยู่ในคอมห้อง Admin\nจะเข้าได้ ต้องเอาไฟกลับมาก่อน",
		],
		"objective": "ไฟดับทั้งชั้น! สับเบรกเกอร์ (ห้องเก็บอุปกรณ์) · หาโพสต์อิทรหัส 3 ใบ · ล็อกอินคอมห้อง Admin (%d/4)",
		"goal": 4,
		"dark_start": true,
		"pc_code": "4471",
		"floor": Color(0.22, 0.25, 0.3), "wall": Color(0.4, 0.44, 0.5), "light": Color(0.6, 0.8, 1.0),
		"map": [
			"##############################",
			"#P..#L......L......L.#..L...H#",
			"#!..#.BBBB.BBBB.BBBB.#.r.....#",
			"#....r1..J.u.......2.#.....u.#",
			"#...#.BBBB.BBBB.BBBB.#...K...#",
			"#t..#......G.......u.......z.#",
			"#...#.BBBB.BBBBZBBBB.#H.....H#",
			"#...#.4......L.....3.#e..L..s#",
			"#.z.#.BBBB.BBBB.BBBB.#.......#",
			"#...#..........u.....#########",
			"#.L.#.BBBB.BBBB.BBBB.#b..b..H#",
			"#.u.#......n.........#bb..n..#",
			"#...#.L............L.#...e..b#",
			"#...########.#########b.....Y#",
			"#.J.#........J.......#..L....#",
			"#...#.D.D.D.5.D.D.D...r......#",
			"#...#....u...........#b.H....#",
			"#....rD.D.n.D.D.D.6..#..s....#",
			"#...#......L.....z...#..L..u.#",
			"#.g.#.D.D.D.D.D.D.D..#o......#",
			"X...#s.............!.#.......#",
			"##############################",
		],
		"signs": ["ห้อง Admin", "ห้องเซิร์ฟเวอร์", "ห้องเก็บอุปกรณ์", "แผนกไอที"],
		"notes": [
			{"title": "Log ห้อง Admin", "evidence": true,
				"text": "01:02  login: somchai (รปภ.)\n01:03  เปิดไฟล์: CCTV_ชั้น4_โต๊ะต๋อง.mp4\n01:03  เปิดไฟล์: CCTV_ชั้น4_โต๊ะต๋อง(2).mp4\n01:04  เปิดไฟล์: ที่อยู่พนักงาน.xlsx\n01:05  ค้นหา: \"ต๋อง บ้าน ซอย\"\n01:06  ตัดไฟชั้น 3"},
			{"title": "โน้ตของเต้", "reveal": "hides",
				"text": "อย่าเชื่อเสียงบี๊บๆ ในห้องเซิร์ฟเวอร์ มันไม่ใช่ UPS\nเหมือนเครื่องในโรงพยาบาลเลย\n\nถ้าไฟดับ ผมมองเห็นแสงไฟฉายจากไกลมาก\nใต้โต๊ะเป็นที่ของผม ใครมุดผมรู้ — ล็อกเกอร์ปลอดภัยกว่า"},
		],
		"postits": [
			{"title": "โพสต์อิทสีเหลือง (1/3)", "text": "รหัสห้อง Admin\n\n4 _ _ _\n\n— เต้ (อย่าบอก รปภ.)"},
			{"title": "โพสต์อิทสีเหลือง (2/3)", "text": "_ 4 7 _\n\nเตียง 4 ...ห้อง 7?\nทำไมผมจำเลขนี้ได้"},
			{"title": "โพสต์อิทสีเหลือง (3/3)", "text": "_ _ _ 1\n\nใส่ผิด เครื่องจะร้องดังลั่นห้องนะ!"},
		],
		"triggers": [
			{"say": "ต๋อง: ไฟดับทั้งชั้น... มีแต่ไฟฉุกเฉินสีแดง ต้องไปสับเบรกเกอร์ที่ห้องเก็บอุปกรณ์", "text": ["กลุ่ม IT", "เต้: ใครอยู่ห้องเซิร์ฟเวอร์ตอนนี้ครับ ผมเห็นไฟ login ขึ้น ...แล้วใครตัดไฟ?"]},
			{"photo": true, "text": ["เบอร์ไม่รู้จัก", "ถ่ายมุมนี้หล่อดีนะครับ ไฟดับแบบนี้ผมชอบ"]},
		],
		"scares": [
			{"kind": "figure", "preset": "goblin", "at": Vector2i(19, 5), "secs": 4.0, "sfx": "techspeak"},
			{"kind": "behind", "preset": "guard", "secs": 4.0, "sfx": "guard_talk"},
			{"kind": "sound", "sfx": "techspeak", "at": Vector2i(8, 15), "line": "ต๋อง: (ใต้โต๊ะ... มีเสียงพึมพำ)"},
		],
		"texts": [
			[40.0, "แม่", "ลูกไม่รับสาย แม่เป็นห่วงนะ"],
			[110.0, "หัวหน้าธนา", "เจอเต้ไหมจ๊ะ บอกให้มาประชุมด้วย 3 ชั่วโมง"],
		],
		"clue_line": "ต๋อง: เสียงบี๊บ... นี่มันเครื่องวัดชีพจร ไม่ใช่เซิร์ฟเวอร์...",
		"intro": [
			# Down in the lift, in through the door at the bottom of the corridor (X), which locks behind
			# him. Up the dark corridor past the แผนกไอที door, to the server room door... where เต้
			# comes up out of the floor. He backs off to the top of the corridor where the stage starts.
			["npc", Vector3(17, 0, 11), Vector3(17, 0, 9)],   # under a desk somewhere for now: out of sight
			["cam", Vector3(2.6, 1.6, 20.2), Vector3(3.3, 1.5, 14), 0.0],   # (พี่สมชาย's cameo spot g is just behind-left: keep it out of shot)
			["sfx", "elevator_ding"],
			["sub", "(ลิฟต์ลงมาถึงชั้นห้องเซิร์ฟเวอร์... ไฟดับทั้งชั้น มีแต่ไฟฉุกเฉินสีแดง)", 3.5],
			["wait", 0.6],
			["sfx", "metalLatch"],   # the door locks behind him
			["walk", Vector3(1.6, 1.6, 17), Vector3(6, 2.0, 17), 2.6],   # square on to the IT department door: its sign
			["say", "ต๋อง: (แผนกไอที... จอดับหมดทุกจอ ไม่มีใครอยู่สักคน)", 2.4],
			["look", Vector3(2, 1.5, 12), 0.8],
			["sub", "ต๋อง: (ต้องหาเบรกเกอร์... ห้องเก็บอุปกรณ์อยู่ไหนนะ)", 3.5],
			["walk", Vector3(2, 1.6, 10), Vector3(2, 1.5, 4), 4.5],   # up the corridor, under the red lights
			["sfx", "techspeak", "npc"],   # muttering somewhere off in the dark
			["walk", Vector3(2, 1.6, 3), Vector3(2, 1.5, 0), 4.0],   # ...to the server room door
			["npc", Vector3(6.4, 0, 3), Vector3(10, 0, 3)],   # in the aisle, his back to the door
			["act", "cut_writhe"],
			["look", Vector3(7, 1.8, 3), 0.9],   # square on through the door: its sign... and someone under it
			["say", "(ห้องเซิร์ฟเวอร์... มีคนยืนอยู่ในนั้น ดิ้นไปมาเหมือนโดนไฟช็อต)", 2.8],
			["say", "ต๋อง: ...เต้? เป็นอะไรรึเปล่า", 1.8],
			["walk", Vector3(3.7, 1.6, 3), Vector3(6.4, 1.5, 3), 2.8],   # slowly, into the doorway
			["act", "cut_split"],   # snaps round to face him: two heads
			["lights", true], ["wait", 0.12], ["lights", false], ["wait", 0.1], ["lights", true],   # the power stutters
			["walk", Vector3(3.3, 1.6, 3), Vector3(6.4, 1.9, 3), 0.4],   # flinches back
			["lights", false], ["wait", 0.5], ["lights", true], ["wait", 0.15], ["lights", false],
			["wait", 0.4],   # ...and it's one head again
			["say", "เต้: IP? DNS? 01101!! ...อ้าว พี่ต๋อง ไฟดับแบบนี้ผมมองเห็นแสงไฟฉายพี่ชัดเลยนะ", 3.5],
			["say", "ต๋อง: (เมื่อกี้... หัวมัน... ตาฝาดไปเองใช่ไหม)", 2.4],
			["walk", Vector3(1.6, 1.6, 2), Vector3(6.4, 1.2, 3), 1.8],   # backs off up the corridor
			["player", 0.8],
			["say", "ต๋อง: เบรกเกอร์ → โพสต์อิทรหัส 3 ใบ → คอมห้อง Admin ...ใช้ไฟฉายเท่าที่จำเป็น", 3.5],
		],
	},
	{
		"title": "ด่าน 4 : ออกจากบริษัท",
		"clock": "01:58",
		"story": [   # black-screen text before the stage (first visit only)
			"พี่สมชาย รปภ. กะดึก ไม่เคยนั่งที่ป้อมหน้าลิฟต์\nเขาอยู่ในห้อง รปภ. หน้าจอกล้องวงจรปิด ทุกคืน",
			"เขาทักต๋องด้วยชื่อทุกวัน ทั้งที่ต๋องไม่เคยบอกชื่อ\nเขารู้ว่าต๋องชอบกินข้าวมันไก่ไม่เอาหนังได้ยังไงก็ไม่รู้",
			"คืนนี้งานเสร็จแล้ว เหลือแค่สแกนนิ้วออก\nแต่ทุกครั้งที่หันหลังให้... เขาดูเหมือนจะใกล้เข้ามา",
		],
		"objective": "เก็บฟิวส์ (ห้อง รปภ.) → ใส่แผงวงจร (ห้องจดหมาย) → สแกนนิ้วที่ทางออก (%d/3) — มองพี่สมชายไว้ตลอด!",
		"goal": 3,
		"flicker": Vector2(22.0, 38.0),
		"finale": true,
		"exit_label": "สแกนนิ้วออกงาน",
		"floor": Color(0.45, 0.42, 0.4), "wall": Color(0.55, 0.5, 0.45), "light": Color(1.0, 0.85, 0.7),
		"map": [
			"##############################",
			"###########....P....##########",
			"###########.!.......##########",
			"#o......L......r......L.....o#",
			"#...u........................#",
			"#...#.....#.....#.....#..u...#",
			"#....b..J.......t.........s..#",
			"#.L...........L..........L...#",
			"#...#.....#.kkkkk.#.....#....#",
			"#...........k.T.kR...........#",
			"#...........k...k............#",
			"#...#.....#.......#.....#....#",
			"#.L..........e.L..........L..#",
			"#o.....u....................o#",
			"#####.#######......#####.#####",
			"#r..B.BBB.##..kkkk..##r..b.bH#",
			"#...D.D..H##...Z....##b...b..#",
			"#.e......s##..L..L..##..H..z.#",
			"#L......!p##.F..u...##L..Jfbb#",
			"##############X###############",
		],
		"signs": ["ล็อบบี้ · ทางออก", "ห้อง รปภ.", "ห้องจดหมาย"],
		"notes": [
			{"title": "สมุดเวร รปภ.", "evidence": true, "reveal": "goals",
				"text": "22:00  ตรวจชั้น 4 — คุณต๋องยังอยู่\n23:00  ตรวจชั้น 4 — คุณต๋องยังอยู่\n00:00  ตรวจชั้น 4 — คุณต๋องยังอยู่ ยิ้มให้ผมด้วย\n01:00  ซื้อข้าวมันไก่ 2 ห่อ\n01:30  ปิดเครื่องสแกนนิ้วชั้นล่าง ...กดค้างนานๆ ถึงจะผ่าน\n01:45  รอ"},
			{"title": "บันทึกห้อง CCTV", "evidence": true, "reveal": "hides",
				"text": "กล้อง 1-12: ชี้ไปที่โต๊ะคุณต๋อง\nกล้อง 13: ชี้ไปที่บ้านคุณต๋อง\n\nกล้อง 13 ไม่ได้อยู่ในรายการอุปกรณ์ของบริษัท\n\n(ใต้โต๊ะมีลายมือ: ไฟตึกนี้ดับเป็นพักๆ\nตอนมืด... อย่าละสายตา เปิดไฟฉายส่องเขาไว้)"},
		],
		"triggers": [
			{"say": "ต๋อง: ล็อบบี้... ป้อม รปภ. ว่างเปล่า พี่สมชายหายไปไหน?"},
			{"say": "ต๋อง: จอทุกจอ... หันมาที่โต๊ะเรา", "text": ["เบอร์ไม่รู้จัก", "ชอบห้องนี้ไหมครับ ผมนั่งดูคุณทุกคืนเลย"], "sfx": "whisper"},
		],
		"scares": [
			{"kind": "lights_out", "secs": 3.0, "sfx": "whisper", "line": "ต๋อง: (ไฟดับ!... เขาอยู่ไหน?! เปิดไฟฉาย!)"},
			{"kind": "sound", "sfx": "knock", "at": Vector2i(27, 18), "line": "ต๋อง: (เสียงเคาะ... จากในกล่องพัสดุ?)"},
		],
		"texts": [
			[25.0, "เบอร์ไม่รู้จัก", "หันหลังให้ผมทำไมครับ"],
			[70.0, "แม่", "ถึงไหนแล้วลูก"],
		],
		"clue_line": "ต๋อง: การ์ดอวยพร... 'หายไวๆ นะต๋อง — จากเพื่อนร่วมงานทุกคน' ...ใครป่วย?",
		"intro": [
			# His booth in the lobby is empty: he is in the security room (his CCTV wall, his bed), standing
			# at the monitors with his back to the door. He stays there until the lights first go out or
			# his phone is taken (Guard > Waits For Dark in stage_4.tscn). Putting the fuse in kills the
			# lights for good (fuse_power_cut), so that is when he comes at the latest.
			["cam", Vector3(13, 1.6, 3), Vector3(14, 1.0, 9), 0.0],
			["say", "(ล็อบบี้เงียบสนิท... ป้อม รปภ. ว่างเปล่า)", 2.5],
			["cam", Vector3(5, 1.7, 15.25), Vector3(5, 1.5, 17.65), 0.0],
			["say", "(ห้อง รปภ. — จอกล้องวงจรปิดทุกจอ เป็นภาพของต๋อง)", 3.0],
			["cam", Vector3(5, 1.7, 16.65), Vector3(5, 1.7, 17.65), 2.5],
			["sfx", "sting"],
			["say", "พี่สมชาย: ...กลับบ้านเหรอครับ คุณต๋อง ผมดูอยู่นะ", 3.0],
			["say", "ต๋อง: (เขาเห็นเราจากกล้อง... ไฟดับเมื่อไหร่ เขาออกมาแน่ ต้องมองเขาไว้ตลอด)", 3.5],
			["say", "ต๋อง: (เครื่องสแกนนิ้วไม่มีไฟ... ต้องเอาฟิวส์ในห้องเขา ไปใส่แผงวงจรที่ห้องจดหมาย)", 3.5],
		],
	},
]

# Stage 0, before stage 1 (scenes/stages/tutorial.tscn, run by tutorial.gd): a bright Friday afternoon,
# everyone at work and happy to chat -> night falls and they go home -> the stranger's texts -> the
# washroom mirror. "coworkers" = the 'A' cells in reading order (to / look are map cells);
# "windows" = wall cells that get a window; the rows under the 'm' mirror repeat the washroom above it.
const TUTORIAL := {
	"title": "บทนำ : เย็นวันศุกร์ ก่อนกะดึก",
	"clock": "17:30",
	"story": [   # black-screen text before the stage (first visit only)
		"วันศุกร์ 08:00 น.\nออฟฟิศยังเป็นออฟฟิศธรรมดา ทุกคนยิ้มให้กัน ทักทายกันตามปกติ",
		"แล้ว HR ก็ประกาศ:\n\"ปิดงบสิ้นเดือน ทุกคนอยู่กะดึก ห้ามกลับก่อนงานเสร็จ\"",
		"ต๋องแค่อยากเลิกงานไวๆ\nแค่อยากทำงานเงียบๆ ให้เสร็จ แล้วกลับบ้านไปกินกับข้าวที่แม่ทำไว้",
	],
	"objective": "เย็นวันศุกร์ที่ออฟฟิศชั้น 4",
	"goal": 0,
	"screens_ok": true,
	"floor": Color(0.36, 0.36, 0.4), "wall": Color(0.7, 0.7, 0.66), "light": Color(0.85, 0.95, 0.9),
	"map": [
		"########################",
		"#o...L......L.....#..L.#",
		"#.D=D=D...D=D=D...#.D.o#",
		"#.P.........A.....r....#",
		"#.................#....#",
		"#.D=D=D...D=D=D...######",
		"#....................rA#",
		"#..L.......L.......L...#",
		"#..A...................#",
		"###r#######r########r###",
		"#......##.....##......o#",
		"#k....L##..L..##.B.B.L.#",
		"#c.....##immmi##.A.....#",
		"#k.....##..L..##....D..#",
		"#kk..e.##.....##.......#",
		"########################",
	],
	"signs": ["ห้องหัวหน้าธนา", "จุดตรวจ รปภ.", "Pantry", "ห้องน้ำ", "แผนกไอที"],
	"windows": [Vector2i(3, 0), Vector2i(4, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(13, 0), Vector2i(14, 0), Vector2i(20, 0),
		Vector2i(0, 6), Vector2i(0, 7), Vector2i(23, 7), Vector2i(23, 8)],
	"mirror_faces": Vector2i(0, -1),
	"coworkers": [
		{"preset": "manager", "display_name": "หัวหน้าธนา", "work": "walk", "to": Vector2i(20, 3), "leave_at": 0.7,
			"lines": ["หัวหน้าธนา: อ้าวต๋อง! งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ~ ไม่ต้องรีบนะ วันนี้วันศุกร์",
				"หัวหน้าธนา: คืนนี้ฝากงบดุล 3 ชุดด้วยนะจ๊ะ ผมไว้ใจต๋องที่สุดเลย ^_^"],
			"bye": "หัวหน้าธนา: ผมกลับก่อนนะจ๊ะ~ ฝากปิดไฟด้วย ...งบดุล 3 ชุด อย่าลืมล่ะ"},
		{"preset": "guard", "display_name": "พี่สมชาย", "work": "stand", "look": Vector2i(15, 6), "leave_at": 1.0,
			"lines": ["พี่สมชาย: สวัสดีครับคุณต๋อง วันนี้กลับดึกอีกไหมครับ... เดี๋ยวผมเปิดไฟรอไว้ให้",
				"พี่สมชาย: ข้าวมันไก่ร้านปากซอยอร่อยนะครับ คุณไม่เอาหนังใช่ไหม ผมจำได้"],
			"bye": "พี่สมชาย: ผมลงไปเฝ้าข้างล่างนะครับ... ผมไม่ไปไหนหรอก"},
		{"preset": "sweeper", "display_name": "ป้าพร", "work": "mop", "to": Vector2i(14, 8), "speed": 0.9, "leave_at": 0.0,
			"lines": ["ป้าพร: ระวังลื่นนะลูก ป้าเพิ่งถูตรงนี้ ...กินข้าวกินปลาหรือยังล่ะ",
				"ป้าพร: ทำงานดึกบ่อยๆ ไม่ดีนะลูก หน้าตาโทรมหมดแล้ว กาแฟใน Pantry ป้าชงไว้ให้นะ"],
			"bye": "ป้าพร: ป้ากลับก่อนนะลูก อย่าอยู่ดึกนักล่ะ สาธุ"},
		{"preset": "goblin", "display_name": "เต้", "work": "type", "look": Vector2i(17, 11), "offset": Vector3(0, 0, -0.45), "leave_at": 0.35,
			"lines": ["เต้: พี่ต๋อง! เห็นสาย LAN สีม่วงของผมไหมครับ ผมว่ามันตกอยู่ใต้โต๊ะสักตัวนี่แหละ",
				"เต้: คอมค้างเมื่อไหร่เรียกผมได้เลยนะพี่ ผมอยู่ถึงดึกทุกวันอยู่แล้ว ฮ่าๆ"],
			"bye": "เต้: ผมไปก่อนนะพี่ต๋อง! ถ้าได้ยินเสียงกุกกักใต้โต๊ะ... ไม่ใช่ผมนะ"},
	],
	# The stranger's texts. Tong can't do anything until he has opened the phone and read them.
	"phone": {
		"sender": "เบอร์ไม่รู้จัก",
		"controls": [
			"สวัสดีครับคุณต๋อง ผมแค่อยากช่วย... อ่านให้จบก่อนนะครับ",
			"เดิน: W A S D · หันมอง: เมาส์ · วิ่ง: กด Shift ค้าง (แถบสีฟ้าคือแรงที่เหลือ)",
			"ก้มย่องเงียบๆ: C",
			"หยิบ / อ่าน / คุย / ซ่อนตัว: มองแล้วกด E",
			"ตอนซ่อนอยู่กด Space ค้าง = กลั้นหายใจ",
			"ขว้างของล่อ: Q หรือคลิกขวา · มือถือ: Tab",
			"ไฟฉาย: F (กินแบตมือถือ) · หยุดเกม: Esc",
			"ลองเดินไปทักทายทุกคนดูสิครับ ตอนนี้พวกเขายัง... ปกติดี",
		],
		"rumour": [
			"ยังไม่กลับอีกเหรอครับ ...กะดึกอีกแล้วสินะ",
			"เคยได้ยินเรื่องเล่าของบริษัทนี้ไหมครับ — ใครที่ทำงานกะดึกบ่อยๆ จะเริ่มเจออะไรแปลกๆ",
			"เขาว่าเป็นเพราะความเครียดสะสม... พอ Social Battery ใกล้หมด ก็จะเห็นเพื่อนร่วมงานในที่ที่ไม่ควรมีใครอยู่",
			"ถ้าไม่เชื่อ ลองไปล้างหน้าที่ห้องน้ำ แล้วส่องกระจกดูสิครับ",
		],
	},
	"notes": [
		{"title": "คู่มือพนักงานกะดึก (ฉบับไม่เป็นทางการ)",
			"text": "1. ได้ยินเสียงฝีเท้า = ก้ม (C) หลบหลังฉากกั้น\n2. โน้ตทุกใบในตึกนี้มีประโยชน์ อ่านให้หมด\n3. ล็อกเกอร์ / ห้องน้ำ / ใต้โต๊ะ = ที่ซ่อน\n4. กาแฟ = Social Battery +40\n5. ถ้า Social Battery ใกล้หมด... อย่าเชื่อสิ่งที่เห็น\n\n— ใครก็ไม่รู้"},
	],
	"texts": [],
	"intro": [
		["cam", Vector3(4, 2.3, 7.5), Vector3(13, 1.0, 3), 0.0],
		["say", "วันศุกร์ 17:30 น. · ออฟฟิศชั้น 4 — ทุกคนยังทำงานกันตามปกติ", 3.0],
		["cam", Vector3(15, 1.5, 4.2), Vector3(12, 1.4, 3), 0.0],
		["say", "หัวหน้าธนา: วันศุกร์แล้ว สู้ๆ นะจ๊ะทุกคน~ งานคืบหน้ากี่เปอร์เซ็นต์กันแล้ว", 3.0],
		["cam", Vector3(2, 1.45, 3.2), Vector3(2, 1.0, 2), 0.0],
		["say", "ต๋อง: เย็นวันศุกร์... ขอแค่คืนนี้อย่าต้องอยู่กะดึกอีกเลย", 3.0],
	],
}
const GUARD_CALLS := [
	"พี่สมชาย (โทรศัพท์): ซื้อข้าวมันไก่มาฝากไหมครับ...? ผมรู้นะว่าคุณชอบไม่เอาหนัง",
	"พี่สมชาย (โทรศัพท์): วันนี้คุณใส่เสื้อสีฟ้าอีกแล้วนะครับ... เหมือนเมื่อวาน... เมื่อวานซืน...",
	"พี่สมชาย (โทรศัพท์): บ้านคุณอยู่ซอยเดียวกับผมเลยนะ... ผมเดินตามไปดูมาแล้ว",
	"พี่สมชาย (โทรศัพท์): ไม่ต้องรีบนะครับ... เดี๋ยวผมไปส่งถึงบ้านเอง",
]

# 3D ending vignettes: tiny maps + cutscene, then the ending card in main.gd.
const ENDING_SCENES := {
	"A": {
		"map": ["##########", "#o......o#", "#...L....#", "#........#", "#........#", "##########"],
		"floor": Color(0.2, 0.2, 0.22), "wall": Color(0.3, 0.3, 0.35), "light": Color(0.7, 0.8, 1.0),
		"steps": [
			["body", "tong", Vector3(4, 0, 2), Vector3(4, 0, 4)],
			["cam", Vector3(4, 1.6, 4.4), Vector3(4, 1.4, 2), 0.0],
			["say", "ต๋อง: (เปิดมือถือพี่สมชาย...) รูปเรา... รูปเรา... ทั้งอัลบั้มเลย", 3.5],
			["say", "ต๋อง: ฮัลโหล 191 ครับ... ผมจะแจ้งความ", 3.0],
			["flash", "police"], ["wait", 0.6], ["flash", "police"], ["wait", 0.6], ["flash", "police"],
			["cam", Vector3(4, 3.5, 5.0), Vector3(4, 1.0, 2), 3.0],
		],
	},
	"B": {
		"map": ["#########", "#o..L..o#", "#...Q...#", "#.......#", "#########"],
		"floor": Color(0.75, 0.8, 0.8), "wall": Color(0.85, 0.9, 0.9), "light": Color(0.9, 1.0, 1.0),
		"steps": [
			["body", "doctor", Vector3(2.6, 0, 2.6), Vector3(4, 0, 2)],
			["body", "manager_long", Vector3(5.4, 0, 2.6), Vector3(4, 0, 2)],
			["cam", Vector3(4, 1.0, 2.2), Vector3(4, 2.9, 1.0), 0.0],
			["sfx", "beep"], ["wait", 1.0], ["sfx", "beep"],
			["say", "หมอ: ฟื้นแล้วเหรอครับ คุณหมดสติเพราะทำงานหนักเกินไป", 3.0],
			["cam", Vector3(4, 1.0, 2.2), Vector3(2.6, 1.8, 2.6), 1.2],
			["say", "หันซ้าย... คุณหมอยิ้มให้", 2.0],
			["cam", Vector3(4, 1.0, 2.2), Vector3(5.4, 2.5, 2.6), 1.2],
			["sfx", "squeak"],
			["say", "หันขวา... \"งานคืบหน้ากี่เปอร์เซ็นต์แล้วจ๊ะ?\"", 3.5],
		],
	},
	"C": {
		"map": ["#########", "#...#...#", "#.L.#.L.#", "#.......#", "#########"],
		"floor": Color(0.35, 0.28, 0.22), "wall": Color(0.55, 0.5, 0.42), "light": Color(1.0, 0.8, 0.6),
		"steps": [
			["body", "guard", Vector3(2, 0, 1.2), Vector3(2, 0, 3)],
			["cam", Vector3(6, 1.6, 3), Vector3(4.4, 1.5, 1.5), 0.0],
			["say", "ต๋อง: ถึงห้องสักที... ล็อกประตูแล้ว", 2.5],
			["sfx", "knock"], ["wait", 1.5],
			["say", "\"ข้าวมันไก่ครับ... ซื้อมาฝาก\"", 3.0],
			["cam", Vector3(5, 1.7, 1.5), Vector3(3, 1.7, 1.5), 1.5],
			["fov", 130.0],
			["cam", Vector3(2.35, 1.72, 1.5), Vector3(2, 1.72, 1.2), 0.0],
			["sfx", "sting"],
			["wait", 2.0],
		],
	},
}

# Character looks (Body presets). Coworker scenes pick one in the Inspector (Body > preset).
# model = assets/characters/<model>.glb (edit the .blend in Blender). The UI shows the same model live (face_view.gd).
const BODIES := {
	"manager": {"model": "manager"},
	"manager_long": {"model": "manager", "neck": 1.0},
	"sweeper": {"model": "sweeper"},
	"goblin": {"model": "goblin"},
	"tong": {"model": "tong"},
	"doctor": {"model": "doctor"},
	"guard": {"model": "guard"},
	"dummy": {"model": "dummy"},
}
