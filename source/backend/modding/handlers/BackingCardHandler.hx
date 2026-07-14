package backend.modding.handlers;

import backend.modding.modules.BackingCard;
import backend.modding.modules.ScriptedBackingCard;

class BackingCardHandler
{
    public static var list:Map<String, BackingCard> = [];

    public static function load():Void
    {
        clear();

        var scriptClass:Dynamic = ScriptedBackingCard;
        var cardClasses:Array<String> = scriptClass.listScriptClasses();

        for (cardEntry in cardClasses)
        {
            var card:BackingCard = scriptClass.scriptInit(cardEntry);

            if (card != null)
                list.set(card.id, card);
        }
    }

    public static function get(id:String):BackingCard
    {
        return list.get(id) ?? null;
    }

    public static function has(id:String):Bool
    {
        return list.exists(id);
    }

    public static function clear():Void
    {
        if (list != null)
            list.clear();
    }
}
