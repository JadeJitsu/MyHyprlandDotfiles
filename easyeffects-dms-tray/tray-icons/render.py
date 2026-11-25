#!/usr/bin/env python3
"""Render EE symbolic tray icons (white-on-transparent PNGs) via librsvg.
Usage: render.py   (writes next to itself; needs gi + Rsvg + cairo)"""
import os, sys
import gi
gi.require_version('Rsvg', '2.0')
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf
from gi.repository import Rsvg
import cairo

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = '/usr/local/share/icons/hicolor/scalable/apps'
SIZE = 48

for name in ('com.github.wwmm.easyeffects-symbolic',
             'com.github.wwmm.easyeffects-off-symbolic'):
    svg = f'{SRC}/{name}.svg'
    out = f'{HERE}/{name}.png'
    handle = Rsvg.Handle.new_from_file(svg)
    # The symbolic SVGs carry only a 16x16 viewBox; render at native size
    # and upscale.
    pb = handle.get_pixbuf().scale_simple(SIZE, SIZE, GdkPixbuf.InterpType.BILINEAR)
    pb.savev(out, 'png', [])
    print(f'rendered {out}')
