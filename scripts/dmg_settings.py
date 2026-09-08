import os

volume_name = 'BarBoss'
badge_icon = 'BarBoss/Resources/AppIcon.icns'
files = [ 'build/DerivedData/Build/Products/Release/BarBoss.app' ]
symlinks = { 'Applications': '/Applications' }
background = 'scripts/dmg_background.png'

window_rect = ((200, 120), (660, 400))
default_view = 'icon-view'
icon_size = 128
text_size = 13

icon_locations = {
    'BarBoss.app': (175, 190),
    'Applications': (485, 190)
}
