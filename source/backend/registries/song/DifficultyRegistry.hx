package backend.registries.song;

typedef DifficultyData =
{
    @:optional @:def(name) var name:String;
    @:optional @:def(true) var difficulty:Bool;
    @:optional @:def(false) var variation:Bool;
}

@:folder("data/difficulties")
@:build(backend.macros.RegistryMacro.build())
class DifficultyRegistry
{
    public static var list:Map<String, DifficultyData> = new Map();

    public static inline function isVariation(name:String):Bool
    {
        var data = get(name);
        return data != null && data.variation == true;
    }

    public static inline function suffix(name:String):String
    {
        return isVariation(name) ? '-$name' : '';
    }

    public static function characterVariations():Array<String>
    {
        var result:Array<String> = [];

        for (id in list.keys())
        {
            var data = list.get(id);
            
            if (data != null && data.variation == true && data.difficulty == false)
                result.push(id);
        }

        return result;
    }
}
