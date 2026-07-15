package menus.freeplay;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

import backend.registries.song.AlbumRegistry;
import backend.registries.song.AlbumRegistry.AlbumData;
import backend.registries.song.AlbumRegistry.AlbumObjectData;

class AlbumRoll extends FlxTypedSpriteGroup<FunkinSprite>
{
    static inline final ART_X:Float = 658;
    static inline final ART_Y:Float = 370;
    static inline final TITLE_X:Float = 355;
    static inline final TITLE_Y:Float = 500;

    public var albumId(default, set):String = null;

    var albumArt:FunkinSprite;
    var albumTitle:FunkinSprite;

    var albumData:AlbumData = null;

    var titleTimer:FlxTimer = null;

    public function new()
    {
        super();

        albumArt = new FunkinSprite(FlxG.width - ART_X, ART_Y);
        albumArt.visible = false;
        add(albumArt);

        albumTitle = new FunkinSprite(FlxG.width - TITLE_X, TITLE_Y);
        albumTitle.visible = false;
        add(albumTitle);

        visible = false;
    }

    function set_albumId(value:String):String
    {
        if (albumId != value || value == null)
        {
            albumId = value;
            updateAlbum();
        }

        return value;
    }

    function updateAlbum():Void
    {
        if (albumId == null || albumId == "" || albumId == "unknown")
        {
            visible = false;
            albumData = null;
            return;
        }

        visible = true;
        albumData = AlbumRegistry.get(albumId);

        if (albumData == null || albumData.sprites == null) return;

        applyObject(albumArt, albumData.sprites.art, FlxG.width - ART_X, ART_Y);
        applyObject(albumTitle, albumData.sprites.text, FlxG.width - TITLE_X, TITLE_Y);

        albumArt.playAnim("idle");
        albumTitle.playAnim("idle");
    }

    function applyObject(spr:FunkinSprite, data:AlbumObjectData, baseX:Float, baseY:Float):Void
    {
        if (data == null || data.path == null || data.path == "") return;

        spr.loadSprite(data.path);

        spr.x = baseX + data.position[0];
        spr.y = baseY + data.position[1];
        spr.scale.set(data.scale[0], data.scale[1]);
        spr.alpha = data.alpha;
        spr.angle = data.angle;

        if (data.animations != null)
        {
            for (anim in data.animations)
            {
                if (anim == null) continue;

                spr.addAnim(anim.name, {
                    prefix: anim.prefix,
                    indices: anim.indices,
                    offsets: anim.offsets,
                    looped: anim.looped,
                    fps: anim.fps
                });
            }
        }
    }

    public function playIntro():Void
    {
        if (albumData == null)
        {
            visible = false;
            return;
        }

        visible = true;

        albumTitle.visible = false;
        albumArt.visible = true;
        playArtAnim("intro");

        if (titleTimer != null) titleTimer.cancel();

        titleTimer = FlxTimer.wait(0.75, function()
        {
            albumTitle.visible = true;
            playTitleSwitch();
        });
    }

    public function skipIntro():Void
    {
        if (albumData == null)
        {
            visible = false;
            return;
        }

        visible = true;

        albumArt.visible = true;
        albumTitle.visible = true;

        playArtAnim("switch");
        playTitleSwitch();
    }

    function playArtAnim(name:String):Void
    {
        albumArt.playAnim(name, {
            force: true,
            onComplete: function() albumArt.playAnim("idle")
        });
    }

    function playTitleSwitch():Void
    {
        albumTitle.playAnim("switch", {
            force: true,
            onComplete: function() albumTitle.playAnim("idle")
        });
    }

    override function destroy():Void
    {
        if (titleTimer != null)
        {
            titleTimer.cancel();
            titleTimer = null;
        }

        super.destroy();
    }
}
