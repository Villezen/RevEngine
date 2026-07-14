package backend.display;

import flixel.system.ui.FlxSoundTray;

import openfl.display.Bitmap;
import openfl.media.Sound;
import openfl.utils.Assets;

import backend.utils.MathUtil;

class SOUNDTRAY extends FlxSoundTray
{
  var graphicScale:Float = 0.30;
  var lerpYPos:Float = 0;
  var alphaTarget:Float = 0;

  var volumeMaxSound:Sound;

  public function new()
  {
    super();
    removeChildren();

    var bg:Bitmap = new Bitmap(Assets.getBitmapData(Paths.image("engine/soundtray/volumebox", "images", "png", false, true)));
    bg.scaleX = graphicScale;
    bg.scaleY = graphicScale;
    bg.smoothing = true;
    addChild(bg);

    y = -height;
    visible = false;

    var backingBar:Bitmap = new Bitmap(Assets.getBitmapData(Paths.image("engine/soundtray/bars_10", "images", "png", false, true)));
    backingBar.x = 9;
    backingBar.y = 5;
    backingBar.scaleX = graphicScale;
    backingBar.scaleY = graphicScale;
    backingBar.smoothing = true;
    addChild(backingBar);
    backingBar.alpha = 0.4;

    _bars = [];

    for (i in 1...11)
    {
      var bar:Bitmap = new Bitmap(Assets.getBitmapData(Paths.image("engine/soundtray/bars_" + i, "images", "png", false, true)));
      bar.x = 9;
      bar.y = 5;
      bar.scaleX = graphicScale;
      bar.scaleY = graphicScale;
      bar.smoothing = true;
      addChild(bar);
      _bars.push(bar);
    }

    screenCenter();
    y = -height - 10;

    volumeUpSound = Paths.sound("engine/soundtray/volUP", "ogg", false, true);
    volumeDownSound = Paths.sound("engine/soundtray/volDOWN", "ogg", false, true);
    volumeMaxSound = Paths.sound("engine/soundtray/volMAX", "ogg", false, true);
  }

  override public function update(ms:Float):Void
  {
    var elapsed = ms / 1000.0;

    var hasVolume:Bool = (!FlxG.sound.muted && FlxG.sound.volume > 0);

    if (hasVolume)
    {
      if (_timer > 0)
      {
        _timer -= elapsed;
        if (_timer <= 0)
        {
          lerpYPos = -height - 10;
          alphaTarget = 0;
        }
      }
      else if (y <= -height)
      {
        visible = false;
        active = false;
      }
    }
    else if (!visible)
    {
      showTray();
    }

    y = MathUtil.smoothLerpPrecision(y, lerpYPos, elapsed, 0.768);
    alpha = MathUtil.smoothLerpPrecision(alpha, alphaTarget, elapsed, 0.307);
    screenCenter();
  }

  override function showIncrement():Void
  {
    moveTrayMakeVisible(true);
    saveVolumePreferences();
  }

  override function showDecrement():Void
  {
    moveTrayMakeVisible(false);
    saveVolumePreferences();
  }

  function moveTrayMakeVisible(up:Bool = false):Void
  {
    showTray();

    if (!silent)
    {
        var sound:Sound = FlxG.sound.volume == 1 ? volumeMaxSound : (up ? cast volumeUpSound : cast volumeDownSound);
        if (sound != null) FlxG.sound.play(sound);
    }
  }

  function showTray():Void
  {
    _timer = 1;
    lerpYPos = 10;
    visible = true;
    active = true;
    alphaTarget = 1;

    updateBars();
  }

  function updateBars():Void
  {
    var globalVolume:Int = FlxG.sound.muted || FlxG.sound.volume == 0 ? 0 : Math.round(FlxG.sound.logToLinear(FlxG.sound.volume) * 10);

    for (i in 0..._bars.length) _bars[i].visible = i < globalVolume;
  }

  function saveVolumePreferences():Void
  {
    #if FLX_SAVE
    if (FlxG.save.isBound)
    {
      FlxG.save.data.mute = FlxG.sound.muted;
      FlxG.save.data.volume = FlxG.sound.volume;
      FlxG.save.flush();
    }
    #end
  }
}
