class StopAnimationEvent extends SongEventModule
{
    function new()
    {
        super("StopAnimationEvent", "Stop Animation");
    }

    override function execute(event):Bool
    {
        if (event.variables == null || event.variables.length < 1)
            return false;

        var game = PlayState.instance;

        if (game == null || game.characters == null)
            return false;

        var target = Std.parseInt(Std.string(event.variables[0]));

        if (target == null)
            return false;

        var character = game.characters[target];

        if (character == null)
            return false;

        character.stunned = false;
        character.dance();

        return true;
    }
}
