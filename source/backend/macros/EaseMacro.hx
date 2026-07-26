package backend.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

class EaseMacro
{
    static final EASES:Array<String> =
    [
        "linear",
        "quadIn", "quadOut", "quadInOut",
        "cubeIn", "cubeOut", "cubeInOut",
        "quartIn", "quartOut", "quartInOut",
        "quintIn", "quintOut", "quintInOut",
        "smoothStepIn", "smoothStepOut", "smoothStepInOut",
        "smootherStepIn", "smootherStepOut", "smootherStepInOut",
        "sineIn", "sineOut", "sineInOut",
        "bounceIn", "bounceOut", "bounceInOut",
        "circIn", "circOut", "circInOut",
        "expoIn", "expoOut", "expoInOut",
        "backIn", "backOut", "backInOut",
        "elasticIn", "elasticOut", "elasticInOut"
    ];

    public static function build():Array<Field>
    {
        var fields:Array<Field> = Context.getBuildFields();
        var pos:Position = Context.currentPos();

        var setters:Array<Expr> = [];

        for (name in EASES)
            setters.push(macro result.set($v{name}, $p{["flixel", "tweens", "FlxEase", name]}));

        fields.push(
        {
            name: "map",
            access: [APublic, AStatic],
            kind: FVar(macro : Map<String, Float->Float>, macro
            {
                var result = new Map<String, Float->Float>();
                $b{setters};
                result;
            }),
            pos: pos
        });

        return fields;
    }
}
#end
