@echo off

cl /c pugl-main\src\common.c pugl-main\src\internal.c pugl-main\src\win.c pugl-main\src\win_gl.c /I pugl-main\include -DPUGL_STATIC=1 /O2

lib /OUT:pugl.lib common.obj internal.obj win.obj win_gl.obj

del common.obj
del internal.obj
del win.obj
del win_gl.obj