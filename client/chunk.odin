package cube

import "core:fmt"
import rl "vendor:raylib"

_GLOBAL_VERTEX_BUFFER    : [^]f32 = make([^]f32, CHUNK_MAX_VERTEX_COUNT * 3)
_GLOBAL_NORMAL_BUFFER    : [^]f32 = make([^]f32, CHUNK_MAX_VERTEX_COUNT * 3)
_GLOBAL_TEXCOORDS_BUFFER : [^]f32 = make([^]f32, CHUNK_MAX_VERTEX_COUNT * 2)
_GLOBAL_TEXCOORDS2_BUFFER: [^]f32 = make([^]f32, CHUNK_MAX_VERTEX_COUNT * 2)

/*  Chunk 

    A chunk stores information about a 16x32x16 region
    of the world, and manages the rendering and updating
    of that data.
*/
Chunk :: struct
{
    /*  blocks 
    
        Buffer to store block information for xyz coordinates.
        This is used as the source of truth for the chunk when
        rendering the mesh.  Never update this directly, use
        a setter that does bounds checking to ensure the right
        chunk is updated
    */
    blocks   : [CHUNK_SIZE][CHUNK_HEIGHT][CHUNK_SIZE]Block_Type,

    /*  lights 
    
        Light data for each block in a chunk
    */
    lights   : [CHUNK_SIZE][CHUNK_HEIGHT][CHUNK_SIZE]u8,

    /*  sunlight 
    
        Sunlight data for each block in a chunk
    */
    sunlight : [CHUNK_SIZE][CHUNK_HEIGHT][CHUNK_SIZE]u8,

    /*  x, y, z
    
        Coordinates of the chunk in the world.  Y coords are used
        becaues chunks can be tiled vertically.

        Use x * CHUNK_SIZE, y * CHUNK_HEIGHT, z * CHUNK_SIZE to go
        from chunk to world coordinates
    */
    x, y, z  : int,

    /*  transform 
    
        Real world coordinates for the model of the chunk
    */
    transform: rl.Vector3,

    /*  mesh 
    
        Manages the vertex / triangle / texture state of the chunk.
        The buffers of this mesh should not be redrawn frequently,
        but should instead be allocated to the max possible size,
        and rendered based on vertex/triangle count.  Also this mesh
        will not be allocated or rendered if the chunk is empty
    */
    mesh     : rl.Mesh,

    /*  model
    
        Manages the offset / location and texture for a chunk's mesh.
    */
    model    : rl.Model,

    /*  dirty 

        Tracks whether the chunk has been modified, and needs to have
        its mesh rebuilt
    */
    dirty    : bool,

    /*  generator 
    
        Manages state throughout the generation of the work
    */
    generator: struct
    {
        /*  normal
        
            The current normal vector for rendering a face
        */
        normal    : rl.Vector3,
        
        /*  uv 
        
            The current texture coordinates for rendering a face
        */
        uv        : rl.Vector2,

        /*  idx, t_idx 
        
            The current indices for vertices and triangles throughout
            the chunk rendering process
        */
        idx, t_idx: int,
    },

    world: ^World,
    loaded: bool,
}

/*  chunk_init 

    Sets up a chunk for rendering and storing world data
*/
chunk_init :: proc (chunk: ^Chunk, w: ^World, x, y, z: int)
{
    chunk_mesh_init(chunk)
    chunk.x = x
    chunk.y = y
    chunk.z = z
    chunk.dirty = false
    chunk.world = w
    chunk.transform = {f32(x) * CHUNK_SIZE, f32(y) * CHUNK_HEIGHT, f32(z) * CHUNK_SIZE}
}

