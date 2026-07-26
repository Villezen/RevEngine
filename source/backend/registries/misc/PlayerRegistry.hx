package backend.registries.misc;

typedef PlayerData =
{
    @:optional @:def(name) var name:String;
    @:optional @:def([name]) var characters:Array<String>;

    @:optional var freeplay:PlayerFreeplayData;
    @:optional var characterSelect:PlayerCharacterSelectData;
}

typedef PlayerFreeplayData =
{
    @:optional var skin:String;
    @:optional var bands:PlayerFreeplayBandData;
}

typedef PlayerFreeplayBandData =
{
    @:optional var text:Array<String>;
    @:optional var color:Array<String>;
    @:optional var speed:Array<Float>;
}

typedef PlayerCharacterSelectData =
{
    @:optional var unlocked:Bool;
    @:optional var position:Int;
}

@:folder("data/players")
@:build(backend.macros.RegistryMacro.build())
class PlayerRegistry
{
    public static var list:Map<String, PlayerData> = new Map();

    public static function playerForCharacter(character:String):Null<String>
    {
        if (character == null || character == "") return null;

        for (id in list.keys())
        {
            var data:PlayerData = list.get(id);

            if (data != null && data.characters != null && data.characters.indexOf(character) != -1)
                return id;
        }

        return null;
    }

    public static function owns(player:String, character:String):Bool
    {
        if (player == null || character == null) return false;

        var data:PlayerData = get(player);
        return data != null && data.characters != null && data.characters.indexOf(character) != -1;
    }
}
