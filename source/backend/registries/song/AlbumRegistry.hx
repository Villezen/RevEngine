package backend.registries.song;

typedef AlbumData =
{
    @:optional @:def(name) var name:String;
    @:optional @:def(["Unknown"]) var artists:Array<String>;
    @:optional @:def var sprites:AlbumSpritesData;
}

typedef AlbumSpritesData =
{
    @:optional @:def var art:AlbumObjectData;
    @:optional @:def var text:AlbumObjectData;
}

typedef AlbumObjectData =
{
    @:optional @:def("") var path:String;
    @:optional @:def(true) var visible:Bool;
    @:optional @:def([0, 0]) var position:Array<Float>;
    @:optional @:def([1, 1]) var scale:Array<Float>;
    @:optional @:def(1) var alpha:Float;
    @:optional @:def(0) var angle:Int;

    @:optional @:def var animations:Array<AlbumAnimationData>;
}

typedef AlbumAnimationData =
{
    @:optional @:def("idle") var name:String;
    @:optional @:def("") var prefix:String;
    @:optional @:def([]) var indices:Array<Int>;
    @:optional @:def([0, 0]) var offsets:Array<Int>;
    @:optional @:def(false) var looped:Null<Bool>;
    @:optional @:def(24) var fps:Null<Int>;
}

@:folder("data/albums")
@:build(backend.macros.RegistryMacro.build())
class AlbumRegistry
{
    public static var list:Map<String, AlbumData> = new Map();
}