/*   chunk_mesh_init

    Set up a temporary mesh to use for a chunk.  This mesh contains references to global
    buffers that must be cleared before freeing the mesh, or else raylib will try
    to free the underlying memory.  Eventually this probably needs to be converted
    back to using the raw GL objects for a less wonky approach, since it's a waste
    to allocate managed memory to each mesh
*/
chunk_mesh_init :: proc (chunk: ^Chunk)
{
    mesh: rl.Mesh
    chunk.mesh = mesh
    chunk.mesh.vertexCount = 0
    chunk.mesh.triangleCount = 0
    chunk.mesh.vertices = _GLOBAL_VERTEX_BUFFER
    chunk.mesh.normals = _GLOBAL_NORMAL_BUFFER
    chunk.mesh.texcoords = _GLOBAL_TEXCOORDS_BUFFER
    chunk.mesh.texcoords2 = _GLOBAL_TEXCOORDS2_BUFFER
    chunk.generator.idx = 0
    chunk.generator.t_idx = 0
}

/*  _chunk_mesh_add_vertex

    Add a single vertex to the chunk's mesh.  6 of these will be added
    per face for cubes, and 4 will be added per face for sprites
*/
@(private="file")
_chunk_mesh_add_vertex :: proc (chunk: ^Chunk, vertex: rl.Vector3, x, y, z: f32, light: u8, sunlight: u8)
{ 
    mesh_ref: ^rl.Mesh = &chunk.mesh
    texture_index: int = chunk.generator.t_idx * 6 + chunk.generator.idx * 2
    mesh_ref.texcoords[texture_index + 0] = chunk.generator.uv.x
    mesh_ref.texcoords[texture_index + 1] = chunk.generator.uv.y
    normal_index: int = chunk.generator.t_idx * 9 + chunk.generator.idx * 3
    mesh_ref.normals[normal_index + 0] = chunk.generator.normal.x
    mesh_ref.normals[normal_index + 1] = chunk.generator.normal.y
    mesh_ref.normals[normal_index + 2] = chunk.generator.normal.z
    vertex_index: int = chunk.generator.t_idx * 9 + chunk.generator.idx * 3
    mesh_ref.vertices[vertex_index + 0] = vertex.x + x
    mesh_ref.vertices[vertex_index + 1] = vertex.y + y
    mesh_ref.vertices[vertex_index + 2] = vertex.z + z
    color_index: int = chunk.generator.t_idx * 6 + chunk.generator.idx * 2
    mesh_ref.texcoords2[color_index + 0] = f32((light << 4))
    mesh_ref.texcoords2[color_index + 1] = f32(sunlight)
    chunk.generator.idx += 1
    if (chunk.generator.idx > 2)
    {
        chunk.generator.t_idx += 1
        chunk.generator.idx = 0
    }
}

