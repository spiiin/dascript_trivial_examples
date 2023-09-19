require glfw/glfw_boost
require dasbgfx/bgfx_boost
require daslib/defer
require daslib/math_boost
require daslib/safe_addr

var [[in]] a_position : float3
var [[in]] a_color0 : float4
var [[in]] a_texcoord0 : float2
var [[inout, semantics=POSITION1]] v_pos : float4
var [[inout]] v_color0 : float4
var [[inout]] v_texcoord0 : float2
var [[uniform]] v_ortho : float4x4

var [[uniform, stage=0]] s_texColor0 : sampler2D
var [[uniform, stage=1]] s_texColor1 : sampler2D

[bgfx_vertex_program]
def vs_main
    v_color0 = a_color0
    gl_Position = v_ortho * float4(a_position, 1.0)
    v_pos = gl_Position

[bgfx_fragment_program]
def fs_main
    var color = v_color0
    let depth = v_pos.z/v_pos.w
    color.xyz *= color.w
    let weight = color.w * clamp(0.03 / (1e-5 + pow(depth, 5.0) ), 0.01, 3000.0)
    gl_FragData[0] = color * weight
    gl_FragData[1] = color.wwww

[bgfx_vertex_buffer]
struct Vertex
    position : float3
    color0 : float4

let vertices = [[Vertex
    position=float3(-0.3, 0.7, 0.0), color0=float4(0.0 ,0.0 ,1.0, 0.75);
    position=float3( 0.7,-0.3, 0.0), color0=float4(0.0, 0.0, 1.0, 0.75);
    position=float3( 0.7, 0.7, 0.0), color0=float4(0.0, 0.0, 1.0, 0.75);
    position=float3(-0.3,-0.3, 0.0), color0=float4(0.0, 0.0, 1.0, 0.57);

    position=float3(-0.5, 0.5, -20.0), color0=float4(1.0 ,1.0 ,0.0, 0.75);
    position=float3( 0.5,-0.5, -20.0), color0=float4(1.0 ,1.0 ,0.0, 0.75);
    position=float3( 0.5, 0.5, -20.0), color0=float4(1.0 ,1.0 ,0.0, 0.75);
    position=float3(-0.5,-0.5, -20.0), color0=float4(1.0 ,1.0 ,0.0, 0.75);

    position=float3(-0.7, 0.3, -40.0), color0=float4(1.0 ,0.0 ,0.0, 0.75);
    position=float3( 0.3,-0.7, -40.0), color0=float4(1.0 ,0.0 ,0.0, 0.75);
    position=float3( 0.3, 0.3, -40.0), color0=float4(1.0 ,0.0 ,0.0, 0.75);
    position=float3(-0.7,-0.7, -40.0), color0=float4(1.0 ,0.0 ,0.0, 0.75)
]]
let indices = [[int 0;1;2;3;1;0; 4;5;6;7;5;4; 8;9;10;11;9;8]]


[bgfx_vertex_program]
def vs_quad
    v_texcoord0 = a_texcoord0
    gl_Position = v_ortho * float4(a_position, 1.0)

[bgfx_fragment_program]
def fs_quad
    let accum   = texture2D(s_texColor0, v_texcoord0)
    let opacity = texture2D(s_texColor1, v_texcoord0).x
    gl_FragColor  = float4(accum.xyz / clamp(accum.w, 1e-4, 5e4), opacity)

[bgfx_vertex_buffer]
struct VertexTex
    position : float3
    color0 : float4
    [[type=FLOAT, size=2, semantics=TEXCOORD0, normalized=false, as_int=false]] uv : float2

let vertices_quad = [[VertexTex
    position=float3(-1.0, 1.0, 0.0), color0=float4(1.0, 1.0, 1.0, 1.0), uv = float2(0.0, 1.0);
    position=float3( 1.0,-1.0, 0.0), color0=float4(1.0, 1.0, 1.0, 1.0), uv = float2(1.0, 0.0);
    position=float3( 1.0, 1.0, 0.0), color0=float4(1.0, 1.0, 1.0, 1.0), uv = float2(1.0, 1.0);
    position=float3(-1.0,-1.0, 0.0), color0=float4(1.0, 1.0, 1.0, 1.0), uv = float2(0.0, 0.0)
]]
let indices_quad = [[int 0;1;2;3;1;0]]

