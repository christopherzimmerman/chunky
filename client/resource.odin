package cube

import rl "vendor:raylib"

/*  resource_load_image

    Load an image into raylib from a file name
*/
resource_load_image :: proc (file_name: cstring) -> rl.Image
{
    image: rl.Image = rl.LoadImage(file_name)
    return image
}

/*  resource_load_texture 

    Load a block atlas texture from a file name
*/
resource_load_texture :: proc (file_name: cstring) -> rl.Texture2D
{
    image: rl.Image = resource_load_image(file_name)
    defer rl.UnloadImage(image)
    texture: rl.Texture2D = rl.LoadTextureFromImage(image)
    return texture
}