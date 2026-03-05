/*
This file is the starting point of your game.

Some important procedures are:
- game_init_window: Opens the window
- game_init: Sets up the game state
- game_update: Run once per frame
- game_should_close: For stopping your game when close button is pressed
- game_shutdown: Shuts down game and frees memory
- game_shutdown_window: Closes window

The procs above are used regardless if you compile using the `build_release`
script or the `build_hot_reload` script. However, in the hot reload case, the
contents of this file is compiled as part of `build/hot_reload/game.dll` (or
.dylib/.so on mac/linux). In the hot reload cases some other procedures are
also used in order to facilitate the hot reload functionality:

- game_memory: Run just before a hot reload. That way game_hot_reload.exe has a
	pointer to the game's memory that it can hand to the new game DLL.
- game_hot_reloaded: Run after a hot reload so that the `g` global
	variable can be set to whatever pointer it was in the old DLL.

NOTE: When compiled as part of `build_release`, `build_debug` or `build_web`
then this whole package is just treated as a normal Odin package. No DLL is
created.
*/

package game

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

when ODIN_OS == .JS {
	foreign import mymath "env"
} else when ODIN_DEBUG {
	when ODIN_OS == .Windows { foreign import mymath "mymath:mymath.lib"  } else
	when ODIN_OS == .Linux   { foreign import mymath "mymath:libmymath.so" } else
	when ODIN_OS == .Darwin  { foreign import mymath "mymath:libmymath.dylib" }
} else {
	when ODIN_OS == .Windows { foreign import mymath "../mymath/target/release/mymath.lib"  } else
	when ODIN_OS == .Linux   { foreign import mymath "../mymath/target/release/libmymath.a" } else
	when ODIN_OS == .Darwin  { foreign import mymath "../mymath/target/release/libmymath.a" }
}

@(default_calling_convention="c")
foreign mymath {
	@(link_name="add")
    add :: proc(left: f32, right: f32) -> f32 ---
}

PIXEL_WINDOW_HEIGHT :: 180

Game_Memory :: struct {
	player_pos: rl.Vector3,
	player_mesh: rl.Mesh,
	player_mat: rl.Material,
	some_number: int,
	run: bool,
}

g: ^Game_Memory

game_camera :: proc() -> rl.Camera3D {
	return {
        position = {0, 3, 3},
        target = {0, 0, 0},
        up = {0, 1, 0},
        fovy = 70,
        projection = .PERSPECTIVE,
    }
}

ui_camera :: proc() -> rl.Camera2D {
	return {
		zoom = f32(rl.GetScreenHeight())/PIXEL_WINDOW_HEIGHT,
	}
}

update :: proc() {
	input: rl.Vector3 = {
		(rl.IsKeyDown(.RIGHT) ? 1 : 0) -
		(rl.IsKeyDown(.LEFT) ? 1 : 0),
		(rl.IsKeyDown(.UP) ? 1 : 0) -
		(rl.IsKeyDown(.DOWN) ? 1 : 0),
		0,
	}

	if input.x != 0 && input.y != 0 {
		input = linalg.normalize0(input)
	}
	g.player_pos += input * rl.GetFrameTime() * 5
	g.some_number += 1

	if rl.IsKeyPressed(.ESCAPE) {
		g.run = false
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode3D(game_camera())
	t := f32(rl.GetTime())
	rot := [3]f32{t, t*2, t*3}
	transf := rl.MatrixTranslate(g.player_pos.x, g.player_pos.y, g.player_pos.z) * rl.MatrixRotateXYZ(rot)
	rl.DrawMesh(g.player_mesh, g.player_mat, transf)
	rl.EndMode3D()

	rl.BeginMode2D(ui_camera())

	// NOTE: `fmt.ctprintf` uses the temp allocator. The temp allocator is
	// cleared at the end of the frame by the main application, meaning inside
	// `main_hot_reload.odin`, `main_release.odin` or `main_web_entry.odin`.
	rl.DrawText(fmt.ctprintf("some_number: %v\nplayer_pos: %v", g.some_number, g.player_pos), 5, 5, 8, rl.WHITE)

	rl.EndMode2D()

	rl.EndDrawing()
}

@(export)
game_update :: proc() {
	update()
	draw()

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	g = new(Game_Memory)

	g^ = Game_Memory {
		run = true,
		some_number = 100,
		player_mesh = rl.GenMeshCube(1, 1, 1),
		player_mat = rl.LoadMaterialDefault(),
	}

	game_hot_reloaded(g)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return g.run
}

@(export)
game_shutdown :: proc() {
	free(g)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_Memory)(mem)

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside `g`.
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
