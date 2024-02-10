package cube

import "core:math"
import rl "vendor:raylib"

Int_Vector3 :: distinct [3]int

/*  matrix_rotate_y 

    Rotate a matrix based on a given angle,
    only along the y axis
*/
matrix_rotate_y :: proc (angle: f32) -> rl.Matrix
{
    result: rl.Matrix = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    }


    cosres := math.cos(angle)
    sinres := math.sin(angle)

    result[0, 0] = cosres
    result[2, 0] = -sinres
    result[0, 2] = sinres
    result[2, 2] = cosres

    return result
}

/*  matrix_transform 

    Compute the matrix transform vector
    from a providex vector and matrix
*/
matrix_transform :: proc (v: rl.Vector3, mat: rl.Matrix) -> rl.Vector3
{
    result: rl.Vector3
    x := v.x
    y := v.y
    z := v.z

    result.x = mat[0, 0] * x + mat[0, 1] * y + mat[0, 2] * z + mat[0, 3]
    result.y = mat[1, 0] * x + mat[1, 1] * y + mat[1, 2] * z + mat[1, 3]
    result.z = mat[2, 0] * x + mat[2, 1] * z + mat[2, 2] * z + mat[2, 3]

    return result
}