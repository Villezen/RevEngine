package backend.assets;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxBitmapFont;

import animate.FlxAnimateFrames;
import animate.FlxAnimateFrames.FlxAnimateSettings;

import openfl.display.BitmapData;
import openfl.display3D.textures.Texture;
import openfl.media.Sound;
import openfl.text.Font;
import openfl.utils.Assets;
import openfl.net.URLRequest;

#if lime
import lime.media.AudioBuffer;
#if lime_vorbis
import lime.media.vorbis.VorbisFile;
#end
#end

import backend.assets.Cacher.RevAssets;

class Paths
{
    public static function getPath(cacheKey:String):String
    {
        if (Path.isAbsolute(cacheKey)) return cacheKey;

        #if sys
        if (Assets.exists(cacheKey))
        {
            var truePath = Assets.getPath(cacheKey);

            if (truePath != null && truePath != "" && FileSystem.exists(truePath))
                return truePath;
        }
        #end

        return cacheKey;
    }

    public static function image(file:String, ?folder:String = "images", ?extension:String = "png", ?absolute:Bool = false, ?permanent:Bool = false):String
    {
        if (file == null || file == "")
        {
            trace('Invalid image requested! | Deploying coconut.', "WARNING");
            return Assets.exists('fallback/image.png') ? 'fallback/image.png' : null;
        }

        var ext = extension != "" ? '.$extension' : "";
        var cacheKey = absolute ? '$file$ext' : 'assets/$folder/$file$ext';
        cacheKey = findCachedGraphicKey(cacheKey);

        var existing = FlxG.bitmap.get(cacheKey);

        if (existing != null && Cacher.instance.refreshStaleGraphic(cacheKey))
            existing = null;

        if (existing != null)
        {
            Cacher.instance.registerGraphic(existing, permanent);
            return cacheKey;
        }

        var realPath = getPath(cacheKey);
        var bmp:BitmapData = null;

        if (FileSystem.exists(realPath))
            bmp = BitmapData.fromFile(realPath);
        else if (!Path.isAbsolute(cacheKey) && Assets.exists(cacheKey))
            bmp = Assets.getBitmapData(cacheKey, false);

        if (bmp != null)
        {
            bmp = toTexture(bmp);

            var graphic = FlxGraphic.fromBitmapData(bmp, false, cacheKey);
            graphic.persist = true;
            FlxG.bitmap.addGraphic(graphic);

            Cacher.instance.registerGraphic(graphic, permanent);
            Cacher.instance.stampFile(cacheKey, realPath);

            return cacheKey;
        }

        trace('Image not found: $cacheKey | Deploying coconut.', "WARNING");
        return Assets.exists('fallback/image.png') ? 'fallback/image.png' : null;
    }

    public static function bitmapData(file:String, ?folder:String = "images", ?extension:String = "png", ?absolute:Bool = false, ?permanent:Bool = false):BitmapData
    {
        if (file == null || file == "")
            return null;

        var ext = extension != "" ? '.$extension' : "";
        var cacheKey = absolute ? '$file$ext' : 'assets/$folder/$file$ext';

        var rev = ensureAssets();

        if (rev.hasBitmapData(cacheKey))
        {
            if (permanent) Cacher.instance.markPermanent(cacheKey);
            return rev.getBitmapData(cacheKey);
        }

        var realPath = getPath(cacheKey);
        var bmp:BitmapData = null;

        if (FileSystem.exists(realPath))
            bmp = BitmapData.fromFile(realPath);
        else if (!Path.isAbsolute(cacheKey) && Assets.exists(cacheKey))
            bmp = Assets.getBitmapData(cacheKey, false);

        if (bmp != null)
        {
            rev.setBitmapData(cacheKey, bmp);
            Cacher.instance.stampFile(cacheKey, realPath);

            if (permanent) Cacher.instance.markPermanent(cacheKey);

            return bmp;
        }

        trace('BitmapData not found: $cacheKey | Deploying coconut.', "WARNING");
        return null;
    }

