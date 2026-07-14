/**
 * Those scripts only run on `PlayState`.
 * For scripts in the root assets unfortunately you have to recompile the game in order to get it working. Adding new scripts without having to recompile only works for mods.
 */
class ExampleScript extends Module
{
    function new()
    {
        super("TestModule");
    }

    function onCreate()
    {
        
    }
}