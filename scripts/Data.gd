extends RefCounted
static func equipment() -> Array:
	return [{"id":"pistol","name":"PISTOL","capacity":12,"reserve":144,"damage":35,"interval":.28,"reload":1.3,"noise":9.0}]
static func rooms() -> Array:
	return [{"name":"COVER TEST","tag":"OPEN SKY / ROOF / WALL REVEAL / CLIMB","brief":"Enter cover, knock, defeat the guard and reload.\nThen reach the green extraction ring.\nTest the roofed room on the right and CLIMB the low crates.","walls":[Rect2(-7,1,5,2),Rect2(2,-5,2,7),Rect2(-10,-7,4,2)],"shelter":Rect2(5,-10,9,10),"crates":[{"at":Vector3(-10,0,5),"size":Vector3(2.4,1.05,2.4)},{"at":Vector3(-.5,0,7),"size":Vector3(2.4,1.2,2.4)},{"at":Vector3(10,0,-5),"size":Vector3(2.2,1.1,2.2)}],"start":Vector3(-5,0,6),"exit":Vector3(10,0,-7),"chips":[],"routes":[[Vector2(-1,-3),Vector2(-1,-9),Vector2(10,-9),Vector2(10,-3)]],"goals":["cover","knock","reload","guard_down"]}]
