package backend.modding.events;

import backend.modding.IScriptedClass;
import backend.modding.modules.Module;

/**
 * Handles all the event dispatching called from other states.
 */
class ScriptEventDispatcher
{
    /**
     * Calls an event and dispatches the function specified to the module.
     * @param target The module.
     * @param event The specified script event.
     */
    public static function call(target:IScriptedClass, event:ScriptEvent):Void
    {
        if (target == null || event == null) return;

        target.onScriptEvent(event);

        if (!event.shouldPropagate)
            return;

        switch(event.type)
        {
            case CREATE:
                target.onCreate(event);
                return;

            case STATE_CREATE:
            {
                if (Std.isOfType(target, Module))
                {
                    var t:Module = cast(target, Module);
                    t.onStateCreate(event);
                }
                return;
            }

            case POST_CREATE:
                target.onPostCreate(event);
                return;

            case UPDATE:
                target.onUpdate(cast event);
                return;

            case DESTROY:
                target.onDestroy(event);
                return;

            case MEASURE_HIT:
                target.onMeasureHit(cast event);
                return;

            case BEAT_HIT:
                target.onBeatHit(cast event);
                return;

            case STEP_HIT:
                target.onStepHit(cast event);
                return;

            case SONG_EVENT:
                target.onSongEvent(cast event);
                return;

            case NOTE_HIT:
                target.onNoteHit(cast event);
                return;
            
            case PLAYER_HIT:
                target.onPlayerHit(cast event);
                return;

            case PLAYER_MISS:
                target.onPlayerMiss(cast event);
                return;

            case OPPONENT_HIT:
                target.onOpponentHit(cast event);
                return;

            case NOTE_HOLD:
                target.onNoteHold(cast event);
                return;
            
            case PLAYER_HOLD:
                target.onPlayerHold(cast event);
                return;

            case OPPONENT_HOLD:
                target.onOpponentHold(cast event);
                return;

            case CAMERA_MOVE:
                target.onCameraMove(cast event);
                return;

            default:
        }

        if (Std.isOfType(target, IScriptedCharacterClass))
        {
            var c:IScriptedCharacterClass = cast(target, IScriptedCharacterClass);

            switch(event.type)
            {
                case DANCE:
                    c.onDance(event);
                case HIT:
                    c.onHit(cast event);
                case MISS:
                    c.onMiss(cast event);
                case HOLD:
                    c.onHold(cast event);

                default:
            }
        }
    }
}