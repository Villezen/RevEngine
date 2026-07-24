class ChangeKeyAmountEvent extends SongEventModule
{
    function new()
    {
        super("ChangeKeyAmountEvent", "Change Key Amount");
    }

    override function execute(event):Bool
    {
        if (event.variables == null || event.variables.length < 2)
            return false;

        var game = PlayState.instance;

        if (game == null || game.strumlines == null)
            return false;

        var target = Std.parseInt(Std.string(event.variables[0]));
        var keys = Std.parseInt(Std.string(event.variables[1]));

        if (target == null || keys == null)
            return false;

        var strumline = game.strumlines.get(target);

        if (strumline == null || strumline.keyCount == keys)
            return false;

        strumline.keyCount = keys;

        return true;
    }
}
