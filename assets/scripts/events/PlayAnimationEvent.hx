class PlayAnimationEvent extends SongEventModule
{
    function new()
    {
        super("PlayAnimationEvent", "Play Animation");
    }

    override function execute(event):Bool
    {
        if (event.variables == null || event.variables.length < 2)
            return false;

        var game = PlayState.instance;

        if (game == null || game.characters == null)
            return false;

        var target = Std.parseInt(Std.string(event.variables[0]));

        if (target == null)
            return false;

        var anim = Std.string(event.variables[1]);

        if (anim == null || anim == "")
            return false;

        var character = game.characters[target];

        if (character == null || !character.hasAnim(anim))
            return false;

        character.playAnim(anim, {force: true});
        character.stunned = true;

        return true;
    }
}
