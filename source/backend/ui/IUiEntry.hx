package backend.ui;

interface IUiEntry
{
    public var clickable(default, set):Bool;
    public var priority(get, set):Bool;
    public function getHoveredElement():IUiEntry;
}