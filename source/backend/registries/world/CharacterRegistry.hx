package backend.registries.world;

typedef CharacterData =
{
    @:optional @:def("Character") var name:String;
    @:optional @:def("#FFFFFF") var color:String;
    @:optional @:def("SPARROW") var renderType:String;

    @:optional @:def(true) var applyStageMatrix:Null<Bool>;

    @:optional @:def(4.0) var singDuration:Null<Float>;

    @:optional @:def("OPPONENT") var placement:String;
    @:optional @:def([0, 0]) var position:Array<Int>;
    @:optional @:def([0, 0]) var camera:Array<Int>;

    @:optional @:def([1.0, 1.0]) var scale:Array<Float>;
    @:optional @:def([false, false]) var flip:Array<Bool>;
    @:optional @:def(true) var antialiasing:Null<Bool>;
    @:optional @:def(1.0) var alpha:Null<Float>;
    @:optional @:def(0) var angle:Null<Int>;

    @:optional @:def var animations:Array<CharacterAnimation>;
}

typedef CharacterAnimation =
{
    @:optional @:def("") var name:String;
    @:optional @:def("") var prefix:String;
    @:optional @:def(false) var looped:Null<Bool>;
    @:optional @:def(24) var fps:Null<Int>;
    @:optional @:def([0, 0]) var offsets:Array<Int>;
    @:optional var indices:Array<Int>;
    @:optional @:def([false, false]) var flip:Array<Bool>;
}

@:folder("data/characters")
@:build(backend.macros.RegistryMacro.build())
class CharacterRegistry
{
    public static var list:Map<String, CharacterData> = new Map();

    public static function healthColor(name:String):FlxColor
    {
        if (name == null || name == "")
            return FlxColor.WHITE;

        var data:CharacterData = get(name);

        if (data == null || data.color == null)
            return FlxColor.WHITE;

        var parsed:Null<FlxColor> = FlxColor.fromString(data.color);

        return (parsed != null) ? parsed : FlxColor.WHITE;
    }
}
