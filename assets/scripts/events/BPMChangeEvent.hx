class BPMChangeEvent extends SongEventModule
{
    function new()
    {
        super("BPMChangeEvent", "BPM Change");
    }

    override function execute(event):Bool
    {
        if (event.variables == null || event.variables.length == 0)
            return false;

        var newBpm:Float = Std.parseFloat(Std.string(event.variables[0]));

        if (Math.isNaN(newBpm) || newBpm <= 0)
            return false;

        Conductor.instance.changeBPM(newBpm);
        return true;
    }
}
