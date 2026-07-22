package backend.registries.world;

import haxe.io.Path;
import json2object.JsonParser;

import backend.utils.RegistryUtil;

typedef CharacterData =
{
    @:optional var name:String;
    @:optional var color:String;
    @:optional var renderType:String;
    
    @:optional var applyStageMatrix:Null<Bool>;

    @:optional var singDuration:Null<Float>;
    
    @:optional var placement:String;
    @:optional var position:Array<Int>;
    @:optional var camera:Array<Int>;
    
    @:optional var scale:Array<Float>;
    @:optional var flip:Array<Bool>;
    @:optional var antialiasing:Null<Bool>;
    @:optional var alpha:Null<Float>;
    @:optional var angle:Null<Int>;

    @:optional var animations:Array<CharacterAnimation>;
}

typedef CharacterAnimation =
{
    @:optional var name:String;
    @:optional var prefix:String;
    @:optional var looped:Null<Bool>;
    @:optional var fps:Null<Int>;
    @:optional var offsets:Array<Int>;
    @:optional var indices:Array<Int>;
    @:optional var flip:Array<Bool>;
}

class CharacterRegistry
{
    public static var list:Map<String, CharacterData> = new Map();
    private static var parser:JsonParser<CharacterData> = new JsonParser<CharacterData>();

    public static function init():Void
    {
        #if sys
        for (file in Paths.readDirectory('data/characters'))
        {
            if (Path.extension(file) == "json")
                reload(Path.withoutExtension(file));
        }
        #end
    }

    public static inline function get(name:String):CharacterData
    {
        if (!list.exists(name))
            reload(name);

        return list.get(name);
    }

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

    public static function reload(name:String):Void
    {
        var rawData:String = "{}";

        #if sys
        if (Paths.exists('data/characters/$name.json'))
            rawData = Paths.data('$name.json', 'data/characters');
        #end

        parser.fromJson(rawData, 'data/characters/$name.json');
        RegistryUtil.reportErrors('data/characters/$name.json', parser.errors);

        list.set(name, validateData(parser.value));
    }

    private static function validateData(data:CharacterData):CharacterData
    {
        if (data == null) data = {};

        if (data.name == null) data.name = "Character";
        if (data.color == null) data.color = "#FFFFFF";

        if (data.renderType == null) data.renderType = "SPARROW";

        if (data.applyStageMatrix == null) data.applyStageMatrix = true;

        if (data.singDuration == null) data.singDuration = 4.0;

        if (data.placement == null) data.placement = "OPPONENT";

        if (data.position == null || data.position.length < 2) data.position = [0, 0];
        if (data.camera == null || data.camera.length < 2) data.camera = [0, 0];
        if (data.scale == null || data.scale.length < 2) data.scale = [1.0, 1.0];

        if (data.flip == null || data.flip.length < 2) data.flip = [false, false];
        if (data.antialiasing == null) data.antialiasing = true;
        if (data.alpha == null) data.alpha = 1.0;
        if (data.angle == null) data.angle = 0;

        if (data.animations == null) data.animations = [];

        var i:Int = data.animations.length;
        while (--i >= 0)
            if (data.animations[i] == null) data.animations.splice(i, 1);

        for (anim in data.animations)
        {
            if (anim.name == null) anim.name = "";
            if (anim.prefix == null) anim.prefix = "";
            if (anim.looped == null) anim.looped = false;
            if (anim.fps == null) anim.fps = 24;
            if (anim.offsets == null || anim.offsets.length < 2) anim.offsets = [0, 0];
            if (anim.flip == null || anim.flip.length < 2) anim.flip = [false, false];
        }

        return data;
    }

    public static function reloadAll():Void
    {
        list.clear();
        init();
    }
}