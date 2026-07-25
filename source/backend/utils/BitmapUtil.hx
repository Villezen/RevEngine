package backend.utils;

import openfl.display.BitmapData;
import openfl.geom.Matrix;

class BitmapUtil
{
	public static function nextPowerOfTwo(value:Int):Int
	{
		var p = 1;

		while (p < value)
			p <<= 1;

		return p > 2048 ? 2048 : p;
	}

	public static function toPowerOfTwo(src:BitmapData):BitmapData
	{
		var w = nextPowerOfTwo(src.width);
		var h = nextPowerOfTwo(src.height);

		var out = new BitmapData(w, h, true, 0x00000000);

		if (w == src.width && h == src.height)
			out.draw(src);
		else
		{
			var matrix = new Matrix();
			matrix.scale(w / src.width, h / src.height);
			out.draw(src, matrix, null, null, null, true);
		}

		return out;
	}
}
