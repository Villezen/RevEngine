package backend.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

class ConfigMacro
{
    public static function build():Array<Field>
    {
        var fields:Array<Field> = Context.getBuildFields();
        var pos:Position = Context.currentPos();

        var loadExprs:Array<Expr> = [];
        var saveExprs:Array<Expr> = [];

        for (field in fields)
        {
            if (field.access == null || !field.access.contains(AStatic) || !field.access.contains(APublic))
                continue;

            switch (field.kind)
            {
                case FVar(_, _):
                default: continue;
            }

            if (hasMeta(field, ':noSave'))
                continue;

            var name:String = field.name;

            loadExprs.push(macro if (configSave.data.$name != null) $i{name} = configSave.data.$name);
            saveExprs.push(macro configSave.data.$name = $i{name});
        }

        fields.push(
        {
            name: '_load',
            access: [APrivate, AStatic],
            kind: FFun({args: [], ret: (macro:Void), expr: macro $b{loadExprs}}),
            pos: pos
        });

        fields.push(
        {
            name: '_save',
            access: [APrivate, AStatic],
            kind: FFun({args: [], ret: (macro:Void), expr: macro $b{saveExprs}}),
            pos: pos
        });

        return fields;
    }

    static function hasMeta(field:Field, name:String):Bool
    {
        if (field.meta == null)
            return false;

        for (entry in field.meta)
        {
            if (entry.name == name)
                return true;
        }

        return false;
    }
}
#end
