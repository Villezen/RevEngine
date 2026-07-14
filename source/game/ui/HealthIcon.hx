package game.ui;

import flixel.ui.FlxBar;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;

import game.world.Character;

import backend.registries.ui.HealthIconRegistry;
import backend.registries.ui.HealthIconRegistry.IconData;

enum IconType
{
    LEFT;
    RIGHT;
    CENTER;
}

typedef HealthIconParams =
{
    var character:Character;
    var type:IconType;
    var bar:FlxBar;
}

class HealthIcon extends FunkinSprite
{
    public var character(default, set):Character;

    function set_character(?value:Character):Character
    {
        if (value == null)
        {
            changeIcon("dummy");
            return character = null;
        }

        if (value != character)
        {
            changeIcon(value.name);
            return character = value;
        }

        return character;
    }

    public var state(default, set):String = "neutral";

    function set_state(value:String):String
    {
        if (state != value || animation.curAnim == null || animation.curAnim.name != value)
        {
            state = value;
            animation.play(state);

            if (data != null && data.states != null)
            {
                for (s in data.states)
                {
                    if (s.name == state)
                    {
                        if (s.offsets != null && s.offsets.length >= 2)
                            iconOffsetPoint.set(s.offsets[0], s.offsets[1]);
                    
                        break;
                    }
                }
            }
        }
        return value;
    }

    public var data(get, never):IconData;

    function get_data():IconData
    {
        return HealthIconRegistry.get(iconName);
    }

    public var iconType:IconType = LEFT;
    public var iconName:String = "dummy"; 

    public var canUpdatePosition:Bool = true;
    public var canUpdateState:Bool = true;
    public var canUpdateOffsets:Bool = true;
    public var canBounce:Bool = true;

    public var originalScale(default, set):FlxPoint = FlxPoint.get(1.0, 1.0);

    function set_originalScale(value:FlxPoint):FlxPoint
    {
        originalScale = value;
        scale.set(value.x, value.y);
        updateHitbox();
        return value;
    }

    public var lerpAngle:Float = 0.0;
    public var iconOffsetPoint:FlxPoint = FlxPoint.get(0.0, 0.0);
    public var bar:FlxBar;

    public var trackerBarOffset:Float = -26;

    public var bopTween:FlxTween = null;

    public function new(?params:HealthIconParams)
    {
        super();

        if (params != null)
        {
            this.character = params.character;
            this.iconType = params.type;
            this.bar = params.bar;
        }
    }
    
    override function updateHitbox()
    {
        super.updateHitbox();
        if (!canUpdateOffsets) return;

        offset.x += iconOffsetPoint.x;
        offset.y += iconOffsetPoint.y;   
    }

    public function changeIcon(char:String = 'none')
    {
        iconName = char;
        loadIcon(char);
        updateHitbox();
    }