/*  _chunk_mesh_add_cube 

    Add a single voxel to a chunk's mesh, ignoring faces
    that do not need to be rendered
*/
@(private="file")
_chunk_mesh_add_cube :: proc (chunk: ^Chunk, position: rl.Vector3, int_pos: Int_Vector3, neighbors: [6]Block_Type, block: Block_Type) -> i32
{
    count: i32
    cmg := &chunk.generator

    #partial switch block
    {
        case .SAPLING, .ROSE, .BUTTERCUP, .TORCH, .TALL_GRASS:
            light_level := chunk_get_light(chunk, int_pos)
            sunlight_level := chunk_get_light(chunk, int_pos, true)
            for i := 0; i < 2; i += 1
            {
                cmg.normal = {0, 1, 0}
                texture_x := f32(BLOCK_ATLAS[block][0] % 16)
                texture_y := f32(BLOCK_ATLAS[block][0] / 16)
                for j := 0; j < 6; j += 1
                {
                    cmg.uv.x = texture_x / 16.0 + SPRITE_TEXTURE_COORDINATES[0][FACE_INDICES[j]].x / 16.0
                    cmg.uv.y = texture_y / 16.0 + SPRITE_TEXTURE_COORDINATES[0][FACE_INDICES[j]].y / 16.0
                    offset := SPRITE_POSITIONS[i][FACE_INDICES[j]]
                    _chunk_mesh_add_vertex(chunk, position, offset.x, offset.y, offset.z, light_level, sunlight_level)
                }
                count += 1

                for j := 5; j >= 0; j -= 1
                {
                    cmg.uv.x = texture_x / 16.0 + SPRITE_TEXTURE_COORDINATES[1][FACE_INDICES[j]].x / 16.0
                    cmg.uv.y = texture_y / 16.0 + SPRITE_TEXTURE_COORDINATES[1][FACE_INDICES[j]].y / 16.0
                    offset := SPRITE_POSITIONS[i][FACE_INDICES[j]]
                    _chunk_mesh_add_vertex(chunk, position, offset.x, offset.y, offset.z, light_level, sunlight_level)
                }
                count += 1
            }
        case:
            for face in Face
            {
                if (!block_is_opaque(neighbors[face]) && (block != neighbors[face] || !block_connects(block)))
                {
                    texture_x := f32(BLOCK_ATLAS[block][face] % 16)
                    texture_y := f32(BLOCK_ATLAS[block][face] / 16)
                    for j := 0; j < 6; j += 1
                    {
                        light_level, sunlight_level: u8
                        if (block_is_opaque(block))
                        {
                            idx := int_pos + LIGHT_DIRECTIONS[face]
                            next_chunk := chunk
                            if (!chunk_in_bounds(idx.x, idx.y, idx.z))
                            {
                                next_chunk_idx := Int_Vector3{chunk.x, chunk.y, chunk.z} + LIGHT_DIRECTIONS[face]
                                if (next_chunk_idx in chunk.world.chunks)
                                {
                                    next_chunk = &chunk.world.chunks[next_chunk_idx]
                                    idx -= LIGHT_DIRECTIONS_X_CHUNK[face]
                                }
                            }
                            light_level = chunk_get_light(next_chunk, idx)
                            sunlight_level = chunk_get_light(next_chunk, idx, true)
                        }
                        else
                        {
                            light_level = chunk_get_light(chunk, int_pos)
                            sunlight_level = chunk_get_light(chunk, int_pos, true)
                        }
                        cmg.normal = BLOCK_NORMALS[face]
                        cmg.uv.x = texture_x / 16.0 + BLOCK_TEXTURE_COORDINATES[face][FACE_INDICES[j]].x / 16.0
                        cmg.uv.y = texture_y / 16.0 + BLOCK_TEXTURE_COORDINATES[face][FACE_INDICES[j]].y / 16.0
                        offset := BLOCK_POSITIONS[face][FACE_INDICES[j]]
                        _chunk_mesh_add_vertex(chunk, position, offset.x, offset.y, offset.z, light_level, sunlight_level)
                    }
                    count += 1
                }
            }
    }

    return count
}

/*  chunk_in_bounds 

    Asserts that a given set of coordinates exist in a single chunk
*/
chunk_in_bounds :: proc (x, y, z: int) -> bool
{
    return x >= 0 && y >= 0 && z >= 0 && x < CHUNK_SIZE && y < CHUNK_HEIGHT && z < CHUNK_SIZE
}

/*  chunk_get_block 

    Returns a block given block level coordinates
    TODO: This should check neighbors (cached on the chunk) if the value
    is out of bounds, to avoiding drawing border meshes
*/
chunk_get_block :: proc (c: ^Chunk, x, y, z: int) -> Block_Type
{
    if (!chunk_in_bounds(x, y, z)) { return .AIR }
    return c.blocks[x][y][z]
}

/*  chunk_build_buffer

    Populate the global mesh buffers for the provided chunk, also
    computing the vertex and triangle counts
*/
chunk_build_buffer :: proc (c: ^Chunk, w: ^World)
{
    if (c.loaded)
    {
        rl.UnloadModel(c.model)
        chunk_mesh_init(c)
    }
    neighbors: [6]Block_Type
    face_count: i32
    x_off := CHUNK_SIZE * c.x 
    z_off := CHUNK_SIZE * c.z
    for x := 0; x < CHUNK_SIZE; x += 1
    {
        for z := 0; z < CHUNK_SIZE; z += 1
        {
            for y := 0; y < CHUNK_HEIGHT; y += 1
            {
                b := c.blocks[x][y][z]
                if (b != .AIR)
                {
                    neighbors[0] = chunk_get_block(c, x, y, z + 1)
                    neighbors[1] = chunk_get_block(c, x, y, z - 1)
                    neighbors[2] = chunk_get_block(c, x + 1, y, z)
                    neighbors[3] = chunk_get_block(c, x - 1, y, z)
                    neighbors[4] = chunk_get_block(c, x, y + 1, z)
                    neighbors[5] = chunk_get_block(c, x, y - 1, z)
                    face_count += _chunk_mesh_add_cube(c, {f32(x), f32(y), f32(z)}, {x, y, z}, neighbors, b)
                }
            }
        }
    }
    c.mesh.vertexCount = face_count * 6
    c.mesh.triangleCount = face_count * 2
    rl.UploadMesh(&c.mesh, false)
    c.mesh.vertices = nil
    c.mesh.normals = nil
    c.mesh.texcoords = nil
    c.mesh.texcoords2 = nil
    c.model = rl.LoadModelFromMesh(c.mesh)
    c.model.materials[0] = w.block_material
    c.loaded = true
}

