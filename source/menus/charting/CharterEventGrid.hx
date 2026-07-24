package menus.charting;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.addons.display.FlxRuntimeShader;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxDestroyUtil;

class CharterEventGrid extends FlxBasic
{
    static inline final ICON_PADDING:Float = 5.0;

    public var events:Array<CharterEvent>;

    public var cellSize(default, null):Float;
    public var outline(default, null):Float;
    public var stripHeight(default, null):Float;
    public var timelineWidth(default, null):Float = 0;

    public var stripTop(default, null):Float = 0;
    public var markerX(default, null):Float = 0;

    var _camera:FlxCamera;
    var _defaultIcon:FlxGraphic;
    var _iconCache:Map<String, FlxGraphic> = new Map();

    var _backing:FunkinSprite;
    var _grid:FunkinSprite;
    var _markerLine:FunkinSprite;
    var _hoverBox:FunkinSprite;

    var _iconPool:Array<FunkinSprite> = [];
    var _iconCount:Int = 0;

    var _viewWidth:Float = 0;
    var _hovering:Bool = false;

    public function new(events:Array<CharterEvent>, cellSize:Float, outline:Float, camera:FlxCamera)
    {
        super();

        this.events = events;
        this.cellSize = cellSize;
        this.outline = outline;
        this._camera = camera;

        this.stripHeight = cellSize + (outline * 2);

        _defaultIcon = resolveIcon("default");

        _backing = new FunkinSprite().makeGraphic(1, 1, 0xFF16161C);
        _backing.alpha = 0.92;
        prep(_backing, 0, 0);

        _grid = new FunkinSprite();
        _grid.loadGraphic(Paths.image("menus/charter/pixel"));
        prep(_grid, 1, 0);

        _hoverBox = new FunkinSprite().makeGraphic(1, 1, FlxColor.WHITE);
        _hoverBox.alpha = 0.3;
        _hoverBox.visible = false;
        prep(_hoverBox, 1, 0);

        _markerLine = new FunkinSprite().makeGraphic(1, 1, 0xFFF5F5F5);
        prep(_markerLine, 0, 0);
    }

    inline function prep(sprite:FunkinSprite, scrollX:Float, scrollY:Float):Void
    {
        sprite.origin.set(0, 0);
        sprite.scrollFactor.set(scrollX, scrollY);
        sprite.camera = _camera;
    }

    function resolveIcon(name:String):FlxGraphic
    {
        var key:String = Paths.image('menus/charter/events/$name');
        if (key == null) return null;

        var graphic:FlxGraphic = FlxG.bitmap.get(key);
        if (graphic == null) graphic = FlxG.bitmap.add(key);

        return graphic;
    }

    function iconGraphicFor(name:String):FlxGraphic
    {
        if (name == null || name == "") return _defaultIcon;
        if (_iconCache.exists(name)) return _iconCache.get(name);

        var graphic:FlxGraphic = _defaultIcon;

        if (Paths.exists('images/menus/charter/events/$name.png'))
        {
            var resolved:FlxGraphic = resolveIcon(name);
            if (resolved != null) graphic = resolved;
        }

        _iconCache.set(name, graphic);
        return graphic;
    }

    public function build(timelineWidth:Float):Void
    {
        this.timelineWidth = Math.max(timelineWidth, cellSize);

        var shader:FlxRuntimeShader = new FlxRuntimeShader(Paths.frag("engine/grid"));

        _grid.setGraphicSize(Std.int(this.timelineWidth + (outline * 2)), Std.int(stripHeight));
        _grid.updateHitbox();
        _grid.shader = shader;

        shader.setFloatArray("u_spriteSize", [_grid.width, _grid.height]);
        shader.setFloat("u_gridSize", cellSize);
        shader.setFloat("u_outline", outline);
        shader.setBool("u_outlineTop", true);
        shader.setBool("u_outlineBottom", true);
        shader.setBool("u_horizontal", true);

        var tint:FlxColor = FlxColor.interpolate(FlxColor.WHITE, 0xFFFFC864, 0.22);
        shader.setFloatArray("u_tint", [tint.redFloat, tint.greenFloat, tint.blueFloat]);
    }

    public function layout(stripTop:Float, markerX:Float, viewWidth:Float):Void
    {
        this.stripTop = stripTop;
        this.markerX = markerX;
        this._viewWidth = viewWidth;

        _backing.setGraphicSize(viewWidth, stripHeight);
        _backing.updateHitbox();
        _backing.setPosition(0, stripTop);

        _grid.setPosition(0, stripTop);

        _markerLine.setGraphicSize(3, stripHeight - (outline * 2));
        _markerLine.updateHitbox();
        _markerLine.setPosition(markerX - 1, stripTop + outline);
    }

    inline function pixelsPerMs(stepLengthMs:Float):Float
    {
        return cellSize / stepLengthMs;
    }

