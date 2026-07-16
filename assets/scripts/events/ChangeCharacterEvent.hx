class ChangeCharacterEvent extends SongEventModule
{
    function new()
    {
        super("ChangeCharacterEvent", "Change Character");
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

        var name = Std.string(event.variables[1]);

        if (name == null || name == "")
            return false;

        var character = game.characters[target];

        if (character == null || character.name == name)
            return false;

        character.change(name);

        return true;
    }
}
