package backend.utils;

import backend.modding.IScriptedClass.IModule;
import backend.modding.events.ScriptEvent;
import backend.modding.events.ScriptEventDispatcher;

/**
 * Shared logic for the module handlers.
 */
class ModuleUtil
{
    /**
     * Rebuilds the sorted ID list from the map, ordered by priority then alphabetically.
     */
    public static function sort<T:IModule>(list:Map<String, T>, sortList:Array<String>):Void
    {
        sortList.resize(0);

        for (id in list.keys())
            sortList.push(id);

        sortList.sort((a, b) -> sortByPriority(list, a, b));
    }

    /**
     * Compares two module ids by priority, falling back to alphabetical order.
     */
    public static function sortByPriority<T:IModule>(list:Map<String, T>, a:String, b:String):Int
    {
        var moduleA:Null<T> = list.get(a);
        var moduleB:Null<T> = list.get(b);

        if (moduleA == null || moduleB == null)
            return 0;

        if (moduleA.priority != moduleB.priority)
            return moduleA.priority - moduleB.priority;

        return SortUtil.alphabetically(a, b);
    }

    /**
     * Dispatches a destroy event to every module, then clears both the map and the sorted ID list.
     */
    public static function clear<T:IModule>(list:Map<String, T>, sortList:Array<String>):Void
    {
        if (list == null) return;

        var event = new ScriptEvent(DESTROY, false);

        for (module in list)
            ScriptEventDispatcher.call(module, event);

        list.clear();
        sortList.resize(0);
    }

    /**
     * Dispatches an event to every active module, in priority order.
     */
    public static function dispatchAll<T:IModule>(list:Map<String, T>, sortList:Array<String>, event:ScriptEvent):Void
    {
        for (id in sortList)
        {
            var module:Null<T> = list.get(id);

            if (module != null && module.active)
                ScriptEventDispatcher.call(module, event);
        }
    }
}
