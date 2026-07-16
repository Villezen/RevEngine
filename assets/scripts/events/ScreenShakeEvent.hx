class ScreenShakeEvent extends SongEventModule
{
    function new()
    {
        super("ScreenShakeEvent", "Screen Shake");
    }

    override function execute(event):Bool
    {
        if (event.variables == null || event.variables.length < 2)
            return false;

        var game = PlayState.instance;

        if (game == null)
            return false;

        var shook:Bool = false;

        shook = shake(game.camGame, parse(event, 0), parse(event, 1)) || shook;

        if (event.variables.length > 2)
        {
            var duration:Float = parse(event, 2);
            var intensity:Float = parse(event, 3);

            for (camera in [game.camHUD, game.camStrums])
                shook = shake(camera, duration, intensity) || shook;
        }

        return shook;
    }

    function shake(camera:FlxCamera, duration:Float, intensity:Float):Bool
    {
        if (camera == null || duration <= 0 || intensity == 0)
            return false;

        camera.shake(intensity, duration);

        return true;
    }

    function parse(event, index:Int):Float
    {
        if (event.variables == null || event.variables.length <= index)
            return 0;

        var value:Float = Std.parseFloat(Std.string(event.variables[index]));

        if (Math.isNaN(value))
            return 0;

        return value;
    }
}
