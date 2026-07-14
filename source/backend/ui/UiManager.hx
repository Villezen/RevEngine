package backend.ui;

import flixel.util.FlxSignal;

class UiManager
{
    public static var rootElements:Array<IUiEntry> = [];
    public static var activeUi:IUiEntry = null;
    private static var initialized:Bool = false;

    public static function register(ui:IUiEntry)
    {
        if (!initialized)
        {
            FlxG.signals.preUpdate.add(onPreUpdate);
            FlxG.signals.preStateSwitch.add(clear); 
            
            initialized = true;
        }
        
        if (!rootElements.contains(ui))
            rootElements.push(ui);
    }

    public static function unregister(ui:IUiEntry)
    {
        rootElements.remove(ui);
    }

    public static function bringToFront(ui:IUiEntry)
    {
        if (rootElements.remove(ui))
            rootElements.push(ui);
    }

    public static function clear()
    {
        rootElements = [];
        activeUi = null;
    }

    private static function onPreUpdate()
    {
        activeUi = null;

        var i = rootElements.length - 1;
        while (i >= 0)
        {
            var ui = rootElements[i];
            
            if (ui == null)
            {
                rootElements.splice(i, 1);
                i--;
                
                continue;
            }

            if (ui.priority)
            {
                var hovered = ui.getHoveredElement();
                if (hovered != null)
                {
                    activeUi = hovered;

                    if (FlxG.mouse.justPressed)
                        bringToFront(ui);

                    return;
                }
            }
            i--;
        }

        i = rootElements.length - 1;
        while (i >= 0)
        {
            var ui = rootElements[i];
            
            if (!ui.priority)
            {
                var hovered = ui.getHoveredElement();
                if (hovered != null)
                {
                    activeUi = hovered;

                    if (FlxG.mouse.justPressed)
                        bringToFront(ui);

                    return;
                }
            }
            i--;
        }
    }

    public static function hasFocus(ui:IUiEntry):Bool
    {
        return activeUi == ui;
    }
}