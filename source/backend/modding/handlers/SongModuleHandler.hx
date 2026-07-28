package backend.modding.handlers;

import backend.modding.songs.SongModule;
import backend.modding.songs.ScriptedSongModule;

import backend.modding.events.ScriptEvent;
import backend.modding.events.ScriptEventDispatcher;

import backend.utils.ModuleUtil;

/**
 * This class manages each song module loaded in the state.
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

        loading = false;
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
        ModuleUtil.clear(list, sortList);
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
        ModuleUtil.dispatchAll(list, sortList, event);
    }

    /**
     * Sorts every module by priority. Skipped during loading, which reorders once at the end.
     */
    public static function reorder():Void
    {
        if (loading) return;
        ModuleUtil.sort(list, sortList);
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
