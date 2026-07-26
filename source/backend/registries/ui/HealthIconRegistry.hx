package backend.registries.ui;

typedef IconData =
{
    @:optional @:def([1.0, 1.0]) var scale:Array<Float>;
    @:optional @:def([0, 0]) var position:Array<Int>;
    @:optional @:def(true) var antialiasing:Null<Bool>;
    @:optional @:def([
        {value: 25.0, name: "losing", prefix: [1], offsets: [0, 0], looped: false, fps: 24},
        {name: "neutral", prefix: [0], offsets: [0, 0], looped: false, fps: 24}
    ]) var states:Array<IconState>;
}

typedef IconState =
{
    @:optional @:def(0.0) var value:Null<Float>;
    @:optional @:def("neutral") var name:String;
    @:optional @:def([0]) var prefix:Array<Int>;
    @:optional @:def([0, 0]) var offsets:Array<Int>;
    @:optional @:def(false) var looped:Null<Bool>;
    @:optional @:def(24) var fps:Null<Int>;
}

@:folder("data/icons")
@:build(backend.macros.RegistryMacro.build())
class HealthIconRegistry
{
    public static var list:Map<String, IconData> = new Map();
}
