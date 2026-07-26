package backend.registries.song;

typedef EventObjectData =
{
    @:optional @:def(name) var name:String;
    @:optional @:def([]) var alias:Array<String>;
    @:optional @:def("") var description:String;

    @:optional @:def var variables:Array<EventObjectVariables>;
}

typedef EventObjectVariables =
{
    @:optional @:def("Value") var name:String;
    @:optional @:def("Int") var type:String;
    @:optional @:def("") var defaultValue:String;
}

@:folder("data/events")
@:build(backend.macros.RegistryMacro.build())
class EventObjectRegistry
{
    public static var list:Map<String, EventObjectData> = new Map();

    public static function findByName(name:String):Null<EventObjectData>
    {
        if (name == null)
            return null;

        for (data in list)
        {
            if (data == null) continue;

            if (data.name == name || (data.alias != null && data.alias.contains(name)))
                return data;
        }

        return null;
    }
}
