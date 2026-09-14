"""Which plans each place builds to: one module per environment, gathered here.

`LAYOUTS[env][variant]` is a tuple of plans, one per layout index, and the index is what a tile is
seeded to -- so a place is drawn four ways and a tile always fights in front of the same one.

The plans themselves live beside the pieces they use, in lay_<env>.py, for the same reason the
pieces do: a catalogue that can only reach one culture's vocabulary cannot accidentally borrow
another's, which is exactly how six places ended up with one castle between them.
"""
import lay_desert as _desert
import lay_dirt as _dirt
import lay_forest as _forest
import lay_grass as _grass
import lay_ice as _ice
import lay_mountains as _mtn

LAYOUTS = {
    "grass": _grass.LAYOUTS,
    "dirt": _dirt.LAYOUTS,
    "desert": _desert.LAYOUTS,
    "ice": _ice.LAYOUTS,
    "forest": _forest.LAYOUTS,
    "mountains": _mtn.LAYOUTS,
}
