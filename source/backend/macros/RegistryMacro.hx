package backend.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class RegistryMacro
{
    public static function build():Array<Field>
    {
        var fields:Array<Field> = Context.getBuildFields();
        var pos:Position = Context.currentPos();
        var cls = Context.getLocalClass().get();

        var folder:String = getFolder(cls.meta.get());
        if (folder == null)
        {
            Context.error('A registry built with this macro needs a folder tag.', pos);
            return fields;
        }

        var dataType:ComplexType = getListType(fields);
        if (dataType == null)
        {
            Context.error('A registry built with this macro needs a list field.', pos);
            return fields;
        }

        var defined = new Map<String, Bool>();

        for (field in fields)
            defined.set(field.name, true);

        if (!defined.exists("parser"))
        {
            fields.push(
            {
                name: "parser",
                access: [APrivate, AStatic],
                kind: FVar(TPath({pack: ["json2object"], name: "JsonParser", params: [TPType(dataType)]}), {expr: ENew({pack: ["json2object"], name: "JsonParser", params: [TPType(dataType)]}, []), pos: pos}),
                pos: pos
            });
        }

        if (!defined.exists("init"))
        {
            var initExprs:Array<Expr> = [];

            if (Context.defined("sys"))
            {
                initExprs.push(macro
                {
                    if (Paths.exists($v{folder}))
                    {
                        for (file in Paths.readDirectory($v{folder}))
                        {
                            if (haxe.io.Path.extension(file) == "json")
                                reload(haxe.io.Path.withoutExtension(file));
                        }
                    }
                });
            }

            fields.push(
            {
                name: "init",
                access: [APublic, AStatic],
                kind: FFun({args: [], ret: (macro:Void), expr: macro $b{initExprs}}),
                pos: pos
            });
        }

        if (!defined.exists("get"))
        {
            fields.push(
            {
                name: "get",
                access: [APublic, AStatic],
                kind: FFun(
                {
                    args: [{name: "name", type: (macro:String)}],
                    ret: dataType,
                    expr: macro
                    {
                        if (!list.exists(name))
                            reload(name);

                        return list.get(name);
                    }
                }),
                pos: pos
            });
        }

        if (!defined.exists("reload"))
        {
            var reloadExprs:Array<Expr> = [];

            reloadExprs.push(macro var rawData:String = "{}");
            reloadExprs.push(macro var path:String = $v{folder} + "/" + name + ".json");

            if (Context.defined("sys"))
            {
                reloadExprs.push(macro
                {
                    if (Paths.exists(path))
                        rawData = Paths.data(name + ".json", $v{folder});
                });
            }

            reloadExprs.push(macro parser.fromJson(rawData, path));
            reloadExprs.push(macro backend.utils.RegistryUtil.reportErrors(path, parser.errors));

            reloadExprs.push(macro var value = applyDefaults(name, parser.value));

            if (defined.exists("validate"))
                reloadExprs.push(macro value = validate(name, value));

            reloadExprs.push(macro list.set(name, value));

            fields.push(
            {
                name: "reload",
                access: [APublic, AStatic],
                kind: FFun(
                {
                    args: [{name: "name", type: (macro:String)}],
                    ret: (macro:Void),
                    expr: macro $b{reloadExprs}
                }),
                pos: pos
            });
        }

        if (!defined.exists("reloadAll"))
        {
            fields.push(
            {
                name: "reloadAll",
                access: [APublic, AStatic],
                kind: FFun({
                    args: [],
                    ret: (macro:Void),
                    expr: macro
                    {
                        list.clear();
                        init();
                    }
                }),
                pos: pos
            });
        }

        if (!defined.exists("applyDefaults"))
        {
            var body:Array<Expr> = [macro if (data == null) data = {}];

            switch (resolve(Context.resolveType(dataType, pos)))
            {
                case TAnonymous(anon): body = body.concat(genObject(macro data, anon.get().fields, 0));
                default:
            }

            body.push(macro return data);

            fields.push(
            {
                name: "applyDefaults",
                access: [APrivate, AStatic],
                kind: FFun(
                {
                    args: [{name: "name", type: (macro : String)}, {name: "data", type: dataType}],
                    ret: dataType,
                    expr: macro $b{body}
                }),
                pos: pos
            });
        }

        return fields;
    }

    static function genObject(obj:Expr, fields:Array<ClassField>, depth:Int):Array<Expr>
    {
        var out:Array<Expr> = [];

        if (depth > 16)
            return out;

        for (field in fields)
        {
            var def = getDef(field);

            if (!def.has)
                continue;

            var access:Expr = {expr: EField(obj, field.name), pos: Context.currentPos()};
            var type:Type = resolve(field.type);

            var anon:Array<ClassField> = asAnon(type);
            var element:Type = arrayElement(type);

            if (anon != null)
            {
                var sub:Array<Expr> = genObject(macro _o, anon, depth + 1);

                if (isNull(def.expr))
                {
                    out.push(macro
                    {
                        if ($access != null)
                        {
                            var _o = $access;
                            $b{sub};
                        }
                    });
                }
                else
                {
                    var seed:Expr = def.expr != null ? def.expr : macro {};

                    out.push(macro
                    {
                        if ($access == null)
                            $access = $seed;

                        var _o = $access;
                        $b{sub};
                    });
                }
            }
            else if (element != null && asAnon(resolve(element)) != null)
            {
                var seed:Expr = def.expr != null ? def.expr : macro [];
                var items:Array<Expr> = genObject(macro _e, asAnon(resolve(element)), depth + 1);

                var guard:Expr = (def.expr != null && arrayLength(def.expr) > 0) ? macro ($access == null || $access.length == 0) : macro ($access == null);

                out.push(macro
                {
                    if ($guard)
                        $access = $seed;

                    var _a = $access;
                    var _i = _a.length;

                    while (--_i >= 0) if (_a[_i] == null)
                        _a.splice(_i, 1);

                    for (_e in _a)
                        $b{items};
                });
            }
            else if (def.expr != null)
            {
                var value:Expr = def.expr;
                var length:Int = element != null ? arrayLength(value) : 0;

                if (length > 0)
                    out.push(macro if ($access == null || $access.length < $v{length}) $access = $value);
                else
                    out.push(macro if ($access == null) $access = $value);
            }
        }

        return out;
    }

    static function isNull(expr:Expr):Bool
    {
        return expr != null && switch (expr.expr)
        {
            case EConst(CIdent("null")): true;
            default: false;
        }
    }

    static function getDef(field:ClassField):{has:Bool, expr:Null<Expr>}
    {
        if (field.meta == null || !field.meta.has(":def"))
            return {has: false, expr: null};

        for (entry in field.meta.extract(":def"))
        {
            if (entry.params != null && entry.params.length > 0)
                return {has: true, expr: entry.params[0]};
        }

        return {has: true, expr: null};
    }

    static function resolve(type:Type):Type
    {
        type = Context.follow(type);

        return switch (type)
        {
            case TAbstract(_.get() => abstractType, [param]) if (abstractType.name == "Null"): resolve(param);
            default: type;
        }
    }

    static function asAnon(type:Type):Array<ClassField>
    {
        return switch (type)
        {
            case TAnonymous(anon): anon.get().fields;
            default: null;
        }
    }

    static function arrayElement(type:Type):Type
    {
        return switch (type)
        {
            case TInst(_.get() => classType, [param]) if (classType.name == "Array" && classType.pack.length == 0): param;
            default: null;
        }
    }

    static function arrayLength(expr:Expr):Int
    {
        return switch (expr.expr)
        {
            case EArrayDecl(values): values.length;
            default: 0;
        }
    }

    static function getFolder(meta:Metadata):String
    {
        for (entry in meta)
        {
            if (entry.name == ":folder" && entry.params != null && entry.params.length > 0)
            {
                switch (entry.params[0].expr)
                {
                    case EConst(CString(value)): return value;
                    default:
                }
            }
        }

        return null;
    }

    static function getListType(fields:Array<Field>):ComplexType
    {
        for (field in fields)
        {
            if (field.name != "list")
                continue;

            switch (field.kind)
            {
                case FVar(TPath(path), _) if (path.name == "Map" && path.params != null && path.params.length == 2):
                {
                    switch (path.params[1])
                    {
                        case TPType(dataType): return dataType;
                        default:
                    }
                }

                default:
            }
        }

        return null;
    }
}
#end
