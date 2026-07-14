package backend.frontends;

class FrontEndHandler
{
    @:access(flixel.FlxG)
    public static function init()
    {
        FlxG.bitmap = new RevBitmapFrontEnd();
    }
}