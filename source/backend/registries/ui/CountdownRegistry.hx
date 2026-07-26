package backend.registries.ui;

typedef CountdownData =
{
    @:optional @:def var increments:CountdownIncrements;
}

typedef CountdownIncrements =
{
    @:optional @:def var THREE:CountdownIncrementData;
    @:optional @:def var TWO:CountdownIncrementData;
    @:optional @:def var ONE:CountdownIncrementData;
    @:optional @:def var GO:CountdownIncrementData;
}

typedef CountdownIncrementData =
{
    @:optional @:def(true) var antialiasing:Null<Bool>;
    @:optional @:def(1.0) var alpha:Null<Float>;
    @:optional @:def(0) var angle:Null<Int>;
    @:optional @:def([1.0, 1.0]) var scale:Array<Float>;
    @:optional @:def([0, 0]) var offsets:Array<Int>;

    @:optional @:def(null) var animation:CountdownIncrementAnimationData;
}

typedef CountdownIncrementAnimationData =
{
    var prefix:String;
    @:optional @:def(24) var fps:Null<Int>;
    @:optional @:def(false) var looped:Null<Bool>;
}

@:folder("data/countdown")
@:build(backend.macros.RegistryMacro.build())
class CountdownRegistry
{
    public static var list:Map<String, CountdownData> = new Map();
}
