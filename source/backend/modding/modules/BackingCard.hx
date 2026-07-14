package backend.modding.modules;

import flixel.group.FlxSpriteGroup;

class BackingCard
{
    public var id(default, null):String;
    public var active:Bool = true;

    public function new(id:String)
    {
        this.id = id;
    }

    public static function createLayer():FlxSpriteGroup
        return new FlxSpriteGroup();

    public function onCreate(freeplay:Dynamic):Void {}
    public function onCardCreate(freeplay:Dynamic):Void {}
    public function onPostCreate(freeplay:Dynamic):Void {}

    public function onIntroDone(freeplay:Dynamic):Void {}
    public function onExit(freeplay:Dynamic):Void {}

    public function onDifficultyChange(freeplay:Dynamic, difficulty:String):Void {}
    public function onSelectionChange(freeplay:Dynamic, curSelected:Int):Void {}
    public function onSongFavorite(freeplay:Dynamic, ?song:Dynamic):Void {}

    public function onBeatHit(freeplay:Dynamic, beat:Int):Void {}

    public function onSelect(freeplay:Dynamic, ?song:Dynamic):Void {}

    public function onUpdate(freeplay:Dynamic, elapsed:Float):Void {}
    public function onDestroy(freeplay:Dynamic):Void {}

    public function toString():String
        return 'BackingCard (id: $id)';
}
