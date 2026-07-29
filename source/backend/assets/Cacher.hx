package backend.assets;

import sys.FileSystem;

import openfl.utils.IAssetCache;
import openfl.utils.Assets;

import openfl.media.Sound;
import openfl.display.BitmapData;
import openfl.text.Font;
import flixel.graphics.FlxGraphic;

import away3d.materials.TextureMaterial;
import away3d.textures.Texture2DBase;
import away3d.materials.utils.DefaultMaterialManager;
import backend.assets.GLTFParser.GLTFModel;

import backend.utils.MemoryUtil;
#if lime
import lime.utils.Assets as LimeAssets;
#end

typedef CacheSnapshot =
{
    var graphics:Map<String, Bool>;
    var sounds:Map<String, Bool>;
    var streams:Array<Sound>;
    var generation:Int;
}

class Cacher
{
    public static var instance(get, never):Cacher;
    private static var _instance:Cacher;

    private static function get_instance():Cacher
    {
        if (_instance == null)
            _instance = new Cacher();

        return _instance;
    }

    public static function init():Void
    {
        get_instance();
    }

    public var usedGraphics:Map<String, FlxGraphic> = [];
    public var agedGraphics:Map<String, FlxGraphic> = [];

    public var permanentIds:Map<String, Bool> = [];
    public var preloadedIds:Map<String, Int> = [];

    public var models:Map<String, GLTFModel> = [];

    public var activeStreams:Array<Sound> = [];
    private var streamGeneration:Map<Sound, Int> = new Map();

    private var _snapshotStack:Array<CacheSnapshot> = [];

    public var generation(default, null):Int = 0;
    
    public function new()
    {
        FlxG.signals.preStateSwitch.add(preStateSwitch);
        FlxG.signals.postStateSwitch.add(postStateSwitch);
    }

    public function destroy()
    {
        FlxG.signals.preStateSwitch.remove(preStateSwitch);
        FlxG.signals.postStateSwitch.remove(postStateSwitch);
    }

    public function registerGraphic(graphic:FlxGraphic, permanent:Bool = false, preload:Bool = false):Void
    {
        if (graphic == null || graphic.key == null) return;
        if (graphic.key.startsWith("flixel")) return;

        agedGraphics.remove(graphic.key);
        usedGraphics.set(graphic.key, graphic);

        if (permanent) permanentIds.set(graphic.key, true);
        if (preload) preloadedIds.set(graphic.key, 2);
    }

    public function markPermanent(id:String):Void
    {
        if (id != null)
            permanentIds.set(id, true);
    }

    public function markPreloaded(id:String, survivals:Int = 2):Void
    {
        if (id != null)
            preloadedIds.set(id, survivals);
    }

    public function takeModel(id:String):GLTFModel
    {
        var model = models.get(id);

        if (model == null)
            return null;

        models.remove(id);

        if (isFileStale(id))
        {
            freeModel(model);
            fileStamps.remove(id);

            return null;
        }

        return model;
    }

    public function putModel(id:String, model:GLTFModel):Void
    {
        if (id == null || model == null)
            return;

        if (models.exists(id))
        {
            freeModel(model);
            return;
        }

        models.set(id, model);
    }

    public function freeModel(model:GLTFModel):Void
    {
        if (model == null)
            return;

        var defaultTex = DefaultMaterialManager.getDefaultTexture();
        var freed:Array<Texture2DBase> = [];

        for (mesh in model.meshes)
        {
            if (!Std.isOfType(mesh.material, TextureMaterial))
                continue;

            var tex = cast(mesh.material, TextureMaterial).texture;

            if (tex == null || tex == defaultTex || freed.contains(tex))
                continue;

            freed.push(tex);
            tex.dispose();
        }

        for (bmp in model.bitmaps)
            bmp.dispose();

        if (model.object != null)
            model.object.disposeWithChildren();
    }

    public function clearModels():Void
    {
        for (model in models)
            freeModel(model);

        models = [];
    }

    public function registerStream(snd:Sound, permanent:Bool = false):Void
    {
        if (snd == null) return;
        if (!activeStreams.contains(snd))
            activeStreams.push(snd);

        streamGeneration.set(snd, permanent ? -1 : generation);
    }

    public function isStream(snd:Sound):Bool
    {
        return snd != null && activeStreams.contains(snd);
    }

    public function closeStream(snd:Sound):Void
    {
        if (snd == null || !activeStreams.remove(snd)) return;
        streamGeneration.remove(snd);

        try snd.close() catch (e:Dynamic) {}
    }

    private var fileStamps:Map<String, {path:String, mtime:Float, size:Int}> = new Map();

