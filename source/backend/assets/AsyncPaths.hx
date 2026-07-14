package backend.assets;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import haxe.MainLoop;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import backend.utils.ThreadUtil;

import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.text.Font;
import openfl.utils.Assets;
import lime.media.AudioBuffer;
import lime.media.vorbis.VorbisFile;
import openfl.net.URLRequest;

class AsyncPaths
{
    public static function image(file:String, ?folder:String = "images", ?extension:String = "png", ?absolute:Bool = false, ?permanent:Bool = false, ?preload:Bool = false, ?onComplete:FlxGraphic->Void):Void
    {
        var ext = extension != "" ? '.$extension' : "";
        var cacheKey = absolute ? '$file$ext' : 'assets/$folder/$file$ext';
        cacheKey = Paths.findCachedGraphicKey(cacheKey);

        var existing = FlxG.bitmap.get(cacheKey);

        if (existing != null && Cacher.instance.refreshStaleGraphic(cacheKey))
            existing = null;

        if (existing != null)
        {
            Cacher.instance.registerGraphic(existing, permanent, preload);
            if (onComplete != null)
                onComplete(existing);
            return;
        }

        var realPath = Paths.getPath(cacheKey);
        ThreadUtil.execAsync(() -> {
            var bmp:BitmapData = null;

            if (FileSystem.exists(realPath))
                bmp = BitmapData.fromFile(realPath);
            else if (!Path.isAbsolute(cacheKey) && Assets.exists(cacheKey))
                bmp = Assets.getBitmapData(cacheKey, false);

            MainLoop.runInMainThread(() -> {
                if (bmp == null)
                {
                    if (onComplete != null) onComplete(null);
                    return;
                }

                var existing = FlxG.bitmap.get(cacheKey);
         
                if (existing != null)
                {
                    bmp.dispose();
                    bmp.disposeImage();

                    Cacher.instance.registerGraphic(existing, permanent, preload);
                    if (onComplete != null) onComplete(existing);
                    return;
                }

                bmp = Paths.toTexture(bmp);
                var graphic = FlxGraphic.fromBitmapData(bmp, false, cacheKey);
                graphic.persist = true;

                FlxG.bitmap.addGraphic(graphic);
                Cacher.instance.registerGraphic(graphic, permanent, preload);
                Cacher.instance.stampFile(cacheKey, realPath);

                if (onComplete != null)
                    onComplete(graphic);
            });
        });
    }

    public static function audio(file:String, ?folder:String = "audio", ?extension:String = "ogg", ?absolute:Bool = false, ?permanent:Bool = false, ?preload:Bool = false, ?stream:Bool = true, ?onComplete:Sound->Void):Void
    {
        var ext = extension != "" ? '.$extension' : "";
        var cacheKey = absolute ? '$file$ext' : 'assets/$folder/$file$ext';
        var realPath = Paths.getPath(cacheKey);

        var cached = Paths.findCachedSound(cacheKey);
        if (cached != null)
        {
            markSound(cacheKey, permanent, preload);
            if (onComplete != null) onComplete(cached);
            return;
        }

        ThreadUtil.execAsync(() -> {
            var audioBuffer:AudioBuffer = null;
            var snd:Sound = null;
            var wantsStream = stream && !preload && FileSystem.exists(realPath);

            if (!wantsStream)
            {
                if (FileSystem.exists(realPath))
                    audioBuffer = createEmbeddedBuffer(realPath, cacheKey);
            }

            MainLoop.runInMainThread(() -> {
                if (audioBuffer != null)
                    snd = Sound.fromAudioBuffer(audioBuffer);
                else if (!wantsStream && !Path.isAbsolute(cacheKey) && Assets.exists(cacheKey))
                    snd = Assets.getSound(cacheKey, true);

                var cached = Paths.findCachedSound(cacheKey);
                if (cached != null)
                {
                    if (snd != null && snd != cached)
                    {
                        try snd.close() catch (e:Dynamic) {}
                    }

                    markSound(cacheKey, permanent, preload);
                    if (onComplete != null) onComplete(cached);
                    return;
                }

                if (wantsStream)
                {
                    snd = new Sound(new URLRequest(realPath));
                    Cacher.instance.registerStream(snd, permanent);
                }
                else if (snd != null)
                {
                    Paths.ensureRevAssets().setSound(cacheKey, snd);
                    markSound(cacheKey, permanent, preload);

                    if (audioBuffer != null)
                        Cacher.instance.stampFile(cacheKey, realPath);
                }

                if (onComplete != null)
                    onComplete(snd);
            });
        });
    }

    public static function font(file:String, ?absolute:Bool = false, ?permanent:Bool = false, ?preload:Bool = false, ?onComplete:String->Void):Void
    {
        var cacheKey = absolute ? file : 'assets/fonts/$file';
        var realPath = Paths.getPath(cacheKey);

        if (Assets.cache.hasFont(cacheKey))
        {
            if (Cacher.instance.isFileStale(cacheKey))
            {
                trace('Cached font "$cacheKey" changed on disk, refreshing...', "CACHE");
                Cacher.instance.evictFont(cacheKey);
            }
            else
            {
                if (onComplete != null)
                    onComplete(cacheKey);

                return;
            }
        }

        ThreadUtil.execAsync(() -> {
            var fnt:Font = null;

            if (FileSystem.exists(realPath))
                fnt = Font.fromFile(realPath);
            else if (!Path.isAbsolute(cacheKey) && Assets.exists(cacheKey))
                fnt = Assets.getFont(cacheKey, true);

            MainLoop.runInMainThread(() -> {
                if (Assets.cache.hasFont(cacheKey))
                {
                    if (onComplete != null) onComplete(cacheKey);
                    return;
                }

                if (fnt != null)
                {
                    Assets.cache.setFont(cacheKey, fnt);
                    Font.registerFont(fnt);
                    Cacher.instance.stampFile(cacheKey, realPath);
                }

                if (onComplete != null)
                    onComplete(cacheKey);
            });
        });
    }

    static function markSound(id:String, permanent:Bool, preload:Bool):Void
    {
        if (permanent) Cacher.instance.markPermanent(id);
        if (preload) Cacher.instance.markPreloaded(id);
    }

    /**
     * Creates a fully in-memory AudioBuffer for the given file.
     */
    static function createEmbeddedBuffer(realPath:String, cacheKey:String):AudioBuffer
    {
        #if lime_vorbis
        var key = cacheKey.toLowerCase();

        if (key.indexOf("/songs/") != -1 && key.endsWith(".ogg"))
        {
            var vorbis = VorbisFile.fromFile(realPath);

            if (vorbis != null)
                return AudioBuffer.fromVorbisFile(vorbis);
        }
        #end

        return AudioBuffer.fromFile(realPath);
    }

    public static function data(file:String, ?folder:String = "data", ?absolute:Bool = false, ?onComplete:String->Void):Void
    {
        var cacheKey = absolute ? file : 'assets/$folder/$file';
        var realPath = Paths.getPath(cacheKey);

        ThreadUtil.execAsync(() -> {
            var raw:String = "";

            if (!Path.isAbsolute(cacheKey) && Assets.exists(cacheKey))
                raw = Assets.getText(cacheKey);
            else if (FileSystem.exists(realPath))
                raw = File.getContent(realPath);

            MainLoop.runInMainThread(() -> {
                if (onComplete != null) onComplete(raw);
            });
        });
    }
}