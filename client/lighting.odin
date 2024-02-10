package cube

import "core:container/queue"
import "core:fmt"

LIGHT_ADD_QUEUE: queue.Queue(Light_Node)
LIGHT_DEL_QUEUE: queue.Queue(Light_Del_Node)

// The entire approach in this file was pulled verbatim from a fantastic reddit post by
// DubstepCoder, and can be found here:
// https://www.reddit.com/r/gamedev/comments/2iru8i/fast_flood_fill_lighting_in_a_blocky_voxel_game/
// I would highly recommend reading through all of his work if you want to experiment with
// something similar, it was an easy approach to implement

/*  Light_Node 

    A node representing a light value that can
    propogate to other nodes
*/
Light_Node :: struct
{
    index: Int_Vector3,
    chunk: ^Chunk,
}

/*  Light_Del_Node 

    A node representing the removal of a light value,
    where the ensuing darkness will spread to other
    nodes
*/
Light_Del_Node :: struct
{
    index: Int_Vector3,
    val: int,
    chunk: ^Chunk,
}

/*  chunk_light_queue_add 

    Add a node to the light queue for light propogation
*/
chunk_light_queue_add :: proc (index: Int_Vector3, chunk: ^Chunk)
{
    node: Light_Node
    node.index = index
    node.chunk = chunk
    queue.push_back(&LIGHT_ADD_QUEUE, node)
}

/*  chunk_light_del_queue_add 

    Add a node to the light queue for darkness propogation
*/
chunk_light_del_queue_add :: proc (index: Int_Vector3, val: int, chunk: ^Chunk)
{
    node: Light_Del_Node
    node.index = index
    node.val = val
    node.chunk = chunk
    queue.push_back(&LIGHT_DEL_QUEUE, node)
}

/*  chunk_get_light 

    Find the current light/sunlight at given chunk coordinates
*/
chunk_get_light :: proc (chunk: ^Chunk, position: Int_Vector3, sunlight: bool = false) -> u8
{
    if (!chunk_in_bounds(position.x, position.y, position.z))
    {
        return 15
    }
    if (sunlight)
    {
        return chunk.sunlight[position.x][position.y][position.z]
    }
    else
    {
        return chunk.lights[position.x][position.y][position.z]
    }
}

/*  chunk_set_light 

    Set light/sunlight at given chunk coordinates.  This has to be called
    before propogation happens or uniformity is not guaranteed
*/
chunk_set_light :: proc (chunk: ^Chunk, position: Int_Vector3, level: u8, sunlight: bool = false)
{
    if (!chunk_in_bounds(position.x, position.y, position.z)) { return }
    if (sunlight)
    {
        chunk.sunlight[position.x][position.y][position.z] = level
    }
    else
    {
        chunk.lights[position.x][position.y][position.z] = level
    }
}

/*  chunk_compute_light_sources 

    Find any light-emitting blocks in a chunk and ensure
    that they are added to the queue for propogation
*/
chunk_compute_light_sources :: proc (chunk: ^Chunk)
{
    if (chunk == nil) { return }
    for x := 0; x < CHUNK_SIZE; x += 1
    {
        for y := 0; y < CHUNK_HEIGHT; y += 1
        {
            for z := 0; z < CHUNK_SIZE; z += 1
            {
                block: Block_Type = chunk.blocks[x][y][z]
                if (!block_emits_light(block)) { continue }
                chunk_set_light(chunk, {x, y, z}, 15, false)
                chunk_light_queue_add({x, y, z}, chunk)
            }
        }
    }
    chunk_spread_light(false)
}

/*  chunk_compute_sunlight 

    Calculate sunlight within a chunk.  Right now, since chunks do not
    stack vertically, this is easy and I just find the transparent block with
    the lowest Y-value to propogate downwards to avoid unnecessary spread
*/
chunk_compute_sunlight :: proc (chunk: ^Chunk)
{
    if (chunk == nil) { return }
    for x := 0; x < CHUNK_SIZE; x += 1
    {
        for z := 0; z < CHUNK_SIZE; z += 1
        {
            for y := CHUNK_HEIGHT - 1; y >= 0; y -= 1
            {
                block: Block_Type = chunk.blocks[x][y][z]
                if (!block_is_opaque(block))
                {
                    chunk_set_light(chunk, {x, y, z}, 15, true)
                    chunk_light_queue_add({x, y, z}, chunk)
                }
                else
                {
                    break
                }
            }

        }
    }
    chunk_spread_light(true)
}

/*  chunk_spread_light 

    Spread light from light sources outwards, sunlight expands
    infinitely downwards while other light will only expand
    to a maximum of 15 blocks
*/
chunk_spread_light :: proc (sunlight: bool = false)
{
    limit: int = 20000
    for queue.len(LIGHT_ADD_QUEUE) > 0 && limit > 0
    {
        limit -= 1
        node := queue.pop_front(&LIGHT_ADD_QUEUE)
        index := node.index
        chunk := node.chunk

        if (chunk == nil) { continue }
        light_level := chunk_get_light(chunk, index, sunlight)

        for face in Face
        {
            next_index := index + LIGHT_DIRECTIONS[face]
            next_chunk := chunk
            if (!chunk_in_bounds(next_index.x, next_index.y, next_index.z))
            {
                neighbor := Int_Vector3{chunk.x, chunk.y, chunk.z} + LIGHT_DIRECTIONS[face]
                if (!(neighbor in chunk.world.chunks)) { continue }
                next_chunk = &chunk.world.chunks[neighbor]
                next_index -= LIGHT_DIRECTIONS_X_CHUNK[face]
            }
            next_light := chunk_get_light(next_chunk, next_index, sunlight)
            if (block_is_opaque(next_chunk.blocks[next_index.x][next_index.y][next_index.z])) { continue }
            sub_val: u8 = 1
            if (face == .BOTTOM && sunlight)
            {
                sub_val = 0
            }
            if (next_light + 1 + sub_val <= light_level)
            {
                chunk_set_light(next_chunk, next_index, light_level - sub_val, sunlight)
                chunk_light_queue_add(next_index, next_chunk)
            }
        }
    }
}