    public function stampFile(id:String, path:String):Void
    {
        if (id == null || path == null) return;

        try
        {
            var stat = FileSystem.stat(path);
            fileStamps.set(id, {path: path, mtime: stat.mtime.getTime(), size: stat.size});
        }
        catch (e:Dynamic) {}
    }

    public function isFileStale(id:String):Bool
    {
        var stamp = fileStamps.get(id);
        if (stamp == null) return false;

        try
        {
            var stat = FileSystem.stat(stamp.path);
            return stat.mtime.getTime() != stamp.mtime || stat.size != stamp.size;
        }
        catch (e:Dynamic)
        {
            return false;
        }
    }

    public function evictSound(id:String):Void
    {
        if (id == null) return;

        fileStamps.remove(id);
        preloadedIds.remove(id);

        var rev = revCache();
        if (rev == null) return;

        var snd = rev.sound.get(id);
        if (snd == null) snd = rev.sound2.get(id);

        rev.removeSound(id);

        if (snd != null)
        {
            #if lime_vorbis
            @:privateAccess
            {
                if (snd.__buffer != null && snd.__buffer.__srcVorbisFile != null)
                    try snd.__buffer.__srcVorbisFile.clear() catch (e:Dynamic) {}
            }
            #end

            try snd.close() catch (e:Dynamic) {}
        }
    }

    public function refreshStaleGraphic(key:String):Bool
    {
        if (!isFileStale(key)) return false;

        var graphic = usedGraphics.get(key);

        if (graphic == null) graphic = agedGraphics.get(key);
        if (graphic == null) graphic = FlxG.bitmap.get(key);

        if (graphic != null && graphic.useCount > 0)
            return false;

        trace('Cached graphic "$key" changed on disk, refreshing...', "INFO");
        evictGraphic(key);

        return true;
    }

    public function evictGraphic(key:String):Void
    {
        if (key == null) return;

        fileStamps.remove(key);
        preloadedIds.remove(key);
        usedGraphics.remove(key);
        agedGraphics.remove(key);

        FlxG.bitmap.removeByKey(key);

        #if lime
        LimeAssets.cache.image.remove(key);
        #end

        var rev = revCache();
        if (rev != null) rev.removeBitmapData(key);
    }

    public function evictFont(id:String):Void
    {
        if (id == null) return;

        fileStamps.remove(id);

        var rev = revCache();
        if (rev != null) rev.removeFont(id);
    }

    public function clearAll():Void
    {
        for (key => graphic in usedGraphics)
            agedGraphics.set(key, graphic);
        
        usedGraphics = [];

        var rev = revCache();
        if (rev != null) rev.demoteMerge();

        preloadedIds.clear();
        clearModels();

        sweepAged();
        MemoryUtil.freeUnusedMemory();
    }

    private function revCache():RevAssets
    {
        return RevAssets.ensureActive();
    }

    private function isProtectedId(id:String):Bool
    {
        if (id == null) return false;

        if (permanentIds.exists(id) || preloadedIds.exists(id))
            return true;

        var target = id.toLowerCase();

        for (key in permanentIds.keys())
        {
            if (key != null && key.toLowerCase() == target)
                return true;
        }

        for (key in preloadedIds.keys())
        {
            if (key != null && key.toLowerCase() == target)
                return true;
        }

        return false;
    }

    function preStateSwitch()
    {
        generation++;

        agedGraphics = usedGraphics;
        usedGraphics = [];

        var rev = revCache();
        if (rev != null) rev.demote();

        var deadPreloads:Array<String> = [];

        for (id in preloadedIds.keys())
        {
            var graphic = agedGraphics.get(id);
            if (graphic != null)
            {
                agedGraphics.remove(id);
                usedGraphics.set(id, graphic);
            }

            if (rev != null)
            {
                rev.promoteSoundLoose(id);
                rev.promoteBitmapData(id);
            }

            var surviving = preloadedIds.get(id) - 1;

            if (surviving <= 0)
                deadPreloads.push(id);
            else
                preloadedIds.set(id, surviving);
        }

        for (id in deadPreloads)
            preloadedIds.remove(id);
    }

    function postStateSwitch()
    {
        sweepAged();
        MemoryUtil.freeUnusedMemory();
    }