    public static function audio(file:String, ?folder:String = "audio", ?extension:String = "ogg", ?absolute:Bool = false, ?permanent:Bool = false, ?stream:Bool = false):Sound
    {
        if (file == null || file == "")
        {
            trace('Invalid audio requested! | Someone is calling.', "WARNING");
            return Assets.exists('fallback/sound.ogg') ? Assets.getSound('fallback/sound.ogg', true) : null;
        }

        var ext = extension != "" ? '.$extension' : "";
        var cacheKey = absolute ? '$file$ext' : 'assets/$folder/$file$ext';

        var cached = findCachedSound(cacheKey);
        if (cached != null)
        {
            if (permanent)
                Cacher.instance.markPermanent(cached.url != null ? cached.url : cacheKey);

            return cached;
        }

        var realPath = getPath(cacheKey);
        var snd:Sound = null;

        if (FileSystem.exists(realPath))
        {
            if (stream)
            {
                snd = streamedSound(realPath);

                if (snd != null)
                {
                    Cacher.instance.registerStream(snd, permanent);
                    return snd;
                }
            }

            snd = Sound.fromFile(realPath);

            if (snd != null)
            {
                ensureAssets().setSound(cacheKey, snd);
                Cacher.instance.stampFile(cacheKey, realPath);
            }
        }
        else if (!Path.isAbsolute(cacheKey) && Assets.exists(cacheKey))
            snd = Assets.getSound(cacheKey, true);

        if (snd != null)
        {
            if (permanent)
                Cacher.instance.markPermanent(cacheKey);

            return snd;
        }

        trace('Audio not found: $cacheKey | Someone is calling.', "WARNING");
        return Assets.exists('fallback/sound.ogg') ? Assets.getSound('fallback/sound.ogg', true) : null;
    }

    static function streamedSound(realPath:String):Sound
    {
        #if (lime && lime_vorbis)
        if (realPath != null && realPath.toLowerCase().endsWith(".ogg"))
        {
            var vorbis = VorbisFile.fromFile(realPath);

            if (vorbis != null)
            {
                var buffer = AudioBuffer.fromVorbisFile(vorbis);

                if (buffer != null)
                    return Sound.fromAudioBuffer(buffer);
            }
        }
        #end

        return null;
    }

    public static function data(file:String, ?folder:String = "data", ?absolute:Bool = false, ?bypassCache:Bool = false):String
    {
        var cacheKey = absolute ? file : 'assets/$folder/$file';

        if (!bypassCache && !Path.isAbsolute(cacheKey) && Assets.exists(cacheKey))
            return Assets.getText(cacheKey);

        var realPath = getPath(cacheKey);

        if (FileSystem.exists(realPath))
            return File.getContent(realPath);

        trace('Data not found: $cacheKey', "WARNING");
        return "";
    }

    public static function font(file:String, ?absolute:Bool = false, ?permanent:Bool = false):String
    {
        if (file == null || file == "")
        {
            trace('Invalid font requested! | Utilizing fallback font.', "WARNING");
            return Assets.exists('assets/fonts/vcr.ttf') ? 'assets/fonts/vcr.ttf' : "";
        }

        var cacheKey = absolute ? file : 'assets/fonts/$file';
        var realPath = getPath(cacheKey);

        if (Assets.cache.hasFont(cacheKey))
        {
            if (Cacher.instance.isFileStale(cacheKey))
            {
                trace('Cached font "$cacheKey" changed on disk, refreshing...', "CACHE");
                Cacher.instance.evictFont(cacheKey);
            }
            else
            {
                return cacheKey;
            }
        }

        var fnt:Font = null;

        if (FileSystem.exists(realPath))
        {
            fnt = Font.fromFile(realPath);

            if (fnt != null)
            {
                Assets.cache.setFont(cacheKey, fnt);
                Cacher.instance.stampFile(cacheKey, realPath);
            }
        }
        else if (!Path.isAbsolute(cacheKey) && Assets.exists(cacheKey))
            fnt = Assets.getFont(cacheKey, true);

        if (fnt != null)
        {
            Font.registerFont(fnt);
            return cacheKey;
        }

        trace('Font not found: $cacheKey | Utilizing fallback font.', "WARNING");
        return Assets.exists('assets/fonts/vcr.ttf') ? 'assets/fonts/vcr.ttf' : "";
    }

