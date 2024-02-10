package cube

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"
import gl "vendor:OpenGl"

main :: proc ()
{
    rl.InitWindow(1200, 800, "cube")
    rl.SetTargetFPS(144)
    w: World
    defer world_destroy(&w)
    world_init(&w)
    seed := rand.int63()

    for x := -5; x <= 5; x += 1
    {
        for z := -5; z <= 5; z += 1
        {
            c: Chunk
            w.chunks[{x, 0, z}] = c
            chunk_init(&w.chunks[{x, 0, z}], &w, x, 0, z)
            chunk_create(&w.chunks[{x, 0, z}], seed)
        }
    }
    for x := -5; x <= 5; x += 1
    {
        for z := -5; z <= 5; z += 1
        {
            chunk := &w.chunks[{x, 0, z}]
            chunk_compute_light_sources(chunk)
            chunk_compute_sunlight(chunk)
            
        }
    }
    for x := -5; x <= 5; x += 1
    {
        for z := -5; z <= 5; z += 1
        {
            chunk_build_buffer(&w.chunks[{x, 0, z}], &w)
        }
    }
    rl.DisableCursor()
    for (!rl.WindowShouldClose())
    {
        rl.BeginDrawing()
        sunlight_strength := world_get_sunlight(&w)
        rl.ClearBackground({u8(140 * sunlight_strength), u8(210 * sunlight_strength), u8(240 * sunlight_strength), 255})
        rl.SetShaderValue(w.block_shader, w.sunlight_loc, &sunlight_strength, .FLOAT)
        rl.BeginMode3D(w.camera)
        rl.UpdateCamera(&w.camera, .FIRST_PERSON)
        rl.SetShaderValue(w.block_shader, rl.ShaderLocationIndex.VECTOR_VIEW, &w.camera.position, .VEC3)
        world_update(&w)
        for chunk, value in &w.chunks
        {
            chunk_draw(&value)
        }
        rl.EndMode3D()
        rl.DrawFPS(0, 0)
        rl.EndDrawing()
    }
}