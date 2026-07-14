package backend.ui;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxBitmapText;
import flixel.group.FlxSpriteGroup;

typedef LabelParams =
{
    var position:Array<Int>;
    var size:Array<Float>;
    var type:String;
    var alpha:Float;
    var color:Int;
    var text:String;
}

class Label extends FlxSpriteGroup implements IUiEntry
{
    public var priority(get, set):Bool;
    private var _priority:Bool = false;

    private function get_priority():Bool
    { 
        return _priority;
    }

    private function set_priority(value:Bool):Bool
    {
        _priority = value;
        return value;
    }

    public var clickable(default, set):Bool = false;
    private function set_clickable(value:Bool):Bool
    {
        clickable = value;
        return value;
    }

    private var params:LabelParams;

    public function new(params:LabelParams)
    {
        var startX:Float = (params != null && params.position != null) ? params.position[0] : 0;
        var startY:Float = (params != null && params.position != null) ? params.position[1] : 0;
        
        super(startX, startY);

        var path:String = switch(params.type)
        {
            case "SOLID": "jetbrains/solid";
            default: "jetbrains";
        }
        
        this.params = params;
        UiManager.register(this);

        var rawText:String = (params != null && params.text != null) ? params.text : "";
        var parsedText:String = StringTools.replace(rawText, "\\n", "\n");
        
        var lines:Array<String> = parsedText.split("\n");
        var font = Paths.getAngelFont(path);

        var scaleX:Float = params.size[0];
        var scaleY:Float = params.size[1];

        var tempText = new FlxBitmapText(0, 0, "A", font);
        tempText.scale.set(scaleX, scaleY);
        tempText.updateHitbox();
        var baseHeight:Float = tempText.height;
        tempText.destroy();

        var currentY:Float = 0;

        for (i in 0...lines.length)
        {
            var lineText = lines[i];
            
            var bmpText = new FlxBitmapText(0, currentY, lineText, font);
            
            bmpText.color = params.color;
            bmpText.alpha = params.alpha;
            bmpText.scale.set(scaleX, scaleY);
            bmpText.updateHitbox();   
            add(bmpText);
            
            currentY += baseHeight; 
        }
    }

    public function getHoveredElement():IUiEntry
    {
        return null;
    }
}