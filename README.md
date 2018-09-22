# Cliff deconstruct

Using the Deconstruction Planner on cliffs will cause robots to place Cliff explosives on every cliff in the area.

## Known Issues

Cliffs will be destroyed regardless of the current deconstruction planner filter settings,
and there is no way to turn off cliff destruction.

Cliffs will *not* be destroyed when shift-clicking a blueprint that has conflicts (unlike
trees and rocks).

This mod causes the icon for the explosives to appear partially transparent when the
mouse cursor is a short distance from the player character.  This distance is misleading
as it is not related to the item's usage range.

## Changelog

0.1.0

* Fix memory leak and save game file growth.

0.0.4

* Deconstructing a cliff multiple times will no longer cause multiple explosives to be placed.
* If a robot gets to a cliff that has already been destroyed then the explosives will not be used.

0.0.3

* Shift-deconstructing an area will cancel explosive placement.

0.0.2

* Fixed a crash when an area of zero size was selected.

0.0.1

* Initial release.
