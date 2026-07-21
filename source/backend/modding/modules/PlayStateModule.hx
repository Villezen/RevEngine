package backend.modding.modules;

import game.PlayState;

/**
 * A `Module` that only runs inside `PlayState`.
 */
class PlayStateModule extends Module
{
    public var game:PlayState = null;

    public function new(id:String, ?priority:Int = 1000)
    {
        super(id, priority);
    }
}