    public static function sound(file:String, ?extension:String = "ogg", ?absolute:Bool = false, ?permanent:Bool = false):Sound
    {
        return audio(file, 'audio/sounds', extension, absolute, permanent, false);
    }

    public static function music(file:String, ?extension:String = "ogg", ?absolute:Bool = false, ?permanent:Bool = false):Sound
    {
        return audio(file, 'audio/music', extension, absolute, permanent, true);
    }

    public static function songTrackKey(song:String, track:String):String
    {
        return 'assets/songs/$song/$track.ogg';
    }

    public static function ensureAssets():RevAssets
    {
        return RevAssets.ensureActive();
    }

    public static function getAngelFont(folder:String):FlxBitmapFont
    {
        return FlxBitmapFont.fromAngelCode(image('font', 'fonts/$folder'), data('font.fnt', 'fonts/$folder'));
    }

    public static function frag(file:String):String
    {
        return data('$file.frag', 'shaders');
    }

    public static function vert(file:String):String
    {
        return data('$file.vert', 'shaders');
    }

    public static function getSparrowAtlas(file:String, ?folder:String = "images", ?absolute:Bool = false, ?permanent:Bool = false):FlxAtlasFrames
    {
        var graphicPath = image(file, folder, "png", absolute, permanent);

        if (graphicPath == null)
        {
            trace('Failed to load Sparrow Atlas for: $file', "WARNING");
            return null;
        }

        var graphic = FlxG.bitmap.get(graphicPath);
        if (graphic != null)
        {
            var cached = FlxAtlasFrames.findFrame(graphic);
            if (cached != null)
                return cached;
        }

        var xmlData = data('${file}.xml', folder, absolute);

        if (xmlData == null || xmlData == "")
        {
            trace('Failed to load Sparrow Atlas for: $file', "WARNING");
            return null;
        }

        return FlxAtlasFrames.fromSparrow(graphicPath, xmlData);
    }

    public inline static function atlas(key:String, ?parent:String, ?absolute:Bool = false):String
    {
        var graphicPath = image(key + '/spritemap1', parent, "png", absolute);
        if (graphicPath == null || graphicPath == "") return null;

        return Path.directory(graphicPath);
    }

    public inline static function getAnimateAtlas(key:String, ?parent:String, ?settings:FlxAnimateSettings, ?absolute:Bool = false):FlxAnimateFrames
    {
        var atlasDir = Paths.atlas(key, parent, absolute);

        if (atlasDir == null) return null;

        return FlxAnimateFrames.fromAnimate(atlasDir, null, null, null, false, settings);
    }

    public static function createDirectory(path:String):Void
    {
        if (!FileSystem.isDirectory(path))
            FileSystem.createDirectory(path);
    }

    public static function isDirectory(path:String, ?absolute:Bool = false):Bool
    {
        var targetPath = absolute ? path : 'assets/$path';

        #if sys
        var pathsToCheck = [targetPath];
        var resolvedPath = getPath(targetPath);

        if (resolvedPath != null && resolvedPath != "" && resolvedPath != targetPath)
            pathsToCheck.push(resolvedPath);

        for (p in pathsToCheck)
        {
            if (FileSystem.exists(p) && FileSystem.isDirectory(p))
                return true;
        }
        #end

        var searchPath = targetPath + "/";

        for (asset in Assets.list())
        {
            if (asset.startsWith(searchPath))
                return true;
        }

        return false;
    }