[export]
def main
    if glfwInit()==0
        panic("can't init glfw")
    defer <|
        glfwTerminate()
    glfwWindowHint(int(GLFW_CLIENT_API), GLFW_NO_API)
    var window = glfwCreateWindow(1280, 720, "BGFX", null, null)
    if window==null
        panic("can't create window")
    defer <|
        glfwDestroyWindow(window)

    var pd: bgfx_platform_data_s
    pd.nwh = glfwGetNativeWindow(window)
    bgfx_set_platform_data(safe_addr(pd))
    bgfx_init(1280, 720)
    glfwSetWindowTitle(window, "BGFX - Hello Weighted-OIT - {bgfx_get_renderer_type()}")

    var fb_textures = [[auto 
        bgfx_create_texture_2d(1280u, 720u, false, 1u, bgfx_texture_format RGBA16F, BGFX_TEXTURE_RT, null);
        bgfx_create_texture_2d(1280u, 720u, false, 1u, bgfx_texture_format R16F, BGFX_TEXTURE_RT, null)
    ]]
    var fbh = bgfx_create_frame_buffer_from_handles(2u, safe_addr(fb_textures),true)

    var pcvl_decl = bgfx_create_vertex_layout(type<Vertex>)
    var vbh = bgfx_create_vertex_buffer(bgfx_make_ref(vertices), safe_addr(pcvl_decl), BGFX_BUFFER_NONE)
    var ibh = bgfx_create_index_buffer(bgfx_make_ref(indices), BGFX_BUFFER_INDEX32)

    var pcvlt_decl = bgfx_create_vertex_layout(type<VertexTex>)
    var vbh_quad = bgfx_create_vertex_buffer(bgfx_make_ref(vertices_quad), safe_addr(pcvlt_decl), BGFX_BUFFER_NONE)
    var ibh_quad = bgfx_create_index_buffer(bgfx_make_ref(indices_quad), BGFX_BUFFER_INDEX32)

    var program = bgfx_create_shader_program(@@vs_main, @@fs_main)
    var program_quad = bgfx_create_shader_program(@@vs_quad, @@fs_quad)

    v_ortho = bgfx_mat_ortho(-1.,1.,-1.,1.,-100.,100.,0.,bgfx_get_caps().homogeneousDepth,false)

    let pal0 = [[float 0.0; 0.0; 0.0; 0.0]]
    let pal1 = [[float 1.0; 1.0; 1.0; 1.0]]

    var display_w, display_h : int
    glfwGetWindowSize(window, safe_addr(display_w), safe_addr(display_h))
    bgfx_reset(uint(display_w), uint(display_h), BGFX_RESET_VSYNC, bgfx_texture_format COUNT)
    bgfx_set_view_rect(0u, 0u, 0u, uint(display_w), uint(display_h))
    bgfx_set_view_rect(1u, 0u, 0u, uint(display_w), uint(display_h))

    while glfwWindowShouldClose(window)==0
        glfwPollEvents()

        bgfx_set_view_frame_buffer(0u, fbh)
        bgfx_set_palette_color(0u, safe_addr(pal0))
        bgfx_set_palette_color(1u, safe_addr(pal1))
        bgfx_set_view_clear_mrt(0u , BGFX_CLEAR_COLOR|BGFX_CLEAR_DEPTH, 1.0f, 0u, 0u, 1u, 0u, 0u, 0u, 0u, 0u, 0u)

        //1. render to rt
        bgfx_set_vertex_buffer(0u, vbh)
        bgfx_set_index_buffer(ibh)
        vs_main_bind_uniform()
        fs_main_bind_uniform()
        var stateNoDepth = ( uint64(0)
            | BGFX_STATE_CULL_CW
            | BGFX_STATE_WRITE_RGB
            | BGFX_STATE_WRITE_A
            | BGFX_STATE_DEPTH_TEST_ALWAYS
            | BGFX_STATE_MSAA
        )
        bgfx_set_state(
            stateNoDepth | BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_ONE, BGFX_STATE_BLEND_ONE) | BGFX_STATE_BLEND_INDEPENDENT,
            uint(BGFX_STATE_BLEND_ZERO >> uint64(BGFX_STATE_BLEND_SHIFT) | (BGFX_STATE_BLEND_SRC_COLOR >> uint64(BGFX_STATE_BLEND_SHIFT) << uint64(4))) //separate blendState for RT1
        )
        bgfx_submit(0u, program, 1u, BGFX_DISCARD_NONE)

        //2. blend rts
        s_texColor0 := fb_textures[0]
        s_texColor1 := fb_textures[1]
        bgfx_set_vertex_buffer(0u, vbh_quad)
        bgfx_set_index_buffer(ibh_quad)
        vs_quad_bind_uniform()
        fs_quad_bind_uniform()
        bgfx_set_view_clear(1u, BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH, RGBA_TO_BGFX_UCOLOR(0.75, 0.75, 0.75, 1.0), 1.0f, 0u)
        bgfx_set_state(BGFX_STATE_WRITE_RGB | BGFX_STATE_BLEND_FUNC(BGFX_STATE_BLEND_INV_SRC_ALPHA, BGFX_STATE_BLEND_SRC_ALPHA), 0u)
        bgfx_submit(1u, program_quad, 1u, BGFX_DISCARD_NONE)

        bgfx_frame(true)
    bgfx_shutdown()