/*  chunk_draw 

    Draw the chunk's underlying model
*/
chunk_draw :: proc (c: ^Chunk)
{
    rl.DrawModel(c.model, c.transform, 1.0, rl.WHITE)
}

/*  chunk_create 

    Basic worldgen function using perlin noise
*/
chunk_create :: proc (c: ^Chunk, seed: i64)
{
    for dx := 0; dx < CHUNK_SIZE; dx += 1
    {
        for dz := 0; dz < CHUNK_SIZE; dz += 1
        {
            x := c.x * CHUNK_SIZE + dx
            z := c.z * CHUNK_SIZE + dz
            f := simplex2(f32(x) * 0.01, f32(z) * 0.01, 4, 0.5, 2, seed)
            g := simplex2(f32(-x) * 0.01, f32(-z) * 0.01, 2, 0.9, 2, seed)
            mh := g * 32 + 16
            h := int(f * mh)
            w: Block_Type = .GRASS
            t := 12
            if (h <= t)
            {
                h = t
                w = .SAND
            }
            h = min(CHUNK_HEIGHT - 1, h)
            for y := 0; y < h; y += 1
            {
                if (y < h - 1 && w == .GRASS)
                {
                    c.blocks[dx][y][dz] = .DIRT
                }
                else
                {
                    c.blocks[dx][y][dz] = w
                }
            }
            if (w == .GRASS)
            {
                if (simplex2(f32(-x) * 0.1, f32(z) * 0.1, 4, 0.8, 2, seed) > 0.6)
                {
                    c.blocks[dx][h][dz] = .TALL_GRASS
                }
                if (simplex2(f32(x) * 0.05, f32(-z) * 0.05, 4, 0.8, 2, seed) > 0.7)
                {
                    c.blocks[dx][h][dz] = .ROSE
                }
                if (simplex2(f32(x) * 0.02, f32(-z) * 0.02, 4, 0.8, 2, seed) > 0.9)
                {
                    c.blocks[dx][h][dz] = .TORCH
                }
                ok := true
                if (dx - 4 < 0 || dz - 4 < 0 || dx + 4 >= CHUNK_SIZE || dz + 4 >= CHUNK_SIZE)
                {
                    ok = false
                }
                if (ok && simplex2(f32(x), f32(z), 6, 0.5, 2, seed) > 0.84)
                {
                    for y := h + 3; y < h + 8; y += 1
                    {
                        for ox := -3; ox <= 3; ox += 1
                        {
                            for oz := -3; oz <= 3; oz += 1
                            {
                                d := (ox * ox) + (oz * oz) + (y - (h + 4)) * (y - (h + 4))
                                if (d < 11)
                                {
                                    c.blocks[dx + ox][y][dz + oz] = .LEAVES
                                }
                            }
                        }
                    }
                    for y := h; y < h + 7; y += 1
                    {
                        c.blocks[dx][y][dz] = .WOOD
                    }
                }
            }
        }
    }
}

/*  chunk_destroy 

    Free the model associated with a chunk
*/
chunk_destroy:: proc (c: ^Chunk)
{
    if c.loaded
    {   
        for i: i32 = 0; i < c.model.meshCount; i += 1
        {
            rl.UnloadMesh(c.model.meshes[i])
        }
    }
}