    public static function readDirectory(path:String, ?absolute:Bool = false):Array<String>
    {
        var files:Array<String> = [];
        var targetPath = absolute ? path : 'assets/$path';

        if (FileSystem.exists(targetPath) && FileSystem.isDirectory(targetPath))
        {
            for (file in FileSystem.readDirectory(targetPath))
            {
                if (!files.contains(file)) files.push(file);
            }
        }

        if (Path.isAbsolute(targetPath)) return files;

        for (asset in Assets.list())
        {
            if (asset.startsWith(targetPath + "/"))
            {
                var remainder = asset.substring(targetPath.length + 1);
                var topLevel = remainder.split('/')[0];

                if (!files.contains(topLevel))
                    files.push(topLevel);
            }
        }

        return files;
    }

    public static function readDirectoryRecursive(path:String, ?absolute:Bool = false):Array<String>
    {
        var fileList:Array<String> = [];
        var targetPath = absolute ? path : 'assets/$path';

        function recurse(currentPath:String):Void
        {
            if (!FileSystem.exists(currentPath) || !FileSystem.isDirectory(currentPath)) return;
            
            for (file in FileSystem.readDirectory(currentPath))
            {
                var fullPath:String = currentPath + '/' + file;
                if (FileSystem.isDirectory(fullPath))
                    recurse(fullPath);
                else
                {
                    var relativePath:String = fullPath.replace(targetPath + '/', "");

                    if (!fileList.contains(relativePath))
                        fileList.push(relativePath);
                }
            }
        }

        recurse(targetPath);

        for (asset in Assets.list())
        {
            if (asset.startsWith(targetPath + "/"))
            {
                var relativePath = asset.substring(targetPath.length + 1);
                if (!fileList.contains(relativePath)) fileList.push(relativePath);
            }
        }

        return fileList;
    }

    public static function exists(path:String, ?absolute:Bool = false):Bool
    {
        var cacheKey = absolute ? path : 'assets/$path';
        var realPath = getPath(cacheKey);

        if (FileSystem.exists(realPath)) return true;
        if (!Path.isAbsolute(cacheKey) && Assets.exists(cacheKey)) return true;

        return false;
    }

    public static function toTexture(bmp:BitmapData):BitmapData
    {
        if (bmp == null || FlxG.stage.context3D == null) return bmp;

        var tex:Texture = FlxG.stage.context3D.createTexture(bmp.width, bmp.height, BGRA, false);
        tex.uploadFromBitmapData(bmp);

        bmp.dispose();
        bmp.disposeImage();

        return BitmapData.fromTexture(tex);
    }

    @:access(flixel.system.frontEnds.BitmapFrontEnd)
    public static function findCachedGraphicKey(targetKey:String):String
    {
        if (targetKey == null || FlxG.bitmap.checkCache(targetKey))
            return targetKey;

        var target = targetKey.toLowerCase();

        if (FlxG.bitmap._cache != null)
        {
            for (key in FlxG.bitmap._cache.keys())
            {
                if (key != null && key.toLowerCase() == target)
                    return key;
            }
        }

        return targetKey;
    }

    public static function findCachedSound(cacheKey:String):Sound
    {
        if (cacheKey == null) return null;

        var rev = ensureAssets();
        var snd = rev.promoteSoundLoose(cacheKey);

        if (snd != null)
        {
            var id = snd.url != null ? snd.url : cacheKey;

            if (Cacher.instance.isFileStale(id))
            {
                trace('Cached sound "$id" changed on disk, refreshing...', "CACHE");
                Cacher.instance.evictSound(id);
                return null;
            }

            return snd;
        }

        if (Cacher.instance != null && Cacher.instance.activeStreams != null)
        {
            var target = cacheKey.toLowerCase();
            var realTarget = getPath(cacheKey).toLowerCase();

            for (stream in Cacher.instance.activeStreams)
            {
                @:privateAccess
                if (stream != null && stream.url != null)
                {
                    var streamUrl = stream.url.toLowerCase();
                    
                    if (streamUrl == target || streamUrl == realTarget)
                        return stream;
                }
            }
        }

        return null;
    }
}
