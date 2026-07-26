package backend.utils;

class ScoringUtil
{
    public static function scoreNote(msTiming:Float):Float
    {
        var absTiming:Float = Math.abs(msTiming);

        if (absTiming <= Constants.SCORE_PERFECT_THRESHOLD)
            return Constants.SCORE_MAX;

        var factor:Float = 1.0 - (1.0 / (1.0 + Math.exp(-Constants.SCORE_SIGMOID_SLOPE * (absTiming - Constants.SCORE_SIGMOID_OFFSET))));

        return Constants.SCORE_MAX * factor + Constants.SCORE_MIN;
    }
}