    private function sweepAged():Void
    {
        var rev = revCache();
        var playing:Array<Sound> = [];

        @:privateAccess
        {
            for (snd in FlxG.sound.list)
            {
                if (snd != null && snd.playing && snd._sound != null)
                    playing.push(snd._sound);
            }

            if (FlxG.sound.music != null && FlxG.sound.music.playing && FlxG.sound.music._sound != null)
                playing.push(FlxG.sound.music._sound);
        }

        for (key => graphic in agedGraphics)
        {
            if (permanentIds.exists(key))
            {
                usedGraphics.set(key, graphic);
                continue;
            }

            FlxG.bitmap.removeByKey(key);

            fileStamps.remove(key);

            #if lime
            LimeAssets.cache.image.remove(key);
            #end
        }
        agedGraphics = [];
        
        if (rev != null)
        {
            for (id => snd in rev.sound2)
            {
                if (snd == null) continue;
                
                if (isProtectedId(id) || playing.contains(snd))
                {
                    rev.sound.set(id, snd);
                    continue;
                }

                try snd.close() catch (e:Dynamic) {}

                fileStamps.remove(id);

                #if lime
                LimeAssets.cache.audio.remove(id);
                #end
            }

            rev.sound2 = [];

            for (id => bmp in rev.bitmapData2)
            {
                if (permanentIds.exists(id))
                {
                    rev.bitmapData.set(id, bmp);
                    continue;
                }

                if (bmp != null)
                {
                    bmp.dispose();
                    bmp.disposeImage();
                }

                #if lime
                LimeAssets.cache.image.remove(id);
                #end
            }
            
            rev.bitmapData2 = [];
        }

        var i = activeStreams.length - 1;
        while (i >= 0)
        {
            var snd = activeStreams[i];
            if (snd == null)
            {
                activeStreams.splice(i, 1);
                i--;
                continue;
            }

            var gen:Null<Int> = streamGeneration.get(snd);
            var expired = (gen == null || (gen != -1 && gen < generation)) && !playing.contains(snd);

            if (expired)
            {
                try snd.close() catch (e:Dynamic) {}

                streamGeneration.remove(snd);
                activeStreams.splice(i, 1);
            }
            i--;
        }
    }

    private function detectPlayingSounds():Array<Sound>
    {
        var playing:Array<Sound> = [];

        @:privateAccess
        {
            for (snd in FlxG.sound.list)
            {
                if (snd != null && snd.playing && snd._sound != null)
                    playing.push(snd._sound);
            }

            if (FlxG.sound.music != null && FlxG.sound.music.playing && FlxG.sound.music._sound != null)
                playing.push(FlxG.sound.music._sound);
        }

        return playing;
    }

    public function pushSnapshot():Void
    {
        var graphics:Map<String, Bool> = [];

        for (key in usedGraphics.keys())
            graphics.set(key, true);

        var sounds:Map<String, Bool> = [];
        var rev = revCache();

        if (rev != null)
        {
            for (id in rev.sound.keys())
                sounds.set(id, true);
        }

        _snapshotStack.push({graphics: graphics, sounds: sounds, streams: activeStreams.copy(), generation: generation});
    }

    public function popSnapshot():Void
    {
        if (_snapshotStack.length == 0) return;

        var snapshot = _snapshotStack.pop();

        if (snapshot.generation != generation) return;

        var rev = revCache();
        var playing = detectPlayingSounds();

        var deadGraphics:Array<String> = [];
        for (key in usedGraphics.keys())
        {
            if (snapshot.graphics.exists(key) || isProtectedId(key)) continue;

            var graphic = usedGraphics.get(key);
            if (graphic != null && graphic.useCount > 0) continue;

            deadGraphics.push(key);
        }

        for (key in deadGraphics)
            evictGraphic(key);

        if (rev != null)
        {
            var deadSounds:Array<String> = [];
            for (id in rev.sound.keys())
            {
                if (snapshot.sounds.exists(id) || isProtectedId(id)) continue;

                var snd = rev.sound.get(id);
                if (snd == null || playing.contains(snd)) continue;

                deadSounds.push(id);
            }

            for (id in deadSounds)
            {
                var snd = rev.sound.get(id);

                if (snd != null)
                    try snd.close() catch (e:Dynamic) {}

                rev.removeSound(id);
                fileStamps.remove(id);
            }
        }

        var i = activeStreams.length - 1;
        while (i >= 0)
        {
            var snd = activeStreams[i];

            if (snd != null && snapshot.streams.indexOf(snd) == -1 && !playing.contains(snd) && streamGeneration.get(snd) != -1)
            {
                try snd.close() catch (e:Dynamic) {}

                streamGeneration.remove(snd);
                activeStreams.splice(i, 1);
            }

            i--;
        }

        if (!(FlxG.state is game.PlayState))
            MemoryUtil.freeUnusedMemory();
    }
}

class RevAssets implements IAssetCache
{
    public static var instance(get, never):RevAssets;
    private static var _instance:RevAssets;

    private static function get_instance():RevAssets
    {
        if (_instance == null)
            _instance = new RevAssets();

        return _instance;
    }

