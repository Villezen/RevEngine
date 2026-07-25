package backend.utils;

class MtlUtil
{
	public static function findMtlLib(objText:String):String
	{
		for (line in objText.split("\n"))
		{
			var trimmed = line.trim();

			if (trimmed.startsWith("mtllib "))
				return trimmed.substr(7).trim();
		}

		return null;
	}

	public static function findTextureRefs(mtlText:String):Array<String>
	{
		var refs:Array<String> = [];
		var trailing = ~/\s+$/;

		for (line in mtlText.split("\n"))
		{
			var raw = trailing.replace(line, "");
			var trunk = raw.split(" ");

			if (trunk.length == 0)
				continue;

			var head = trunk[0];
			if (head.length > 0 && (head.charCodeAt(0) == 9 || head.charCodeAt(0) == 32))
				trunk[0] = head.substr(1);

			if (trunk[0] != "map_Kd")
				continue;

			var f = parseMapKd(trunk).split("\\").join("/");

			if (f != "" && refs.indexOf(f) < 0)
				refs.push(f);
		}

		return refs;
	}

	static function parseMapKd(trunk:Array<String>):String
	{
		var i = 1;

		while (i < trunk.length)
		{
			switch (trunk[i])
			{
				case "-blendu", "-blendv", "-cc", "-clamp", "-texres": i += 2;
				case "-mm": i += 3;
				case "-o", "-s", "-t": i += 4;
				default: break;
			}
		}

		return trunk.slice(i).join(" ").rtrim();
	}
}
