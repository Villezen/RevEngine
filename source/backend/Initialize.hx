package backend;

import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.util.typeLimit.NextState;

import openfl.utils.Assets;

import lime.app.Application;

import backend.utils.WindowUtil;
import backend.utils.MemoryUtil;

import cpp.vm.Gc;

import backend.modding.PolymodManager;

import backend.modding.ModState;
import backend.modding.ModSubState;

import backend.assets.Cacher;
import backend.assets.Cacher.RevAssets;
import backend.assets.Paths;

import backend.frontends.FrontEndHandler;

import backend.registries.menus.*;
import backend.registries.misc.*;
import backend.registries.song.*;
import backend.registries.ui.*;
import backend.registries.world.*;

/**
 * A state used to load any configurations before transitioning to the first initial state.
 */
class Initialize extends FlxState
{
    /**
     * What state to transition to after everything's ready.
     */
    private static var firstState:NextState = new menus.TitleState();

    public override function create():Void
    {
        super.create();

        Assets.cache = RevAssets.instance;
        Paths.ensureRevAssets();

        Cacher.init();

        FrontEndHandler.init();
        AnsiLogger.init();

        PolymodManager.setup();
        
        Configs.load();

        setup_game();
        start_game();
    }

    /**
     * Configures global engine behaviours.
     */
    function setup_game()
    {
        #if cpp
        Gc.setTargetFreeSpacePercentage(10);
        #end

        MemoryUtil.startPeriodicCleaning();

        FlxG.fixedTimestep = false;
        FlxG.game.focusLostFramerate = 10;
        FlxG.mouse.useSystemCursor = true;

        FlxGraphic.defaultPersist = false;

        FlxSprite.defaultAntialiasing = true;

        FlxG.signals.preStateSwitch.add(function()
        {
            Configs.save();
        });

        FlxG.signals.preStateCreate.add(function(state:FlxState)
        {   
            WindowUtil.initSignals();
        });

        CharacterRegistry.init();
        StageRegistry.init();
        NoteSkinRegistry.init();
        ChartRegistry.init();
        MetaRegistry.init();
        DifficultyRegistry.init();
        EventRegistry.init();
        HealthIconRegistry.init();
        CountdownRegistry.init();
        RatingsRegistry.init();
        DialogueRegistry.init();
        EventObjectRegistry.init();
        AlbumRegistry.init();

        ConfigRegistry.load();
        ConfigRegistry.execute();

        TitleMenuRegistry.load();
        MainMenuRegistry.load();
        FreeplayRegistry.load();
    }

    /**
     * Finalizes everything by switching the game to the defined `firstState`.
     */
    function start_game()
    {
        Manager.switchState(firstState);
    }
}