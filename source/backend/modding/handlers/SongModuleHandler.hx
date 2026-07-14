package backend.modding.handlers;

import backend.utils.SortUtil;

import backend.modding.songs.SongModule;
import backend.modding.songs.ScriptedSongModule;

import backend.modding.events.ScriptEvent;
import backend.modding.events.ScriptEventDispatcher;

/**
 * This class manages each module loaded in the state.
 */
class SongModuleHandler
{
    /**
     * A map containing each currently loaded Module.
     */
    public static var list:Map<String, SongModule> = [];

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

        var scriptClass:Dynamic = ScriptedSongModule;
        var moduleClasses:Array<String> = scriptClass.listScriptClasses();

        for (moduleEntry in moduleClasses)
        {
            var module:SongModule = scriptClass.scriptInit(moduleEntry, moduleEntry);

            if (module != null)
            {   
                list.set(module.songId, module);
            }
        }
        reorder();
    }

    /**
     * Gets a module by ID.
     * Typically used by other modules so they can access eachother without any complications.
     * @param id The module's ID.
     * @return Module
     */
    public static function get(id:String):SongModule
    {
        return list.get(id) ?? null;
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
    public static function call(module:SongModule, event:ScriptEvent):Void
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
            var module:SongModule = list.get(moduleID);

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
        var a:Null<SongModule> = get(module1);
        var b:Null<SongModule> = get(module2);
        
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
     * Iterates through each of the currently loaded song modules to call a function for each.
     * @param func The function to call for each module.
     */
    public static function forEachModule(func:SongModule->Void):Void
    {
        for (module in list)
        {
            func(module);
        }
    }

    /**
     * Calls `CREATE` on every loaded song module.
     */
    public static inline function callCreate(song:String):Void
    {
        call(get(song), new ScriptEvent(CREATE, false));
    }
}