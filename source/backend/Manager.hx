package backend;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import backend.modding.ModState;
import backend.modding.ModSubState; 
import backend.modding.PolymodManager;
import backend.modding.handlers.TransitionHandler;
import backend.transition.TransitionLoader;
import backend.transition.TransitionState;
import backend.registries.misc.ConfigRegistry;

class Manager
{
    public static var currentState(get, never):String;

    private static function get_currentState():String
    {
        if (FlxG.state == null) return "None";
        return Type.getClassName(Type.getClass(FlxG.state));
    }

    public static var currentScriptedState:String = null;
    public static var currentScriptedSubState:String = null;

    public static function switchState(state:Dynamic, ?transType:String):Void
    {
        if (!(state is String) && !(state is FlxState))
        {
            trace("Target state must be a [String] for scripted states or an FlxState!", "ERROR");
            return;
        }

        PolymodManager.reloadMods();
        ConfigRegistry.load();

        var sourceName:String = currentScriptedState != null ? currentScriptedState : Type.getClassName(Type.getClass(FlxG.state)).split(".").pop();
        var targetName:String = (state is String) ? cast state : Type.getClassName(Type.getClass(state)).split(".").pop();
        
        var originalSourceName:String = sourceName;
        var originalTargetName:String = targetName;

        if (ConfigRegistry.data.overrides.states != null)
        {
            for (overrideEntry in ConfigRegistry.data.overrides.states)
            {
                if (overrideEntry.target == sourceName) originalSourceName = overrideEntry.state;
                
                if (overrideEntry.state == targetName)
                {
                    if (Paths.exists('scripts/substates/${overrideEntry.target}.hx'))
                    {
                        openSubState(overrideEntry.target);
                        return;
                    }
                    targetName = overrideEntry.target;
                    state = targetName;
                }
            }
        }

        var nextTrans:String = transType;

        if (ConfigRegistry.data?.overrides?.transitions != null)
        {
            for (transEntry in ConfigRegistry.data.overrides.transitions)
            {
                if (transEntry.state == originalSourceName && transEntry.phase.transitionOut != "")
                    nextTrans = transEntry.phase.transitionOut;
                
                if (transEntry.state == originalTargetName && transEntry.phase.transitionIn != "")
                    nextTrans = transEntry.phase.transitionIn;
            }
        }

        currentScriptedState = null;

        if (state is String)
        {
            var name:String = cast state;
            if (Paths.exists('scripts/states/$name.hx'))
            {
                if (FlxG.state != null)
                    FlxG.state.closeSubState();

                currentScriptedState = name;
                TransitionHandler.load(); 
                TransitionLoader.switchState(ModState.load(name), nextTrans);
            }
            else
                trace('Scripted State NOT FOUND! ($name.hx)', "ERROR");
            return;
        }

        if (FlxG.state != null)
            FlxG.state.closeSubState();

        TransitionHandler.load();
        TransitionLoader.switchState(cast state, nextTrans);
    }

    public static function openSubState(substate:Dynamic):Void
    {
        if (FlxG.state == null) return;
        if (!(substate is String) && !(substate is FlxSubState)) return;

        PolymodManager.reloadMods();
        ConfigRegistry.load();

        var substateName:String = (substate is String) ? cast substate : Type.getClassName(Type.getClass(substate)).split(".").pop();
        
        if (ConfigRegistry.data?.overrides?.states != null)
        {
            for (overrideEntry in ConfigRegistry.data.overrides.states)
            {
                if (overrideEntry.state == substateName)
                {
                    if (Paths.exists('scripts/states/${overrideEntry.target}.hx'))
                    {
                        switchState(overrideEntry.target);
                        return;
                    }
                    substate = overrideEntry.target;
                    break;
                }
            }
        }

        currentScriptedSubState = null;

        if (substate is String)
        {
            var name:String = cast substate;
            if (Paths.exists('scripts/substates/$name.hx'))
            {
                currentScriptedSubState = name;
                FlxG.state.openSubState(ModSubState.load(name));
            }
            else
                trace('Scripted SubState NOT FOUND! ($name.hx)', "ERROR");
            return;
        }
        FlxG.state.openSubState(cast substate);
    }

    public static function resetState():Void
    {
        if (FlxG.state.subState is TransitionState) return;
        TransitionHandler.load();

        var targetName = ModState.tracker.get(FlxG.state);

        if (targetName != null)
            TransitionLoader.switchState(ModState.load(targetName), "fade");
        else if (currentScriptedState != null)
            switchState(currentScriptedState);
        else
            TransitionLoader.switchState(Type.createInstance(Type.getClass(FlxG.state), []), "fade");
    }
}