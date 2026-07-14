package menus;

import backend.assets.FunkinSprite;

import backend.MusicBeatState;

import flixel.text.FlxText;
import backend.ui.Button;

class CreditsState extends MusicBeatState
{
    var title:FlxText;

    override public function create()
    {
        add(new FunkinSprite().makeGraphic(camera.width, camera.height, 0xFF595959));

        title = new FlxText(0, 0, 0, "RevEngine Credits Menu", 30, true);
        title.screenCenter();
        title.y -= 100;
        add(title);

        var button:Button = new Button({position: [0, 0], size: [100, 50], text: "BACK", callback: () -> Manager.switchState(new MainMenuState())});
        button.screenCenter();
        button.y += 100;
        add(button);

        super.create();
    }
}