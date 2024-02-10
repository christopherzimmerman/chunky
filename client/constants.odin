package cube

import rl "vendor:raylib"

/*  CHUNK_SIZE 

    The width of achunk along the x and z axes
*/
CHUNK_SIZE :: 16

/*  CHUNK_HEIGHT 

    The size of a chunk alone the y axis.  This
    is intentionally small, as chunks can be layered
    vertically along the y axis to avoid expensive
    rendering for small operations
*/
CHUNK_HEIGHT :: 64

/*  CHUNK_VOLUME 

    The maximum number of possible solid blocks in a chunk
*/
CHUNK_VOLUME :: CHUNK_SIZE * CHUNK_HEIGHT * CHUNK_SIZE

/*  CHUNK_MAX_VERTEX_COUNT 

    Maximum number of vertices that can appear in a chunk
*/
CHUNK_MAX_VERTEX_COUNT :: CHUNK_VOLUME * 36

/*  Face 

    Individual face on a single voxel
*/
Face :: enum u8
{
    FRONT,
    BACK,
    RIGHT,
    LEFT,
    TOP,
    BOTTOM,
}

/*  BLOCK_POSITION S

    A mapping of face positions to offsets when
    rendering textures for a single voxel
*/
BLOCK_POSITIONS: [][4]rl.Vector3 = {
    // front face
    {{0, 0, 1}, {1, 0, 1}, {1, 1, 1}, {0, 1, 1}},
    // back face
    {{1, 0, 0}, {0, 0, 0}, {0, 1, 0}, {1, 1, 0}},
    // right face
    {{1, 0, 1}, {1, 0, 0}, {1, 1, 0}, {1, 1, 1}},
    // left face
    {{0, 0, 0}, {0, 0, 1}, {0, 1, 1}, {0, 1, 0}},
    // top face
    {{0, 1, 1}, {1, 1, 1}, {1, 1, 0}, {0, 1, 0}},
    // bottom face
    {{0, 0, 0}, {1, 0, 0}, {1, 0, 1}, {0, 0, 1}},
}

/*  BLOCK_NORMALS 

    A mapping of face positions to normals for rendering
    a single voxel
*/
BLOCK_NORMALS: []rl.Vector3 = {
    // front face
    { 0.0, 0.0,-1.0},
    // back face
    { 0.0, 0.0, 1.0},
    // right face
    { 1.0, 0.0, 0.0},
    // left face
    {-1.0, 0.0, 0.0},
    // top face
    { 0.0, 1.0, 0.0},
    // bottom face
    { 0.0,-1.0, 0.0},
}

/*  BLOCK_TEXTURE_COORDINATES

    A mapping of faces to texture offsets for drawing
    vertices for a block face
*/
BLOCK_TEXTURE_COORDINATES: [][4]rl.Vector2 = {
    // front face
    {{0.0, 1.0}, {1.0, 1.0}, {1.0, 0.0}, {0.0, 0.0}},
    // back face
    {{0.0, 1.0}, {1.0, 1.0}, {1.0, 0.0}, {0.0, 0.0}},
    // right face
    {{0.0, 1.0}, {1.0, 1.0}, {1.0, 0.0}, {0.0, 0.0}},
    // left face
    {{1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}, {1.0, 0.0}},
    // top face
    {{0.0, 1.0}, {1.0, 1.0}, {1.0, 0.0}, {0.0, 0.0}},
    // bottom face
    {{0.0, 1.0}, {1.0, 1.0}, {1.0, 0.0}, {0.0, 0.0}},
}

/*  FACE_INDICES 

    A mapping of faces to offets within face configuration
    for rendering a voxel face
*/
FACE_INDICES := []int{0, 1, 2, 2, 3, 0}

/*  SPRITE_POSITIONS

    A mapping of faces to sprite positions for rendering
    a sprite face
*/
SPRITE_POSITIONS: [][4]rl.Vector3 = {
    {{0, 0, 0}, {1, 0, 1}, {1, 1, 1}, {0, 1, 0}},
    {{0, 0, 1}, {1, 0, 0}, {1, 1, 0}, {0, 1, 1}},
}

/*  SPRITE_TEXTURE_COORDINATES 

    A mapping of sprite faces to texture coordinates
    for drawing a single sprite face
*/
SPRITE_TEXTURE_COORDINATES: [][4]rl.Vector2 = {
    {{0.0, 1.0}, {1.0, 1.0}, {1.0, 0.0}, {0.0, 0.0}},
    {{1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}, {1.0, 0.0}},
}

/*  LIGHT_DIRECTIONS 

    Directions that light can spread from a node to
    another block
*/
LIGHT_DIRECTIONS: [6]Int_Vector3 = {
    {0, 0, +1},
    {0, 0, -1},
    {+1, 0, 0},
    {-1, 0, 0},
    {0, +1, 0},
    {0, -1, 0},
}

/*  LIGHT_DIRECTIONS_X_CHUNK 

    Directions that light can spread from a node to
    another block, scaled by the size of a chunk
*/
LIGHT_DIRECTIONS_X_CHUNK: [6]Int_Vector3 = {
    {0, 0, +CHUNK_SIZE},
    {0, 0, -CHUNK_SIZE},
    {+CHUNK_SIZE, 0, 0},
    {-CHUNK_SIZE, 0, 0},
    {0, +CHUNK_HEIGHT, 0},
    {0, -CHUNK_HEIGHT, 0},
}

/*  WORLD_DAY_LENGTH_SECONDS 

    Time for a complete day/night cycle to complete
*/
WORLD_DAY_LENGTH_SECONDS :: 24 * 60