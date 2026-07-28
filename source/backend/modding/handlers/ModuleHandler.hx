package backend.modding.handlers;

import backend.modding.modules.Module;
import backend.modding.modules.ScriptedModule;
import backend.modding.modules.PlayStateModule;
import backend.modding.modules.ScriptedPlayStateModule;

import backend.modding.events.ScriptEvent;
import backend.modding.events.ScriptEventDispatcher;

import backend.utils.ModuleUtil;

import game.PlayState;

/**
 * This class manages each module loaded in the state.
 */
class ModuleHandler
{
    /**
     * A map containing each currently loaded Module.
     */
    public static var list:Map<String, Module> = [];

    /**
     * An array only used when the list has to be sorted by priority.
     */
    static var sortList:Array<String> = [];

    /**
     * Whether modules are being loaded, so per-module priority changes don't get sorted every time a single change happens.
     */
    static var loading:Bool = false;

    /**
     * Loads every module found in the mod's directory.
     */
    public static function load():Void
    {
        clear();

        loading = true;

        loadScripts(ScriptedModule);
        loadScripts(ScriptedPlayStateModule);

        loading = false;
        reorder();
    }

    static function loadScripts(scriptClass:Dynamic):Void
    {
        var moduleClasses:Array<String> = scriptClass.listScriptClasses();

        for (moduleEntry in moduleClasses)
        {
            var module:Module = scriptClass.scriptInit(moduleEntry, moduleEntry);

            if (module != null)
            {
                list.set(module.id, module);
            }
        }
    }

    /**
     * Gets a module by ID.
     * Typically used by other modules so they can access eachother without any complications.
     * @param id The module's ID.
     * @return Module
     */
    public static function get(id:String):Module
    {
        return list.get(id) ?? null;
    }

    /**
     * Clears every module from the map and calls their respective `DESTROY` functions.
     */
    public static function clear():Void
    {
        ModuleUtil.clear(list, sortList);
    }

    /**
     * Calls a dedicated `ScriptEvent` to every loaded module, in priority order.
     * @param event The script event.
     */
    public static function call(event:ScriptEvent):Void
    {
        var inPlayState:Bool = (FlxG.state is PlayState);

        for (moduleID in sortList)
        {
            var module:Module = list.get(moduleID);

            if (module == null || !module.active) continue;

            if ((module is PlayStateModule))
            {
                if (!inPlayState) continue;

                cast(module, PlayStateModule).game = PlayState.instance;
            }

            ScriptEventDispatcher.call(module, event);
        }
    }

    /**
     * Sorts every module by priority. Skipped during a bulk load, which reorders once at the end.
     */
    public static function reorder():Void
    {
        if (loading) return;
        ModuleUtil.sort(list, sortList);
    }

    /**
     * Calls `CREATE` on every loaded module.
     */
    public static function callCreate():Void
    {
        call(new ScriptEvent(CREATE, false));
    }
}