    public static function ensureActive():RevAssets
    {
        var rev = instance;

        if (Assets.cache != rev)
            Assets.cache = rev;

        return rev;
    }

    public var enabled(get, set):Bool;
    private var __enabled:Bool = true;

    private function get_enabled():Bool
        return __enabled;

    private function set_enabled(value:Bool):Bool
        return __enabled = value;

    public var sound:Map<String, Sound> = [];
    public var bitmapData:Map<String, BitmapData> = [];

    public var font:Map<String, Font> = [];

    public var sound2:Map<String, Sound> = [];
    public var bitmapData2:Map<String, BitmapData> = [];

    public function new() {}

    public function demote():Void
    {
        sound2 = sound;
        sound = [];

        bitmapData2 = bitmapData;
        bitmapData = [];
    }

    public function demoteMerge():Void
    {
        for (id => snd in sound)
            sound2.set(id, snd);

        sound = [];

        for (id => bmp in bitmapData)
            bitmapData2.set(id, bmp);

        bitmapData = [];
    }

    public function promoteSound(id:String):Sound
    {
        var snd = sound.get(id);

        if (snd != null)
            return snd;

        snd = sound2.get(id);

        if (snd != null)
        {
            sound2.remove(id);
            sound.set(id, snd);
        }

        return snd;
    }

    public function promoteSoundLoose(id:String):Sound
    {
        var snd = promoteSound(id);
        if (snd != null)
            return snd;

        var target = id.toLowerCase();

        for (key in sound.keys())
        {
            if (key != null && key.toLowerCase() == target)
                return sound.get(key);
        }

        for (key in sound2.keys())
        {
            if (key != null && key.toLowerCase() == target)
                return promoteSound(key);
        }

        return null;
    }

    public function promoteBitmapData(id:String):BitmapData
    {
        var bmp = bitmapData.get(id);
        if (bmp != null)
            return bmp;

        bmp = bitmapData2.get(id);
        if (bmp != null)
        {
            bitmapData2.remove(id);
            bitmapData.set(id, bmp);
        }
        return bmp;
    }

    public function getSound(id:String):Sound
    {
        return promoteSoundLoose(id);
    }

    public function hasSound(id:String):Bool
    {
        return sound.exists(id) || sound2.exists(id);
    }

    public function removeSound(id:String):Bool
    {
        #if lime
        LimeAssets.cache.audio.remove(id);
        #end

        var removedUsed = sound.remove(id);
        var removedAged = sound2.remove(id);
        return removedUsed || removedAged;
    }

    public function setSound(id:String, snd:Sound):Void
    {
        @:privateAccess snd.url = id;

        if (sound2.get(id) == snd)
            sound2.remove(id);

        sound.set(id, snd);
    }

    public function getBitmapData(id:String):BitmapData
    {
        return promoteBitmapData(id);
    }

    public function hasBitmapData(id:String):Bool
    {
        return bitmapData.exists(id) || bitmapData2.exists(id);
    }

    public function removeBitmapData(id:String):Bool
    {
        #if lime
        LimeAssets.cache.image.remove(id);
        #end

        var removedUsed = bitmapData.remove(id);
        var removedAged = bitmapData2.remove(id);
        return removedUsed || removedAged;
    }

    public function setBitmapData(id:String, bmp:BitmapData):Void
    {
        if (bitmapData2.get(id) == bmp)
            bitmapData2.remove(id);

        bitmapData.set(id, bmp);
    }

    public function getFont(id:String):Font
    {
        return font.get(id);
    }

    public function hasFont(id:String):Bool
    {
        return font.exists(id);
    }

    public function removeFont(id:String):Bool
    {
        #if lime
        LimeAssets.cache.font.remove(id);
        #end
        return font.remove(id);
    }

    public function setFont(id:String, fnt:Font):Void
    {
        font.set(id, fnt);
    }

    public function clear(prefix:String = null):Void
    {
        if (prefix == null)
        {
            sound = [];
            bitmapData = [];
            font = [];

            sound2 = [];
            bitmapData2 = [];

            return;
        }

        for (map in [sound, sound2])
        {
            var toRemove = [for (id in map.keys()) if (id.startsWith(prefix)) id];

            for (id in toRemove)
                map.remove(id);
        }

        for (map in [bitmapData, bitmapData2])
        {
            var toRemove = [for (id in map.keys()) if (id.startsWith(prefix)) id];

            for (id in toRemove)
                map.remove(id);
        }

        var fontsToRemove = [for (id in font.keys()) if (id.startsWith(prefix)) id];

        for (id in fontsToRemove)
            font.remove(id);
    }
}