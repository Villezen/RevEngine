package backend.modding.events;

/**
 * An abstract class used to define each function that's gonna be able to get called to the Module.
 */
@:nullSafety
enum abstract ScriptEventType(String) from String to String
{
    /**
     * General
     */
    var CREATE = "CREATE";
    var STATE_CREATE = "STATE_CREATE";
    var POST_CREATE = "POST_CREATE";

    var UPDATE = "UPDATE";

    var DESTROY = "DESTROY";

    var CAMERA_MOVE = "CAMERA_MOVE";

    var MEASURE_HIT = "MEASURE_HIT";
    var BEAT_HIT = "BEAT_HIT";
    var STEP_HIT = "STEP_HIT";

    var SONG_EVENT = "SONG_EVENT";

    var NOTE_HIT = "NOTE_HIT";
    var PLAYER_HIT = "PLAYER_HIT";
    var OPPONENT_HIT = "OPPONENT_HIT";

    var PLAYER_MISS = "PLAYER_MISS";

    var NOTE_HOLD = "NOTE_HOLD";
    var PLAYER_HOLD = "PLAYER_HOLD";
    var OPPONENT_HOLD = "OPPONENT_HOLD";

    /**
     * Character
     */
    var DANCE = "DANCE";
    var HIT = "HIT";
    var MISS = "MISS";
    var HOLD = "HOLD";
}