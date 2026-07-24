class ChangeNoteskinEvent extends SongEventModule
{
    function new()
    {
        super("ChangeNoteskinEvent", "Change Noteskin");
    }

    override function execute(event):Bool
    {
        if (event.variables == null || event.variables.length < 2)
            return false;

        var game = PlayState.instance;

        if (game == null || game.strumlines == null)
            return false;

        var target = Std.parseInt(Std.string(event.variables[0]));
        var skin = Std.string(event.variables[1]);

        if (target == null || skin == null || skin == "")
            return false;

        var strumline = game.strumlines.get(target);

        if (strumline == null || strumline.skin == skin)
            return false;

        strumline.skin = skin;

        return true;
    }
}
