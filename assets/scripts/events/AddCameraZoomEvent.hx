class AddCameraZoomEvent extends SongEventModule
{
    function new()
    {
        super("AddCameraZoomEvent", "Add Camera Zoom");
    }

    override function execute(event):Bool
    {
        var game = PlayState.instance;

        if (game == null)
            return false;

        var gameZoom:Float = parse(event, 0, 0.015);
        var hudZoom:Float = parse(event, 1, 0.03);

        game.cameraBop(gameZoom, hudZoom);

        return true;
    }

    function parse(event, index:Int, fallback:Float):Float
    {
        if (event.variables == null || event.variables.length <= index)
            return fallback;

        var value:Float = Std.parseFloat(Std.string(event.variables[index]));

        if (Math.isNaN(value))
            return fallback;

        return value;
    }
}
