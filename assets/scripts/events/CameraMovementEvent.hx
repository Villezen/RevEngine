class CameraMovementEvent extends SongEventModule
{
    function new()
    {
        super("CameraMovementEvent", "Camera Movement");
    }

    override function execute(event):Bool
    {
        if (event.variables == null || event.variables.length == 0)
            return false;

        var game = PlayState.instance;

        if (game == null || game.pointer == null)
            return false;

        var value = Std.parseInt(Std.string(event.variables[0]));

        switch (value)
        {
            case 0:
                game.pointer.curTarget = game.dad;
            case 1:
                game.pointer.curTarget = game.boyfriend;
            default:
                return false;
        }

        return true;
    }
}
