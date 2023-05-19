package vector_graphics

import "core:fmt"
import mu "vendor:microui"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

MAX_QUADS :: 8192

atlas_as_rgba :: proc() -> (result: [len(mu.default_atlas_alpha) * 4]u8) {
    for i in 0 ..< len(mu.default_atlas_alpha) {
        result[i * 4 + 0] = 255
        result[i * 4 + 1] = 255
        result[i * 4 + 2] = 255
        result[i * 4 + 3] = mu.default_atlas_alpha[i]
    }
    return
}

atlas := atlas_as_rgba()

atlas_id: u32
shader_id: u32
uniforms: gl.Uniforms

Vertex :: struct {
    position: [2]f32,
    uv: [2]f32,
    color: [4]f32,
}

State :: struct {
    translation: [2]f32,
    clip_pos: [2]f32,
    clip_size: [2]f32,
    color: [4]f32,
}

Context :: struct {
    size: [2]int,
    write_index: int,
    vao: u32,
    vbo: u32,
    ebo: u32,
    vertices: [MAX_QUADS * 4]Vertex,
    indices: [MAX_QUADS * 6]u16,
    state: State,
    saved_states: [dynamic]State,
}

init :: proc() {
    compiled_ok: bool
    shader_id, compiled_ok = gl.load_shaders_source(VERTEX_SOURCE, FRAGMENT_SOURCE)
	if !compiled_ok {
		fmt.eprintln("Failed to compile shader.")
		return
	}
    gl.UseProgram(shader_id)

    uniforms = gl.get_uniforms_from_program(shader_id)

    gl.GenTextures(1, &atlas_id)
    gl.BindTexture(gl.TEXTURE_2D, atlas_id)
    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT,
        0,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        &atlas[0],
    )
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
}

shutdown :: proc() {
    gl.DeleteTextures(1, &atlas_id)
    gl.DeleteProgram(shader_id)
    delete(uniforms)
}

create :: proc() -> ^Context {
    ctx := new(Context)

    gl.GenVertexArrays(1, &ctx.vao)
    gl.GenBuffers(1, &ctx.vbo)
    gl.GenBuffers(1, &ctx.ebo)

    gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vbo)
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, position))
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))
    gl.VertexAttribPointer(2, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, color))

    reserve(&ctx.saved_states, 256)

    return ctx
}

destroy :: proc(ctx: ^Context) {
    gl.DeleteVertexArrays(1, &ctx.vao)
    gl.DeleteBuffers(1, &ctx.vbo)
    gl.DeleteBuffers(1, &ctx.ebo)
    delete(ctx.saved_states)
    free(ctx)
}

begin_frame :: proc(ctx: ^Context, size: [2]int) {
    ctx.size = size

    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.Disable(gl.CULL_FACE)
    gl.Disable(gl.DEPTH_TEST)
    gl.Enable(gl.SCISSOR_TEST)
    gl.Enable(gl.TEXTURE_2D)

    gl.Viewport(0, 0, i32(size.x), i32(size.y))
    gl.Scissor(0, 0, i32(size.x), i32(size.y))

    ctx.state = State{
        clip_size = {f32(size.x), f32(size.y)},
    }
}

end_frame :: proc(ctx: ^Context) {
    _flush(ctx)
    clear(&ctx.saved_states)
}

save :: proc(ctx: ^Context) {
    append(&ctx.saved_states, ctx.state)
}

restore :: proc(ctx: ^Context) {
    last_index := len(ctx.saved_states) - 1
    if last_index < 0 {
        fmt.eprintln("Warning: vector_graphics restore was called while no more saved states were left.")
        return
    }
    ctx.state = ctx.saved_states[last_index]
    _flush(ctx)
    _raw_clip(ctx, ctx.state.clip_pos, ctx.state.clip_size)
    resize(&ctx.saved_states, last_index)
}

translate :: proc(ctx: ^Context, amount: [2]f32) {
    ctx.state.translation += amount
}

rect :: proc(ctx: ^Context, pos, size: [2]f32) {
    color := ctx.state.color
    uv_pos, uv_size := _mu_rect_to_f32(mu.default_atlas[mu.DEFAULT_ATLAS_WHITE])
    _push_quad(ctx, pos, size, uv_pos, uv_size, color)
}

text :: proc(ctx: ^Context, text: string, pos: [2]f32) {
    pos := pos
    color := ctx.state.color
    for c in text {
        if c & 0xc0 == 0x80 {
            continue
        }
        chr := min(int(c), 127)
        uv_pos, uv_size := _mu_rect_to_f32(mu.default_atlas[mu.DEFAULT_ATLAS_FONT + chr])
        _push_quad(ctx, pos, uv_size, uv_pos, uv_size, color)
        pos.x += uv_size.x
    }
}

text_width :: proc(ctx: ^Context, text: string) -> (result: int) {
    for c in text {
        if c & 0xc0 == 0x80 {
            continue
        }
        chr := min(int(c), 127)
        result += int(mu.default_atlas[mu.DEFAULT_ATLAS_FONT + chr].w)
    }
    return
}

text_height :: proc(ctx: ^Context) -> int {
    return 18
}

set_color :: proc(ctx: ^Context, color: [4]f32) {
    ctx.state.color = color
}

reset_clip :: proc(ctx: ^Context) {
    ctx.state.clip_pos = 0
    ctx.state.clip_size = {f32(ctx.size.x), f32(ctx.size.y)}
    _raw_clip(ctx, ctx.state.clip_pos, ctx.state.clip_size)
}

