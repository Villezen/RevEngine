package backend.modding.handlers;

import backend.utils.SortUtil;

import backend.modding.modules.Module;
import backend.modding.modules.ScriptedModule;
import backend.modding.modules.PlayStateModule;
import backend.modding.modules.ScriptedPlayStateModule;

import backend.modding.events.ScriptEvent;
import backend.modding.events.ScriptEventDispatcher;

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
     * Loads every module found in the mod's directory.
     */
    public static function load():Void
    {
        clear();

        loadScripts(ScriptedModule);
        loadScripts(ScriptedPlayStateModule);

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
        var a:Null<Module> = get(module1);
        var b:Null<Module> = get(module2);
        
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
     * Calls `CREATE` on every loaded module.
     */
    public static function callCreate():Void
    {
        call(new ScriptEvent(CREATE, false));
    }
}