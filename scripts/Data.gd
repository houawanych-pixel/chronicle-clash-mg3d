extends RefCounted
static func equipment() -> Array:
	return [
		{"id":"pistol","name":"PISTOL","capacity":12,"reserve":144,"damage":35,"interval":.28,"reload":1.3,"noise":9.0},
		{"id":"rifle","name":"RIFLE","capacity":30,"reserve":360,"damage":26,"interval":.12,"reload":1.9,"noise":16.0},
		{"id":"sniper","name":"SNIPER","capacity":5,"reserve":40,"damage":110,"interval":1.1,"reload":2.4,"noise":20.0},
		{"id":"rocket","name":"ROCKET","capacity":1,"reserve":12,"damage":150,"interval":1.0,"reload":2.5,"noise":24.0},
		{"id":"smg","name":"SMG","capacity":25,"reserve":250,"damage":20,"interval":.09,"reload":1.6,"noise":13.0},
		{"id":"dagger","name":"DAGGER","capacity":1,"reserve":0,"damage":45,"interval":.5,"reload":0.0,"noise":2.0},
		{"id":"sword","name":"SWORD","capacity":1,"reserve":0,"damage":55,"interval":.7,"reload":0.0,"noise":5.0}]

static func rooms() -> Array:
	return [{"name":"COVER TEST","tag":"COVER / CRAWL / VENT POV / DRONES","brief":"Enter cover, knock, defeat the guard and reload.\nThen reach the green extraction ring.\nTest CLIMB, the CRAWL vent, and both drones.","walls":[Rect2(-7,1,5,2),Rect2(2,-5,2,7),Rect2(-10,-7,4,2)],"shelter":Rect2(5,-10,9,10),"crates":[{"at":Vector3(-10,0,5),"size":Vector3(2.4,1.05,2.4)},{"at":Vector3(-.5,0,7),"size":Vector3(2.4,1.2,2.4)},{"at":Vector3(10,0,-5),"size":Vector3(2.2,1.1,2.2)}],"start":Vector3(-5,0,6),"exit":Vector3(10,0,-7),"chips":[],"routes":[[Vector2(-1,-3),Vector2(-1,-9),Vector2(10,-9),Vector2(10,-3)]],"goals":["cover","knock","reload","guard_down"]}]
