package backend.registries.world;

typedef StageData =
{
    @:optional @:def var camera:CameraData;
    @:optional @:def var characters:CharactersData;
    @:optional @:def var sprites:Array<SpriteData>;
}

typedef CameraData =
{
    @:optional @:def(1.0) var zoom:Null<Float>;
    @:optional @:def(1.0) var speed:Null<Float>;
    @:optional @:def([0, 0]) var baseline:Array<Int>;
    @:optional @:def([0, 0]) var boyfriend:Array<Int>;
    @:optional @:def([0, 0]) var dad:Array<Int>;
    @:optional @:def([0, 0]) var girlfriend:Array<Int>;
}

typedef CharactersData =
{
    @:optional @:def([0, 0]) var boyfriend:Array<Int>;
    @:optional @:def([0, 0]) var dad:Array<Int>;
    @:optional @:def([0, 0]) var girlfriend:Array<Int>;
    @:optional @:def([true, true, true]) var visibility:Array<Bool>;
}

typedef SpriteData =
{
    @:optional @:def("Sprite") var name:String;
    @:optional @:def("") var path:String;
    @:optional @:def([0, 0]) var position:Array<Int>;
    @:optional @:def([1.0, 1.0]) var scale:Array<Float>;
    @:optional @:def([1.0, 1.0]) var scroll:Array<Float>;
    @:optional @:def([false, false]) var flip:Array<Bool>;
    @:optional @:def(1.0) var alpha:Null<Float>;
    @:optional @:def(0) var angle:Null<Int>;
    @:optional @:def("#FFFFFF") var color:String;
    @:optional @:def(true) var antialiasing:Null<Bool>;
    @:optional @:def var animations:AnimationData;
}

typedef AnimationData =
{
    @:optional @:def("") var current:String;
    @:optional @:def var data:Array<AnimationEntry>;
}

typedef AnimationEntry =
{
    @:optional @:def("") var name:String;
    @:optional @:def("") var prefix:String;
    @:optional var indices:Array<Int>;
    @:optional @:def(30) var fps:Null<Int>;
    @:optional @:def(true) var looping:Null<Bool>;
    @:optional @:def([false, false]) var flip:Array<Bool>;
}

@:folder("data/stages")
@:build(backend.macros.RegistryMacro.build())
class StageRegistry
{
    public static var list:Map<String, StageData> = new Map();
}