clip :: proc(ctx: ^Context, pos, size: [2]f32) {
    _flush(ctx)

    old_pos := ctx.state.clip_pos
    old_pos_br := old_pos + ctx.state.clip_size
    pos_br := pos + size

    pos_intersect: [2]f32
    pos_intersect.x = max(pos.x, old_pos.x)
    pos_intersect.y = max(pos.y, old_pos.y)

    pos_intersect_br: [2]f32
    pos_intersect_br.x = min(pos_br.x, old_pos_br.x)
    pos_intersect_br.y = min(pos_br.y, old_pos_br.y)

    size_intersect: [2]f32
    size_intersect.x = max(0, pos_intersect_br.x - pos_intersect.x)
    size_intersect.y = max(0, pos_intersect_br.y - pos_intersect.y)

    ctx.state.clip_pos = pos_intersect
    ctx.state.clip_size = size_intersect

    _raw_clip(ctx, ctx.state.clip_pos, ctx.state.clip_size)
}

_raw_clip :: proc(ctx: ^Context, pos, size: [2]f32) {
    pos := pos + ctx.state.translation
    gl.Scissor(i32(pos.x), i32(ctx.size.y) - i32(pos.y + size.y), i32(size.x), i32(size.y))
}

_push_quad :: proc(ctx: ^Context, pos, size, uv_pos, uv_size: [2]f32, color: [4]f32) {
    if ctx.write_index == MAX_QUADS {
        _flush(ctx)
    }

    pos := pos + ctx.state.translation

    pos_left := pos.x
    pos_right := pos_left + size.x
    pos_top := pos.y
    pos_bottom := pos_top + size.y

    tex_left := uv_pos.x / f32(mu.DEFAULT_ATLAS_WIDTH)
    tex_right := tex_left + uv_size.x / f32(mu.DEFAULT_ATLAS_WIDTH)
    tex_top := uv_pos.y / f32(mu.DEFAULT_ATLAS_WIDTH)
    tex_bottom := tex_top + uv_size.y / f32(mu.DEFAULT_ATLAS_WIDTH)

    v_tl := Vertex{
        position = {pos_left, pos_top},
        uv = {tex_left, tex_top},
        color = color,
    }
    v_tr := Vertex{
        position = {pos_right, pos_top},
        uv = {tex_right, tex_top},
        color = color,
    }
    v_bl := Vertex{
        position = {pos_left, pos_bottom},
        uv = {tex_left, tex_bottom},
        color = color,
    }
    v_br := Vertex{
        position = {pos_right, pos_bottom},
        uv = {tex_right, tex_bottom},
        color = color,
    }

    vertex_index := ctx.write_index * 4
    index_index := ctx.write_index * 6

    ctx.vertices[vertex_index + 0] = v_tl
    ctx.vertices[vertex_index + 1] = v_tr
    ctx.vertices[vertex_index + 2] = v_bl
    ctx.vertices[vertex_index + 3] = v_br

    ctx.indices[index_index + 0] = u16(vertex_index + 0)
    ctx.indices[index_index + 1] = u16(vertex_index + 1)
    ctx.indices[index_index + 2] = u16(vertex_index + 2)
    ctx.indices[index_index + 3] = u16(vertex_index + 2)
    ctx.indices[index_index + 4] = u16(vertex_index + 3)
    ctx.indices[index_index + 5] = u16(vertex_index + 1)

    ctx.write_index += 1
}

_flush :: proc(ctx: ^Context) {
    if ctx.write_index == 0 {
        return
    }

    gl.UseProgram(shader_id)
    gl.BindTexture(gl.TEXTURE_2D, atlas_id)
    gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vbo)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.ebo)

    gl.BufferData(gl.ARRAY_BUFFER, ctx.write_index * 4 * size_of(ctx.vertices[0]), &ctx.vertices[0], gl.DYNAMIC_DRAW)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, ctx.write_index * 6 * size_of(ctx.indices[0]), &ctx.indices[0], gl.DYNAMIC_DRAW)

    projection_matrix := glm.mat4Ortho3d(0.0, f32(ctx.size.x), f32(ctx.size.y), 0.0, -1.0, 1.0)
    gl.UniformMatrix4fv(uniforms["ProjMtx"].location, 1, false, &projection_matrix[0, 0])

    gl.DrawElements(gl.TRIANGLES, i32(ctx.write_index * 6), gl.UNSIGNED_SHORT, nil)

    ctx.write_index = 0
}

_mu_rect_to_f32 :: proc(rect: mu.Rect) -> ([2]f32, [2]f32) {
    return {f32(rect.x), f32(rect.y)}, {f32(rect.w), f32(rect.h)}
}

VERTEX_SOURCE :: `#version 330 core
uniform mat4 ProjMtx;
layout(location=0) in vec2 Position;
layout(location=1) in vec2 UV;
layout(location=2) in vec4 Color;
out vec2 Frag_UV;
out vec4 Frag_Color;
void main() {
    Frag_UV = UV;
    Frag_Color = Color;
    gl_Position = ProjMtx * vec4(Position.xy, 0, 1);
}
`

FRAGMENT_SOURCE :: `#version 330 core
uniform sampler2D Texture;
in vec2 Frag_UV;
in vec4 Frag_Color;
out vec4 Out_Color;
void main() {
    Out_Color = Frag_Color * texture(Texture, Frag_UV.st);
}
`