    inline function xForTime(time:Float, scale:Float):Float
    {
        return outline + (time * scale);
    }

    public inline function containsStrip(worldY:Float):Bool
    {
        return worldY >= stripTop && worldY <= stripTop + stripHeight;
    }

    public inline function inGrid(worldX:Float):Bool
    {
        return worldX >= outline && worldX <= outline + timelineWidth;
    }

    public function timeAtX(worldX:Float, stepLengthMs:Float):Float
    {
        if (stepLengthMs <= 0) return 0;

        var time:Float = (worldX - outline) / pixelsPerMs(stepLengthMs);
        return (time < 0) ? 0 : time;
    }

    public function eventAt(worldX:Float, worldY:Float, stepLengthMs:Float):CharterEvent
    {
        if (!containsStrip(worldY) || stepLengthMs <= 0) return null;

        var scale:Float = pixelsPerMs(stepLengthMs);

        for (event in events)
        {
            var left:Float = xForTime(event.time, scale);

            if (worldX >= left && worldX <= left + cellSize)
                return event;
        }

        return null;
    }

    public function updateHover(worldX:Float, snapCells:Float, free:Bool):Void
    {
        _hovering = true;

        var boxWidth:Float = cellSize * snapCells;
        if (boxWidth < 1) boxWidth = cellSize;

        var left:Float;

        if (free)
            left = worldX;
        else
            left = outline + (Math.floor((worldX - outline) / boxWidth) * boxWidth);

        var maxLeft:Float = outline + timelineWidth - boxWidth;
        if (left < outline) left = outline;
        if (maxLeft >= outline && left > maxLeft) left = maxLeft;

        _hoverBox.setGraphicSize(boxWidth, cellSize);
        _hoverBox.updateHitbox();
        _hoverBox.setPosition(left, stripTop + outline);
    }

    public function hideHover():Void
    {
        _hovering = false;
    }

    public function refresh(leftTime:Float, rightTime:Float, stepLengthMs:Float, playheadX:Float):Void
    {
        _iconCount = 0;

        if (!visible || stepLengthMs <= 0) return;

        var scale:Float = pixelsPerMs(stepLengthMs);
        var iconSize:Float = cellSize - (ICON_PADDING * 2);
        var iconY:Float = stripTop + outline + ICON_PADDING;

        for (event in events)
        {
            if (event.time > rightTime) continue;
            if (event.time + (cellSize / scale) <= leftTime) continue;

            var boxLeft:Float = xForTime(event.time, scale);

            var icon:FunkinSprite = acquireIcon();

            var graphic:FlxGraphic = iconGraphicFor(event.name);
            if (graphic != null && icon.graphic != graphic)
                icon.loadGraphic(graphic);

            fitIcon(icon, boxLeft + ICON_PADDING, iconY, iconSize);

            icon.color = ((boxLeft + (cellSize / 2)) < playheadX) ? 0xFF999999 : 0xFFFFFFFF;
        }
    }

    inline function acquireIcon():FunkinSprite
    {
        var sprite:FunkinSprite = (_iconCount < _iconPool.length) ? _iconPool[_iconCount] : null;

        if (sprite == null)
        {
            sprite = new FunkinSprite();
            sprite.makeGraphic(1, 1, FlxColor.TRANSPARENT);

            prep(sprite, 1, 0);
            _iconPool.push(sprite);
        }

        _iconCount++;
        return sprite;
    }

    inline function fitIcon(sprite:FunkinSprite, boxX:Float, boxY:Float, boxSize:Float):Void
    {
        if (sprite.frameWidth > 0 && sprite.frameHeight > 0)
        {
            var scale:Float = Math.min(boxSize / sprite.frameWidth, boxSize / sprite.frameHeight);
            if (scale <= 0) scale = 0.01;

            sprite.scale.set(scale, scale);
            sprite.updateHitbox();
        }

        sprite.setPosition(boxX + (boxSize - sprite.width) / 2, boxY + (boxSize - sprite.height) / 2);
    }

    override public function draw():Void
    {
        if (!visible) return;

        _backing.draw();
        _grid.draw();

        if (_hovering)
            _hoverBox.draw();

        for (i in 0..._iconCount)
            _iconPool[i].draw();

        _markerLine.draw();
    }

    override public function destroy():Void
    {
        for (sprite in _iconPool)
            sprite.destroy();

        _iconPool = null;
        _iconCache = null;

        _backing = FlxDestroyUtil.destroy(_backing);
        _grid = FlxDestroyUtil.destroy(_grid);
        _hoverBox = FlxDestroyUtil.destroy(_hoverBox);
        _markerLine = FlxDestroyUtil.destroy(_markerLine);

        events = null;
        _camera = null;

        super.destroy();
    }
}
