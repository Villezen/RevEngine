class ZoomCamEvent extends SongEventModule
{
    var tween:FlxTween = null;

    function new()
    {
        super("ZoomCamEvent", "Zoom Cam");
    }

    override function execute(event):Bool
    {
        if (event.variables == null || event.variables.length < 1)
            return false;

        var game = PlayState.instance;

        if (game == null)
            return false;

        var zoom:Float = Std.parseFloat(Std.string(event.variables[0]));

        if (Math.isNaN(zoom))
            return false;

        var steps:Float = 4.0;

        if (event.variables.length > 1)
        {
            var parsed:Float = Std.parseFloat(Std.string(event.variables[1]));

            if (!Math.isNaN(parsed))
                steps = parsed;
        }

        var ease = resolveEase(event.variables.length > 2 ? Std.string(event.variables[2]) : "linear");

        var duration:Float = (Conductor.instance.stepLengthMs * steps) / 1000.0;

        cancel();

        if (duration <= 0)
        {
            game.currentCameraZoom = zoom;
            return true;
        }

        tween = FlxTween.num(game.currentCameraZoom, zoom, duration, {ease: ease}, (value:Float) -> game.currentCameraZoom = value);

        return true;
    }

    function resolveEase(name:String)
    {
        if (name == null || StringTools.trim(name) == "")
            return FlxEase.linear;

        var ease = Reflect.field(FlxEase, StringTools.trim(name));

        if (ease == null || !Reflect.isFunction(ease))
        {
            trace('Zoom Cam: unknown ease "$name", falling back to linear.', "WARNING");
            return FlxEase.linear;
        }

        return ease;
    }

    function cancel():Void
    {
        if (tween != null)
        {
            tween.cancel();
            tween = null;
        }
    }

    override function onDestroy(event:ScriptEvent):Void
    {
        cancel();
    }
}
