package backend.modding.handlers;

import backend.utils.SortUtil;

import backend.modding.songs.SongEventModule;
import backend.modding.songs.ScriptedSongEventModule;

import backend.modding.events.ScriptEvent;
import backend.modding.events.ScriptEventDispatcher;

import backend.registries.song.EventObjectRegistry;

/**
 * This class manages each song event module loaded in the state.
 */
class SongEventModuleHandler
{
    /**
     * A map containing each currently loaded Module, keyed by the event name it belongs to.
     */
    public static var list:Map<String, SongEventModule> = [];

    /**
     * An array only used when the list has to be sorted by priority.
     */
    static var sortList:Array<String> = [];

    /**
     * Loads every module found in the mod's directory.
     */
    public static function load():Void
    {
        clear();

        var scriptClass:Dynamic = ScriptedSongEventModule;
        var moduleClasses:Array<String> = scriptClass.listScriptClasses();

        for (moduleEntry in moduleClasses)
        {
            var module:SongEventModule = scriptClass.scriptInit(moduleEntry, moduleEntry);

            if (module != null)
            {
                list.set(module.eventId, module);
            }
        }
        reorder();
    }

    /**
     * Gets a module by the event name it belongs to.
     * @param id The event's name.
     * @return SongEventModule
     */
    public static function get(id:String):SongEventModule
    {
        return list.get(id) ?? null;
    }

    /**
     * Resolves an event name from a chart to its module, also checking the aliases.
     * @param name The event name used in the chart.
     * @return The matching module, or `null` if none was found.
     */
    public static function resolve(name:String):SongEventModule
    {
        if (list.exists(name))
            return list.get(name);

        var data = EventObjectRegistry.findByName(name);

        if (data != null && list.exists(data.name))
            return list.get(data.name);

        return null;
    }

    /**
     * Executes the module attached to the given song event.
     * @param event The script event holding the executed event's name, time and variables.
     * @return Whether the event executed successfully.
     */
    public static function execute(event:SongEventScriptEvent):Bool
    {
        if (event == null)
            return false;

        var module:SongEventModule = resolve(event.name);

        if (module == null || !module.active)
            return false;

        return module.execute(event);
    }

    /**
     * Clears every module from the map and calls their respective `DESTROY` functions.
     */
    public static function clear():Void
	{
        if (list != null)
        {
            var event = new ScriptEvent(DESTROY, false);

            for (key => value in list)
            {
                ScriptEventDispatcher.call(value, event);
            }

            list.clear();
            list = [];
        }
    }

    /**
     * Calls a dedicated `ScriptEvent` to the Module.
     * @param event The script event.
     */
    public static function call(module:SongEventModule, event:ScriptEvent):Void
    {
        if (module == null || !module.active) return;
        ScriptEventDispatcher.call(module, event);
    }

    /**
     * Calls a dedicated `ScriptEvent` to every loaded module.
     * @param event The script event.
     */
    public static function callAll(event:ScriptEvent):Void
    {
        for (moduleID in sortList)
        {
            var module:SongEventModule = list.get(moduleID);

            if (module != null && module.active)
            {
                ScriptEventDispatcher.call(module, event);
            }
        }
    }

    /**
     * Sorts every module so they're positioned by priority. If two modules have the same priority value, they get sorted alphabetically.
     */
    public static function reorder():Void
    {
        sortList = list.keys().array().copy();
        sortList.sort(sortByPriority);
    }

    /**
     * Sorts two modules by priority.
     * @param module1 The first module to be sorted.
     * @param module2 The second module to be sorted.
     * @return Which module should advance.
     */
    static function sortByPriority(module1:String, module2:String):Int
	{
        var a:Null<SongEventModule> = get(module1);
        var b:Null<SongEventModule> = get(module2);

        if (a == null || b == null)
            return 0;

        if (a.priority != b.priority)
		{
			return a.priority - b.priority;
		}
		else
		{
			return SortUtil.alphabetically(module1, module2);
		}
	}

    /**
     * Iterates through each of the currently loaded song event modules to call a function for each.
     * @param func The function to call for each module.
     */
    public static function forEachModule(func:SongEventModule->Void):Void
    {
        for (module in list)
        {
            func(module);
        }
    }

    /**
     * Calls `CREATE` on every loaded song event module.
     */
    public static inline function callCreate():Void
    {
        callAll(new ScriptEvent(CREATE, false));
    }
}
