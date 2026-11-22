extends RefCounted

const ROOT="fighters/saizo"
const DEFAULT=106477
const CATALOG={
	DEFAULT:["Shigure"],
	106052:["Original Blue-Black"],
	106058:["Yellow & Green"],
	106064:["Blue & Tan"],
	106070:["Red & Brown"],
	105696:["Blond"],
	105492:["Purple Hair"],
	105486:["Black & Yellow"],
	106188:["Akamaru"],
	120234:["Winter Lion"],
	105178:["Brown Hair"],
	106182:["Pink Hair"],
	119308:["White Hair Alternate"],
}
const PORTRAIT_ORIGIN=Vector2(-18,-84)

static func valid_id(value:Variant)->int:
	return int(value) if value is int and CATALOG.has(value) else DEFAULT

static func root(id:int)->String:
	return "res://assets/characters/crossgate/%s/%d/"%[ROOT,id]

static func portrait(id:int)->Texture2D:
	return load(root(id)+"portrait.png")
