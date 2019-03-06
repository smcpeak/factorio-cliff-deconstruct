# Cliff deconstruct

Using the Deconstruction Planner on cliffs will cause robots to place Cliff explosives on all cliffs in the area, destroying them.

Additionally, shift-clicking with cliff-explosives will mark a spot for their use
by robots.

Mod originally by bob809, almost completely rewritten and improved by smcpeak.

## Known Issues

Cliffs will be destroyed regardless of the current deconstruction planner filter settings.
However, there is a setting (in Options -> Mod Settings) to disable the mod, in which case
it will ignore uses of the deconstruction planner.

Cliffs will *not* be destroyed when shift-clicking a blueprint that has conflicts (unlike
trees and rocks).

It is possible to put the ghost entities that mark cliff deconstruction into a blueprint.
The same is true of shift-click placing the cliff-explosives item.

This mod causes the icon for the explosives to appear partially transparent when the
mouse cursor is a short distance from the player character.  This distance is misleading
as it is not related to the item's usage range.

## Placement Efficiency

From v0.1.0 the placement algorithm is very efficient, notably using about half
as many cliff explosives as the previous naive approach. This is just as
efficient as manual placement in almost every case.

Consequently, there is no resource penalty associated with using robots to do the work
(other than the usual costs of building and powering the robots themselves).

## Changelog

0.1.0

* Rewrite of the mod's internals by [smcpeak](https://mods.factorio.com/user/smcpeak)
* New, much more efficient, placement algorithm, reducing cliff explosive use by about half.
* Add Mod Settings efficient
    - Enable/disable the mod
    - Enable logging
    - Show cliff explosive area of effect in sprite
* Fix memory leak and consequent save game file growth.

0.0.4

* Deconstructing a cliff multiple times will no longer cause multiple explosives to be placed.
* If a robot gets to a cliff that has already been destroyed then the explosives will not be used.

0.0.3

* Shift-deconstructing an area will cancel explosive placement.

0.0.2

* Fixed a crash when an area of zero size was selected.

0.0.1

* Initial release.
