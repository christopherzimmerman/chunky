package cube

import "core:fmt"
import "core:math"
import "core:time"
import rl "vendor:raylib"

/*  WORLD_TO_CHUNK 

    Convert xz world coordinates to xz chunk coordinates
*/
WORLD_TO_CHUNK :: proc (x: int) -> int {return x < 0 ? x % CHUNK_SIZE == 0 ? 0 : CHUNK_SIZE + x % CHUNK_SIZE : x % CHUNK_SIZE}

/*  CHUNK_FROM_WORLD_COORDS 

    Find the xz offset of a chunk based on xz world
    coordinates
*/
CHUNK_FROM_WORLD_COORDS :: proc(x: int) -> int
{ 
    chunk := f32(x) / CHUNK_SIZE
    return chunk < 0 ? int(math.floor_f32(chunk)) : int(chunk)
}

/*  World 

    Manages all entities related to the rendering
    and updating of a voxel world
*/
World :: struct
{
    /*  chunks 

        The world manages chunks, keeping them in
        a map for easy lookup based on offset
    */
    chunks        : map[Int_Vector3]Chunk,

    /*  camera 
    
        Basic 3D camera, relies on Raylibs first person
        controller for now
    */
    camera        : rl.Camera3D,

    /*  block_texture 
    
        Shared texture for all chunk meshes
    */
    block_texture : rl.Texture2D,

    /*  block_shader 
    
        Shared block shader for all chunk meshes
    */
    block_shader  : rl.Shader,

    /*  block_material
    
        Shared material for all chunk meshes
    */
    block_material: rl.Material,

    /*  current_time 
    
        Current offset of time, capped at the max day length
        and then reset to zero
    */
    current_time  : f64,

    /*  sunlight_loc 
    
        Shader location of sunlight strength
    */
    sunlight_loc  : rl.ShaderLocationIndex,

    /*  tick 
    
        Current world tick to calculate time of day
    */
    tick          : time.Tick,
}

/*  world_init 

    Initialize the shaders, materials and textures associated
    with a voxel world, and set shader attributes
*/
world_init :: proc (w: ^World)
{
    w.block_texture = resource_load_texture("resources/atlas.png")
    w.block_shader = rl.LoadShader("resources/shaders/lighting.vs", "resources/shaders/lighting.fs")
    w.block_shader.locs[
        rl.ShaderLocationIndex.VECTOR_VIEW
    ] = rl.GetShaderLocation(w.block_shader, "viewPos")
    w.camera.up.y = 90
    w.camera.fovy = 85
    w.camera.position = {7, 32, 7}
    w.tick = time.tick_now()
    mat := rl.LoadMaterialDefault()
    w.block_material = rl.LoadMaterialDefault()
    rl.SetMaterialTexture(&w.block_material, .ALBEDO, w.block_texture)
    w.block_material.shader = w.block_shader
    draw_distance: f32 = 160
    w.sunlight_loc = rl.ShaderLocationIndex(rl.GetShaderLocation(w.block_shader, "sunlightStrength"))
    rl.SetShaderValue(w.block_shader, rl.ShaderLocationIndex(rl.GetShaderLocation(w.block_shader, "drawDistance")), &draw_distance, .FLOAT)
}

/*  world_update 

    Update time of day and other entities managed by the world
*/
world_update :: proc (w: ^World)
{
    new_tick := time.tick_now()
    time_spent := time.duration_seconds(time.tick_diff(w.tick, new_tick))
    w.tick = new_tick
    w.current_time += time_spent
    if (w.current_time >= WORLD_DAY_LENGTH_SECONDS)
    {
        w.current_time = 0
    }
}

/*  world_get_sunlight 

    Compute current sunlight level based on time of day
*/
world_get_sunlight :: proc (w: ^World) -> f32
{
    return max(abs((f32(w.current_time) - WORLD_DAY_LENGTH_SECONDS / 2.0)) / (WORLD_DAY_LENGTH_SECONDS / 2.0), 2 / 16.0)
}

/*  world_get_block 

    Calculate a block based on world coordinates.  THIS IS SLOW
    and should not be used in bulk, chunks should store their
    neighbors and use offset calculations to find neighboring
    blocks rather than fall back to this
*/
world_get_block :: proc (w: ^World, x: int, y: int, z: int) -> Block_Type
{
    chunk_x := CHUNK_FROM_WORLD_COORDS(x)
    chunk_z := CHUNK_FROM_WORLD_COORDS(z)
    if (!({chunk_x, 0, chunk_z} in w.chunks) || y < 0 || y >= CHUNK_HEIGHT)
    {
        return .AIR
    }
    else
    {
        return w.chunks[{chunk_x, 0, chunk_z}].blocks[WORLD_TO_CHUNK(x)][y][WORLD_TO_CHUNK(z)]
    }
}

/*  world_destroy 

    Free chunk meshes and shared materials
*/
world_destroy :: proc (w: ^World)
{
    for idx in w.chunks {
        chunk_destroy(&w.chunks[idx])
    }
    rl.UnloadMaterial(w.block_material)
}