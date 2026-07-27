package backend.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

class ConverterMacro
{
    public static function build():Array<Field>
    {
        var fields:Array<Field> = Context.getBuildFields();
        var cls = Context.getLocalClass().get();
        var pos:Position = Context.currentPos();

        var defined = new Map<String, Bool>();

        for (field in fields)
            defined.set(field.name, true);

        var path:TypePath = {pack: cls.pack, name: cls.name};
        var type:ComplexType = TPath(path);
        var create:Expr = {expr: ENew(path, []), pos: pos};

        if (!defined.exists("_instance"))
        {
            fields.push(
            {
                name: "_instance",
                access: [APrivate, AStatic],
                kind: FVar(type, null),
                pos: pos
            });
        }

        if (!defined.exists("get_instance"))
        {
            fields.push(
            {
                name: "get_instance",
                access: [APrivate, AStatic],
                kind: FFun(
                {
                    args: [],
                    ret: type,
                    expr: macro
                    {
                        if (_instance == null)
                            _instance = $create;

                        return _instance;
                    }
                }),
                pos: pos
            });
        }

        if (!defined.exists("instance"))
        {
            fields.push(
            {
                name: "instance",
                access: [APublic, AStatic],
                kind: FProp("get", "never", type, null),
                pos: pos
            });
        }

        if (!defined.exists("song"))
        {
            fields.push(
            {
                name: "song",
                access: [APublic],
                kind: FVar(macro : String, macro ""),
                pos: pos
            });
        }

        if (!defined.exists("difficulty"))
        {
            fields.push(
            {
                name: "difficulty",
                access: [APublic],
                kind: FVar(macro : String, macro null),
                pos: pos
            });
        }

        if (!defined.exists("new"))
        {
            fields.push(
            {
                name: "new",
                access: [APublic],
                kind: FFun({args: [], ret: null, expr: macro {}}),
                pos: pos
            });
        }

        // using temporary writer until i make my own for every format
        if (!defined.exists("write"))
        {
            fields.push(
            {
                name: "write",
                access: [APublic],
                kind: FFun(
                {
                    args: [{name: "data", type: (macro:Dynamic)}],
                    ret: (macro:String),
                    expr: macro return haxe.Json.stringify(data, null, "\t")
                }),
                pos: pos
            });
        }

        return fields;
    }
}
#end
