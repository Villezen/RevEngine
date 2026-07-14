package game.ui;

import backend.assets.FunkinSprite;
import flixel.util.FlxColor;
import flixel.ui.FlxBar;
import flixel.group.FlxSpriteGroup;

import game.world.Character;

import backend.utils.MathUtil;

typedef HealthBarParams =
{
    /**
     * Parent Class.
     */
    var parent:Dynamic; 

    /**
     * What value the health bar should follow.
     */
    var parentVar:String;

    /**
     * Which characters will have their data used for the health bar?
     */
    var characters:Array<Character>;
}

/**
 * Visual graphic used to display the player's current health.
 */
class HealthBar extends FlxSpriteGroup
{
    /**
     * The charcters that will have their color and icon used for the health bar.
     */
    public var characters:Array<Character> = [];

    /**
     * The sprite used to decorate the bar.
     */
    public var sprite:FunkinSprite;

    /**
     * The bar displaying the amount of health you have.
     */
    public var bar:FlxBar;

    /**
     * The health icon for the opponent.
     */
    public var leftIcon:HealthIcon;

    /**
     * The health icon for the player.
     */
    public var rightIcon:HealthIcon;

    /**
     * The distance of the health icons for the icon bopping.
     */
    private var iconScaleDist:Array<Float> = [0.0, 0.0];
    
    /**
     * The current angling of the health icons for the icon bopping.
     */
    private var iconAngleDist:Array<Float> = [0.0, 0.0];

    /**
     * Creates a new health bar sprite.
     * @param x The x position of the bar.
     * @param y The y position of the bar.
     * @param params The parameters of the health bar.
     */
    public function new(x:Float, y:Float, params:HealthBarParams)
    {
        super(x, y);

        characters = params.characters;

        sprite = new FunkinSprite().loadGraphic(Paths.image("game/ui/healthBar"));
        add(sprite);

        bar = new FlxBar(0, 0, RIGHT_TO_LEFT, Std.int(sprite.width - 8), Std.int(sprite.height - 8), params.parent, params.parentVar, Constants.MIN_HEALTH, Constants.MAX_HEALTH);
        bar.numDivisions = 800;
        bar.setPosition(sprite.x + 4, sprite.y + 4);
        add(bar);

        changeColor(characters[0]?.hpColor ?? 0xFFA1A1A1, characters[1]?.hpColor ?? 0xFFA1A1A1);

        leftIcon = new HealthIcon({character: characters[0], type: LEFT, bar: this.bar});
        leftIcon.updateHitbox();

        rightIcon = new HealthIcon({character: characters[1], type: RIGHT, bar: this.bar});
        rightIcon.updateHitbox();
        rightIcon.flipX = true;

        for (icon in [leftIcon, rightIcon])
        {
            add(icon);
        }
    } 

    /**
     * Called every beat. Used to handle the icon bounce.
     * @param beat The current beat index.
     */
    public function bounce(beat:Float)
    {
        for (icon in [leftIcon, rightIcon])
        {
            icon.bounce();
        }
    }
    
    /**
     * Change the coloring of the health bars to whatever you desire thru HEX colors, FlxColor's preset colors, etc.
     * @param leftColor   Color of the left side of the health bar.     (DEFAULT: FlxColor.RED)
     * @param rightColor  Color of the right side of the health bar.    (DEFAULT: FlxColor.LIME)
     * @param gradient Makes the health bar's colors have a gradient fade out at the sides, if set to false the bar will just be two solid colors.
     */
    public function changeColor(?leftColor:FlxColor = FlxColor.RED, ?rightColor:FlxColor = FlxColor.LIME)
    {   
        bar.createFilledBar(leftColor, rightColor);
    }
}