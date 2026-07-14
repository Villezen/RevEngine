package backend.utils;

class SortUtil
{
  /**
   * Sort predicate for sorting strings alphabetically.
   * @param a The first string to compare.
   * @param b The second string to compare.
   * @return 1 if `a` comes before `b`, -1 if `b` comes before `a`, 0 if they are equal
   */
  public static function alphabetically(a:String, b:String):Int
  {
    a = a.toUpperCase();
    b = b.toUpperCase();

    // Sort alphabetically. Yes that's how this works.
    return a == b ? 0 : a > b ? 1 : -1;
  }
}