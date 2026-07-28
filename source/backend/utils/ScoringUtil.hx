package backend.utils;

import backend.Highscore;
import backend.Highscore.ScoreTallies;

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

    /**
     * Determines the rank earned for a completed song from its final tallies.
     * @param tallies The score tallies to grade.
     * @return The earned rank.
     */
    public static function calculateRank(?tallies:ScoreTallies):Null<ScoringRank>
    {
        if (tallies == null || tallies.totalNotes == 0)
            return null;

        if (tallies.sick == tallies.totalNotes)
            return ScoringRank.PERFECT_GOLD;

        return rankForCompletion(Highscore.tallyCompletion(tallies));
    }

    /**
     * Determines the rank the player currently holds, graded against the notes played so far.
     * @return The live rank, or null before any note has been judged.
     */
    public static function calculateRankLive(sick:Int, good:Int, bad:Int, shit:Int, missed:Int):Null<ScoringRank>
    {
        var processed:Int = sick + good + bad + shit + missed;

        if (processed == 0)
            return null;

        if (sick == processed)
            return ScoringRank.PERFECT_GOLD;

        var completion:Float = Math.max(0, Math.min(1, (sick + good - missed) / processed));
        return rankForCompletion(completion);
    }

    static function rankForCompletion(completion:Float):ScoringRank
    {
        if (completion >= Constants.RANK_PERFECT_THRESHOLD)
            return ScoringRank.PERFECT;
        else if (completion >= Constants.RANK_EXCELLENT_THRESHOLD)
            return ScoringRank.EXCELLENT;
        else if (completion >= Constants.RANK_GREAT_THRESHOLD)
            return ScoringRank.GREAT;
        else if (completion >= Constants.RANK_GOOD_THRESHOLD)
            return ScoringRank.GOOD;
        else
            return ScoringRank.SHIT;
    }
}

enum abstract ScoringRank(String)
{
    var PERFECT_GOLD;
    var PERFECT;
    var EXCELLENT;
    var GREAT;
    var GOOD;
    var SHIT;

    /**
     * Converts a rank to an integer value.
     */
    static function getValue(rank:Null<ScoringRank>):Int
    {
        if (rank == null) return -1;
        switch (rank)
        {
            case PERFECT_GOLD: return 5;
            case PERFECT: return 4;
            case EXCELLENT: return 3;
            case GREAT: return 2;
            case GOOD: return 1;
            case SHIT: return 0;
            default: return -1;
        }
    }

    @:op(A > B) static function compareGT(a:Null<ScoringRank>, b:Null<ScoringRank>):Bool
    {
        if (a != null && b == null) return true;
        if (a == null || b == null) return false;
        return getValue(a) > getValue(b);
    }

    @:op(A >= B) static function compareGTEQ(a:Null<ScoringRank>, b:Null<ScoringRank>):Bool
    {
        if (a != null && b == null) return true;
        if (a == null || b == null) return false;
        return getValue(a) >= getValue(b);
    }

    @:op(A < B) static function compareLT(a:Null<ScoringRank>, b:Null<ScoringRank>):Bool
    {
        if (a != null && b == null) return true;
        if (a == null || b == null) return false;
        return getValue(a) < getValue(b);
    }

    @:op(A <= B) static function compareLTEQ(a:Null<ScoringRank>, b:Null<ScoringRank>):Bool
    {
        if (a != null && b == null) return true;
        if (a == null || b == null) return false;
        return getValue(a) <= getValue(b);
    }

    /**
     * The animation name for this rank's badge in the freeplay rank spritesheet.
     */
    public function getFreeplayRankIconAsset():String
    {
        switch (abstract)
        {
            case PERFECT_GOLD: return 'PERFECTSICK';
            case PERFECT: return 'PERFECT';
            case EXCELLENT: return 'EXCELLENT';
            case GREAT: return 'GREAT';
            case GOOD: return 'GOOD';
            case SHIT: return 'LOSS';
            default: return 'LOSS';
        }
    }

    /**
     * The color used for this rank's freeplay glow.
     */
    public function getRankingFreeplayColor():FlxColor
    {
        return switch (abstract)
        {
            case SHIT: 0xFF6044FF;
            case GOOD: 0xFFEF8764;
            case GREAT: 0xFFEAF6FF;
            case EXCELLENT: 0xFFFDCB42;
            case PERFECT: 0xFFFF58B4;
            case PERFECT_GOLD: 0xFFFFB619;
            default: 0xFF6044FF;
        }
    }

    /**
     * The label shown in the score text for the rank on track to be earned.
     */
    public function getScoreLabel():String
    {
        switch (abstract)
        {
            case PERFECT_GOLD: return 'P+';
            case PERFECT: return 'P';
            case EXCELLENT: return 'E';
            case GREAT: return 'G+';
            case GOOD: return 'G';
            case SHIT: return 'L';
            default: return 'L';
        }
    }

    public function toString():String
    {
        return this;
    }
}
