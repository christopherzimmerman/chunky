package cube

import "core:math/noise"

/*  simplex2 

    Basic simplex noise, chosen over perlin noise
    due to the lower computational overhead
*/
simplex2 :: proc (x, y: f32, octaves: int, persistence: f32, lacunarity: f32, seed: i64) -> f32
{
    freq: f32 = 1
    amp: f32 = 1
    max: f32 = 1
    total: f32 = noise.noise_2d(seed, {f64(x), f64(y)})
    for i := 1; i < octaves; i += 1
    {
        freq *= lacunarity
        amp *= persistence
        max += amp
        total += noise.noise_2d(seed, {f64(x * freq), f64(y * freq)}) * amp
    }
    return (1 + total / max) / 2
}