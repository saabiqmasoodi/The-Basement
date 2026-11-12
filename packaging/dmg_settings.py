# dmgbuild layout for the macOS release.
#
# The window is deliberately a single decorated panel: the app sits on the
# left, Applications on the right, and the painted background carries the
# drag arrow and the horror styling. dmgbuild writes the .DS_Store directly,
# so the layout works on headless CI runners as well as locally.

import os

app = os.path.abspath(defines.get("app", "build/releases/macos/NotToLove.app"))
app_name = os.path.basename(app)

files = [app]
symlinks = {"Applications": "/Applications"}
hide_extensions = [app_name]

background = os.path.abspath(
    defines.get("background", "packaging/dmg-background.png")
)

icon_locations = {
    app_name: (210, 222),
    "Applications": (790, 222),
}

window_rect = ((180, 120), (1000, 420))
default_view = "icon-view"
icon_size = 128
text_size = 14

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
include_icon_view_settings = "auto"
