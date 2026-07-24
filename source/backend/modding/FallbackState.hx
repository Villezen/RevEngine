package backend.modding;

import backend.MusicBeatState;
import flixel.text.FlxText;

class FallbackState extends MusicBeatState
{
    override public function create()
    {
        var spr:FunkinSprite = new FunkinSprite().loadGraphic('fallback/sad.png');
        spr.scale.set(0.2, 0.2);
        spr.updateHitbox();
        spr.screenCenter();
        spr.y -= 20;
        add(spr);

        var text:FlxText = new FlxText(0, 0, FlxG.width, '0 0 0 F 5 F 4 0\nF A L L B A C K');
        text.setFormat(Paths.font('chicago.ttf'), 50, 0xFFFFFFFF, CENTER);
        text.scale.set(0.5, 0.5);
        text.updateHitbox();
        text.antialiasing = false;
        text.screenCenter();
        text.y += 40;
        text.letterSpacing = 3;
        add(text);
    }
}