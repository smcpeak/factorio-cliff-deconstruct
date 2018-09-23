# Cliff deconstruct

Using the Deconstruction Planner on cliffs will cause robots to place Cliff explosives on every cliff in the area.

Additionally, shift-clicking with cliff-explosives will mark a spot for their use
by robots.

## Known Issues

Cliffs will be destroyed regardless of the current deconstruction planner filter settings,
and there is no way to turn off cliff destruction.

Cliffs will *not* be destroyed when shift-clicking a blueprint that has conflicts (unlike
trees and rocks).

The deconstruction planner filter now has an option for cliff-explosives, but its
effect is limited and perhaps unexpected since any use of the planner still marks
cliffs.

It is possible to put the ghost entities that mark cliff deconstruction into a blueprint.
If the blueprint only has those entities, it can be clicked and dragged to "paint" a very
large number of them anywhere on the map.  The same is true of shift-click-dragging the
cliff-explosives item.

The current placement algorithm uses about 50% more explosives than optimal manual
placement.  However, it is more efficient than in 0.0.5, which used about 100% more than
optimal.

This mod causes the icon for the explosives to appear partially transparent when the
mouse cursor is a short distance from the player character.  This distance is misleading
as it is not related to the item's usage range.

## Changelog

0.1.0

* Fix memory leak and save game file growth.
* Rework some of the internals, add comments.
* Reduce explosive usage by placing them on every other cliff entity.

0.0.4

* Deconstructing a cliff multiple times will no longer cause multiple explosives to be placed.
* If a robot gets to a cliff that has already been destroyed then the explosives will not be used.

0.0.3

* Shift-deconstructing an area will cancel explosive placement.

0.0.2

* Fixed a crash when an area of zero size was selected.

0.0.1

* Initial release.
