package backend.assets;

import away3d.containers.ObjectContainer3D;
import away3d.core.math.Quaternion;
import openfl.Vector;
import openfl.geom.Matrix3D;
import openfl.geom.Vector3D;

typedef GLTFSampler = 
{
    var times:Array<Float>;
    var values:Array<Float>;
    var interp:String;
}

typedef GLTFNodeTrack = 
{
    var container:ObjectContainer3D;
    var base:Array<Float>;
    var t:GLTFSampler;
    var r:GLTFSampler;
    var s:GLTFSampler;
}

typedef GLTFNodeClip = 
{
    var name:String;
    var startTime:Float;
    var duration:Float;
    var tracks:Array<GLTFNodeTrack>;
}

class GLTFNodeAnimator 
{
    public var names(get, never):Array<String>;
    
    var _clips:Map<String, GLTFNodeClip> = new Map();
    var _names:Array<String> = [];
    var _active:GLTFNodeClip;
    var _absTime:Float = 0;
    var _lastTime:Float = -1;
    var _loop:Bool = true;

    public function new() {}

    function get_names():Array<String> 
    {
        return _names;
    }

    public function addClip(clip:GLTFNodeClip):Void 
    {
        if (!_clips.exists(clip.name)) 
            _names.push(clip.name);
            
        _clips.set(clip.name, clip);
    }

    public function hasClip(name:String):Bool 
    {
        return _clips.exists(name);
    }

    public function play(name:String, loop:Bool = true):Void 
    {
        if (!_clips.exists(name)) 
            return;

        _active = _clips.get(name);
        _loop = loop;
        _absTime = 0;
        _lastTime = -1;

        applyAt(_active.startTime);
    }

    public function update(timeMs:Float):Void 
    {
        if (_active == null) 
            return;

        if (_lastTime < 0) 
            _lastTime = timeMs;

        _absTime += (timeMs - _lastTime);
        _lastTime = timeMs;

        var durMs = _active.duration * 1000;
        var phase = 0.0;
        
        if (durMs > 0) 
            phase = _loop ? (_absTime % durMs) : Math.min(_absTime, durMs);

        applyAt(_active.startTime + (phase / 1000));
    }

    function applyAt(t:Float):Void 
    {
        for (track in _active.tracks) 
        {
            var trans = track.t != null ? eval(track.t, 3, false, t) : track.base.slice(0, 3);
            var rot = track.r != null ? eval(track.r, 4, true, t) : track.base.slice(3, 7);
            var scale = track.s != null ? eval(track.s, 3, false, t) : track.base.slice(7, 10);

            var q = new Quaternion(-rot[0], -rot[1], rot[2], rot[3]);
            var m = q.toMatrix3D();
            m.prependScale(scale[0], scale[1], scale[2]);
            m.appendTranslation(trans[0], trans[1], -trans[2]);

            track.container.transform = m;
        }
    }

    public static function eval(s:GLTFSampler, comps:Int, isQuat:Bool, t:Float):Array<Float> 
    {
        var times = s.times;
        var n = times.length;
        
        if (n == 0) 
            return isQuat ? [0.0, 0.0, 0.0, 1.0] : [for (_ in 0...comps) 0.0];
            
        if (t <= times[0]) 
            return getKeyValue(s, 0, comps);
            
        if (t >= times[n - 1]) 
            return getKeyValue(s, n - 1, comps);

        var i = 0;
        while (i < n - 1 && times[i + 1] <= t) 
            i++;

        if (s.interp == "STEP") 
            return getKeyValue(s, i, comps);

        var f = (t - times[i]) / (times[i + 1] - times[i]);
        var v1 = getKeyValue(s, i, comps);
        var v2 = getKeyValue(s, i + 1, comps);

        if (isQuat) 
        {
            var q1 = new Quaternion(v1[0], v1[1], v1[2], v1[3]);
            var q2 = new Quaternion(v2[0], v2[1], v2[2], v2[3]);
            var result = new Quaternion();
            result.slerp(q1, q2, f);
            return [result.x, result.y, result.z, result.w];
        } 
        else 
            return [for (c in 0...comps) v1[c] + (v2[c] - v1[c]) * f];
    }

    static inline function getKeyValue(s:GLTFSampler, index:Int, comps:Int):Array<Float> 
    {
        var stride = (s.interp == "CUBICSPLINE") ? 3 : 1;
        var valueOffset = (s.interp == "CUBICSPLINE") ? comps : 0;
        var base = (index * stride) * comps + valueOffset;
        return s.values.slice(base, base + comps);
    }
}