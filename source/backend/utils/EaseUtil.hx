package backend.utils;

@:build(backend.macros.EaseMacro.build())
class EaseUtil
{
    public static function get(name:String, ?fallback:Float->Float):Float->Float
    {
        if (name != null && map.exists(name))
            return map.get(name);

        return fallback != null ? fallback : flixel.tweens.FlxEase.linear;
    }
}