    private function loadIcon(char:String)
    {
        var iconPath:String = 'characters/$char/icon';
        var isSparrow:Bool = false;

        if (!Paths.exists('images/$iconPath.png'))
            iconPath = 'game/ui/dummy'; 
        else if (Paths.exists('images/$iconPath.xml'))
            isSparrow = true;

        var iconData:IconData = HealthIconRegistry.get(iconName);

        if (isSparrow)
        {
            frames = Paths.getSparrowAtlas(iconPath);
        }
        else
        {
            var graphic = FlxG.bitmap.add(Paths.image(iconPath));
            if (graphic == null) return;

            var totalFrames = 1;

            if (iconData != null && iconData.states != null)
            {
                var maxIndex = 0;
                
                for (s in iconData.states)
                {
                    var arr:Array<Dynamic> = cast s.prefix;

                    for (v in arr) 
                    {
                        if (Std.int(v) > maxIndex)
                            maxIndex = Std.int(v);
                    }
                }

                totalFrames = Std.int(Math.max(iconData.states.length, maxIndex + 1));
            }

            var frameWidth = Std.int(graphic.width / totalFrames);

            if (frameWidth <= 0)
                frameWidth = graphic.width;

            loadGraphic(graphic, true, frameWidth, graphic.height);
        }

        if (iconData != null)
        {
            if (iconData.scale != null && iconData.scale.length >= 2)
                originalScale = FlxPoint.get(iconData.scale[0], iconData.scale[1]);
            else
                originalScale = FlxPoint.get(1.0, 1.0);
                
            antialiasing = iconData.antialiasing;

            if (iconData.states != null)
            {
                for (stateData in iconData.states)
                {
                    if (isSparrow)
                        animation.addByPrefix(stateData.name, Std.string(stateData.prefix), stateData.fps, stateData.looped);
                    else
                    {
                        var framesArr:Array<Int> = [];
                        
                        if (Std.isOfType(stateData.prefix, Array))
                        {
                            var arr:Array<Dynamic> = cast stateData.prefix;
                            for (v in arr) framesArr.push(Std.int(v));
                        }
                        else 
                            framesArr = [0]; 

                        animation.add(stateData.name, framesArr, stateData.fps, stateData.looped);
                    }
                }
            }
        }
        else 
        {
            originalScale = FlxPoint.get(1.0, 1.0);
            antialiasing = true;

            if (isSparrow)
            {
                animation.addByPrefix('neutral', 'neutral', 24, false);
                animation.addByPrefix('losing', 'losing', 24, false);
            }
            else
            {
                animation.add('neutral', [0], 24, false);
                animation.add('losing', [1], 24, false);
            }
        }

        state = "neutral";
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        updatePosition();

        if (canUpdateState && bar != null && iconType != CENTER)
        {
            var curHealth = (iconType == LEFT) ? (100 - bar.percent) : bar.percent;
            var targetState = "neutral";
            
            if (data != null && data.states != null)
            {               
                targetState = data.states[data.states.length - 1].name;
                
                for (s in data.states)
                {
                    if (s.value > 0 && curHealth <= s.value)
                    {
                        targetState = s.name;
                        break;
                    }
                }
            }
            
            state = targetState;
        }
    }

    public function updatePosition():Void
    {
        if (!canUpdatePosition || bar == null) return;

        var hPercent:Float = 1 - (Reflect.field(bar.parent, bar.parentVariable) / 2);
        var trackerX:Float = bar.x + (bar.width * hPercent);
        var iconOffset:Float = Math.abs(trackerBarOffset);

        switch (iconType)
        {
            case LEFT: 
                this.x = trackerX - this.width + iconOffset + data.position[0];
            case RIGHT: 
                this.x = trackerX - iconOffset + data.position[0];
            case CENTER: 
                this.x = trackerX - (this.width / 2) + data.position[0];
        }

        this.y = bar.y - (this.height / 2) + data.position[1];
        
        this.updateHitbox();
    }

    public function bounce():Void
    {
        if (!canBounce || iconType == CENTER) return;

        if (bopTween != null)
            bopTween.cancel();

        var targetWidth:Float = this.frameWidth * originalScale.x;
        var targetHeight:Float = this.frameHeight * originalScale.y;

        var bounceWidth:Float = targetWidth + (targetWidth * 0.2);
        var bounceHeight:Float = targetHeight + (targetHeight * 0.2);

        setGraphicSize(Std.int(bounceWidth), Std.int(bounceHeight));
        this.updateHitbox();
        this.updatePosition();

        bopTween = FlxTween.num(bounceWidth, targetWidth, Math.min(Conductor.instance.stepLengthMs * 0.002, 0.175), {
            onComplete: function(twn:FlxTween) { bopTween = null; }
        }, function(value:Float) {
            
            var ratio = (value - targetWidth) / (bounceWidth - targetWidth);
            if (Math.isNaN(ratio)) ratio = 0;
            var curHeight = targetHeight + ((bounceHeight - targetHeight) * ratio);

            setGraphicSize(Std.int(value), Std.int(curHeight));
            this.updateHitbox();
            this.updatePosition();
        });
    }
}