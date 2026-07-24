package menus.charting;

import backend.utils.MathUtil;

import flixel.FlxBasic;
import flixel.FlxCamera;

class CharterStrumlineOutline extends FlxBasic
{
    var _edges:Array<FunkinSprite> = [];
    var _camera:FlxCamera;

    var _x:Float = 0;
    var _y:Float = 0;
    var _w:Float = 0;
    var _h:Float = 0;

    var _targetX:Float = 0;
    var _targetY:Float = 0;
    var _targetW:Float = 0;
    var _targetH:Float = 0;

    var _active:Bool = false;
    var _shown:Bool = false;

    public function new(camera:FlxCamera)
    {
        super();

        _camera = camera;

        for (i in 0...4)
        {
            var edge:FunkinSprite = new FunkinSprite().makeGraphic(1, 1, 0xFFFF0000);
            edge.origin.set(0, 0);
            edge.antialiasing = false;
            edge.alpha = 0.6;
            edge.camera = camera;

            _edges.push(edge);
        }
    }

    public function setTarget(x:Float, y:Float, w:Float, h:Float):Void
    {
        _targetX = x;
        _targetY = y;
        _targetW = w;
        _targetH = h;

        if (!_active)
        {
            _x = x;
            _y = y;
            _w = w;
            _h = h;
        }

        _active = true;
    }

    public function clearTarget():Void
    {
        _active = false;
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        _shown = _active;
        if (!_shown) return;

        _x = MathUtil.smoothLerpPrecision(_x, _targetX, elapsed, 0.15);
        _w = MathUtil.smoothLerpPrecision(_w, _targetW, elapsed, 0.15);
        
        _y = _targetY;
        _h = _targetH;

        layout();
    }

    function layout():Void
    {
        place(_edges[0], _x - 2, _y - 2, _w + (2 * 2), 2);
        place(_edges[1], _x - 2, _y + _h, _w + (2 * 2), 2);
        place(_edges[2], _x - 2, _y, 2, _h);      
        place(_edges[3], _x + _w, _y, 2, _h);
    }

    inline function place(edge:FunkinSprite, x:Float, y:Float, w:Float, h:Float):Void
    {
        edge.setGraphicSize(w, h);
        edge.updateHitbox();
        edge.setPosition(x, y);
    }

    override public function draw():Void
    {
        if (!_shown) return;

        for (edge in _edges)
            edge.draw();
    }

    override public function destroy():Void
    {
        for (edge in _edges)
            edge.destroy();

        _edges = null;
        _camera = null;

        super.destroy();
    }
}
