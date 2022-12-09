package main;
//BIG NOTE
//SDL colour format: ARGB
//OPENGL COLOUR FORMAT: ABGR

open_glify_colour :: proc (col:u32) -> u32 {
    colour := transmute([4]u8)col
    colour[3] = 0xFF;
    new_colour := transmute(u32)swizzle(colour, 2, 1, 0, 3)
    return new_colour
}

import "core:fmt"
import "core:os"
import "core:slice"
import "core:reflect"

import "core:mem";
import "core:log";
import "core:strings";
import "core:runtime";
import "core:odin/parser"
import "core:odin/ast"
import "core:odin/tokenizer"

import sdl "vendor:sdl2";
import gl  "vendor:OpenGL";

import imgui "odin-imgui";
import imgl  "odin-imgui/impl/opengl";
import imsdl "odin-imgui/impl/sdl";

enum_filename :: "enum.odin"
package_name :: "main"

DESIRED_GL_MAJOR_VERSION :: 4;
DESIRED_GL_MINOR_VERSION :: 5;

import "vendor:glfw"
import "core:image/png"

import "vendor:sdl2";
import "core:math"
import "LPI";

NATIVE_WIDTH   : i32 : 320
NATIVE_HEIGHT  : i32 : 200

RES_MULTIPLIER : i32: 1

FPS :: 60;
FRAME_DURATION :: 1000 / FPS;

MOUSE_PT := [2]i32{}
PREV_PT := [2]i32{}


make_working_surface :: #force_inline proc (render_surface:^sdl2.Surface) -> ^sdl2.Surface {
    return sdl2.CreateRGBSurface(0, 
        NATIVE_WIDTH, NATIVE_HEIGHT, 
        i32(render_surface.format.BitsPerPixel), u32(render_surface.format.Rmask), 
        render_surface.format.Gmask, render_surface.format.Bmask, render_surface.format.Amask);
}

PROFILING :: false
import "core:time"
when PROFILING {
    profiling_ms := make([dynamic]f64)

    profile_start :: proc () -> time.Tick {
        OLD_TIME := time.tick_now()
        return OLD_TIME
    }
    profile_end :: proc (OLD_TIME:time.Tick) -> (time_in_milliseconds:f64) {
        new := time.tick_now()
        diff := time.tick_diff(OLD_TIME, new)
        time_in_milliseconds = time.duration_milliseconds(diff)
        fmt.printf("--- Diff: %v \n", time_in_milliseconds)
        return
    }
} 

DrawMode :: enum {
    Pencil,
    Line,
    Fill,
}

WhichClick :: enum {
    Left,
    Right,
}

MousePerFrameStatus :: enum {
    Clicked,
    Released,
    Moved,
}

ClickStatus :: struct {
    prev_status:bit_set[MousePerFrameStatus],
    now_status:bit_set[MousePerFrameStatus],
    held:bool,
    pal_idx:u8,
}

GlobalEverything :: struct {
    draw_mode: DrawMode,
    brush_size: int,
    frame_counter:u64,
    working_lbp : ^LPI.LimitedPaletteImage(4),
    points_to_draw : [dynamic]LPI.PointToDraw,
    preview_points : [dynamic]LPI.PointToDraw,
    stored_point:Maybe([2]i32),
    click_status:[WhichClick]ClickStatus,
    which_click_drawing:Maybe(WhichClick),
}


Texture :: distinct u32

create_texture :: proc(path: string) -> Texture {
  texture: u32
  gl.GenTextures(1, &texture)
  gl.BindTexture(gl.TEXTURE_2D, texture)
    
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

  img, err := png.load_from_file(path, {.alpha_add_if_missing})
  fmt.println(err)
  defer png.destroy(img)
  gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(img.width), i32(img.height), 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(img.pixels.buf))
  return Texture(texture)
}

create_texture_from_lpi :: proc(lpi: ^LPI.LimitedPaletteImage(4)) -> Texture {
    texture: u32
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
      
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    buff := make([^]u32, lpi.dims.x * lpi.dims.y); defer free(&buff);
    pal := lpi.suggested_palette
    LPI.write_to_buffer_lpi4(&pal, lpi, buff)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(lpi.dims.x), i32(lpi.dims.y), 0, gl.RGBA, gl.UNSIGNED_BYTE, rawptr(buff))
    return Texture(texture)
}

create_texture_from_surface :: proc(surf: ^sdl2.Surface) -> Texture {
    texture: u32
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
      
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(surf.w), i32(surf.h), 0, gl.RGBA, gl.UNSIGNED_BYTE, rawptr(surf.pixels))
    return Texture(texture)
}

update_texture :: proc (dims:^[2]u32, buffptr:rawptr, tex:Maybe(Texture) = nil) {
    if tex != nil {
        gl.BindTexture(gl.TEXTURE_2D, cast(u32)tex.(Texture))
    }
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, i32(dims.x), i32(dims.y), 0, gl.RGBA, gl.UNSIGNED_BYTE, buffptr)
}

destroy_texture :: proc(texture: ^Texture) {
  gl.DeleteTextures(1, cast(^u32)texture)
}

main :: proc() {
    logger_opts := log.Options {
        .Level,
        .Line,
        .Procedure,
    };
    context.logger = log.create_console_logger(opt = logger_opts);

    log.info("Starting SDL Example...");
    init_err := sdl.Init({.VIDEO});
    defer sdl.Quit();
    if init_err != 0 {
        log.debugf("Error during SDL init: (%d)%s", init_err, sdl.GetError());
        return
    }

    log.info("Setting up the window...");
    window := sdl.CreateWindow("odin-imgui SDL+OpenGL example", 100, 100, 1280, 720, { .OPENGL, .MOUSE_FOCUS, .SHOWN, .RESIZABLE});
    if window == nil {
        log.debugf("Error during window creation: %s", sdl.GetError());
        sdl.Quit();
        return;
    }
    defer sdl.DestroyWindow(window);

    log.info("Setting up the OpenGL...");
    sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, DESIRED_GL_MAJOR_VERSION);
    sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, DESIRED_GL_MINOR_VERSION);
    sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GLprofile.CORE));
    sdl.GL_SetAttribute(.DOUBLEBUFFER, 1);
    sdl.GL_SetAttribute(.DEPTH_SIZE, 24);
    sdl.GL_SetAttribute(.STENCIL_SIZE, 8);
    gl_ctx := sdl.GL_CreateContext(window);
    if gl_ctx == nil {
        log.debugf("Error during window creation: %s", sdl.GetError()); 
        return;
    }
    sdl.GL_MakeCurrent(window, gl_ctx);
    defer sdl.GL_DeleteContext(gl_ctx);
    if sdl.GL_SetSwapInterval(1) != 0 {
        log.debugf("Error during window creation: %s", sdl.GetError());
        return;
    }
    gl.load_up_to(DESIRED_GL_MAJOR_VERSION, DESIRED_GL_MINOR_VERSION, sdl.gl_set_proc_address);
    gl.ClearColor(0.25, 0.25, 0.25, 1);

    imgui_state := init_imgui_state(window);

    running := true;
    show_demo_window := false;
    event := sdl.Event{};
    tex_id := create_texture("test.png")
    @static rawbuff : [320*200]u32
    for e in &rawbuff {
        e = 0x445975
    }
    fmt.printf("8 digits %8x", rawbuff[0])

    pal1 := [4]u32{0xCBF1F5, 0x445975, 0x0E0F21, 0x050314}


    new_lpi := LPI.LimitedPaletteImage(4){}
    LPI_dims := [2]u32{cast(u32)NATIVE_WIDTH, cast(u32)NATIVE_HEIGHT}
    swizzled := pal1; 
    for x in &swizzled do x = open_glify_colour(x);
    fmt.printf("Before swiz: %8x. After: %8x \n", pal1[1], swizzled[1])
    LPI.init_lpi(&new_lpi, &swizzled, LPI_dims)
    RENDER_BUFF := make([^]u32, NATIVE_WIDTH * NATIVE_HEIGHT); 

    for x, idx in &new_lpi.pixels {
        x = 0b01010101
    }

    LPI.write_to_buffer_lpi4(&swizzled, &new_lpi, RENDER_BUFF)

    lpi_tex := create_texture_from_lpi(&new_lpi)

    using ge := GlobalEverything {
        working_lbp = &new_lpi,
        points_to_draw = make([dynamic]LPI.PointToDraw),
        brush_size = 1,
        click_status = {.Left = {pal_idx = 0}, .Right = {pal_idx = 3}},
    }

    for running {
        defer {
            for ptd in ge.points_to_draw {
                LPI.set_pixel_4(ptd.pt, ptd.pal, ge.working_lbp)
            }
            clear(&ge.points_to_draw)
        };
        defer PREV_PT = MOUSE_PT

        for cs in &click_status {
            if .Clicked in cs.prev_status {
                cs.held = true;
            } 
            cs.prev_status = cs.now_status;
            cs.now_status = {}
        }

        for sdl.PollEvent(&event) {
            imsdl.process_event(event, &imgui_state.sdl_state);

            #partial switch event.type {
                case .QUIT:
                    log.info("Got SDL_QUIT event!");
                    running = false;
                case .KEYDOWN: #partial switch event.key.keysym.sym {
                    case .ESCAPE: sdl.PushEvent(&sdl.Event{type = .QUIT});
                    case .TAB: if imgui.get_io().want_capture_keyboard == false do show_demo_window = true;
                    case .F1: 
                        fmt.printf("Attempted write to texture \n")
                        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 320, 200, 0, gl.RGBA, gl.UNSIGNED_BYTE, &rawbuff)
                        fmt.printf("After attempted write to texture \n")
                    case .F2:
                        for e in &rawbuff {
                            e = 0xFF755944
                        }
                    }
                    #partial switch event.key.keysym.sym {
                        case .NUM1: ge.draw_mode = .Pencil
                        case .NUM2: ge.draw_mode = .Line
                        case .NUM3: ge.draw_mode = .Fill
                    }
                    if event.key.keysym.sym == .F3 {
                        // for x in 0..=3 {
                        //     set_pixel_4({cast(i32)x,4}, RIGHT_COLOUR, &new_lbp)
                        // }
                        LPI.draw_line_immediate(&new_lpi, click_status[.Right].pal_idx, {0,0}, {25,25})
                        LPI.draw_line_immediate(&new_lpi, click_status[.Right].pal_idx, {0,1}, {25,26})
                    }
                    if event.key.keysym.sym == .LEFTBRACKET {
                        brush_size = max(1, brush_size - 1)
                    }
                    if event.key.keysym.sym == .RIGHTBRACKET {
                        brush_size = max(brush_size, brush_size + 1)
                    }
            }
            if event.type == .MOUSEMOTION {
                // UPDATE_MOUSE = true
                // MOUSE_PT = {event.motion.x / RES_MULTIPLIER, event.motion.y / RES_MULTIPLIER}
            }
            poll_clickstatus :: proc (cs:^ClickStatus, event:^sdl2.Event) {
                #partial switch event.type {
                    case .MOUSEMOTION:
                        cs.now_status += {.Moved};
                    case .MOUSEBUTTONDOWN:
                        cs.now_status += {.Clicked};
                    case .MOUSEBUTTONUP:
                        cs.now_status += {.Released};
                        cs.held = false;
                }
            }
            if event.button.button == sdl2.BUTTON_LEFT {
                poll_clickstatus(&click_status[.Left], &event)
            }
            if event.button.button == sdl2.BUTTON_RIGHT {
                poll_clickstatus(&click_status[.Right], &event)
                if .Clicked in click_status[.Left].now_status && .Clicked in click_status[.Right].now_status {
                    click_status[.Right].now_status = {};
                }
                if click_status[.Left].held == true && click_status[.Right].held == true {
                    click_status[.Right].held = false
                }
            }
        }
        do_click_actions :: proc (using ge:^GlobalEverything) {
            if MOUSE_PT.x >= NATIVE_WIDTH || MOUSE_PT.y >= NATIVE_HEIGHT do return;
            if MOUSE_PT.x < 0 || MOUSE_PT.y < 0 do return;
            // fmt.printf("Input mouse pt %v \n", MOUSE_PT)
            for cs, idx in ge.click_status {
                switch draw_mode {
                    case .Pencil: 
                        if !(.Clicked in cs.now_status || cs.held) {
                            for pt in LPI.make_square(MOUSE_PT, brush_size) do LPI.checked_pt_append(&ge.preview_points, ge.working_lbp, pt, ge.click_status[.Left].pal_idx);
                            break;
                        }
                        sloice := LPI.make_square(PREV_PT, brush_size);
                        vec := MOUSE_PT - PREV_PT  
                        if (vec != [2]i32{0,0}) {
                            for pt in sloice do LPI.draw_line_returned(&points_to_draw, working_lbp, cs.pal_idx, pt, vec)
                            break;
                        } 
                        for pt in sloice do LPI.checked_pt_append(&points_to_draw, working_lbp, pt, cs.pal_idx)
                    case .Line: 
                        if ge.stored_point == nil {
                            if .Clicked in cs.now_status {
                                ge.stored_point = MOUSE_PT
                                ge.which_click_drawing = WhichClick(idx);
                                break;
                            }
                            for pt in LPI.make_square(MOUSE_PT, brush_size) do LPI.checked_pt_append(&ge.preview_points, ge.working_lbp, pt, ge.click_status[.Left].pal_idx);
                            break;
                        }
                        if .Clicked in cs.now_status {
                            if MOUSE_PT - ge.stored_point.([2]i32) == {0,0} do break;
                            sloice := LPI.make_square(ge.stored_point.([2]i32), brush_size);  
                            vec := MOUSE_PT - ge.stored_point.([2]i32)
                            for pt in sloice {
                                LPI.draw_line_immediate(working_lbp, cs.pal_idx, pt, vec)
                            }
                            ge.stored_point, ge.which_click_drawing = nil, nil;
                            break;
                        }
                        vec := MOUSE_PT - ge.stored_point.([2]i32)
                        _enum := ge.which_click_drawing.(WhichClick)
                        for pt in LPI.make_square(ge.stored_point.([2]i32), brush_size) {
                            LPI.draw_line_returned(&ge.preview_points, working_lbp, ge.click_status[_enum].pal_idx, pt, vec)
                        }
                    case .Fill: 
                        FillMode :: enum {
                            Unconditional,
                            Isolated,
                        }
                        mode := FillMode.Isolated
                        if .Clicked not_in cs.now_status do break;
                        switch mode {
                            case .Unconditional:
                                colour_to_replace := LPI.get_pixel_4(MOUSE_PT, ge.working_lbp)
                                LPI._replace_colour_lpi4(ge.working_lbp, colour_to_replace, cs.pal_idx)
                            case .Isolated:
                                colour_to_replace := LPI.get_pixel_4(MOUSE_PT, ge.working_lbp)
                                LPI.flood_fill_stack(MOUSE_PT, ge.working_lbp, colour_to_replace, cs.pal_idx)
                        }
                };
            }
        }

        imgui_new_frame(window, &imgui_state);
        imgui.new_frame();

        if imgui.begin_main_menu_bar() {
            if imgui.begin_menu("File") {
                imgui.text("Open...");
                imgui.text("Save...");
                imgui.text("Save As...");
                imgui.text("Exit...");
                imgui.end_menu();
            }
            if imgui.begin_menu("Options") {
                imgui.text("Foo");
                imgui.end_menu();
            }
            // imgui.begin_menu("Options"); imgui.end_menu();
            imgui.end_main_menu_bar()
        }


        colour_to_float :: proc (col:u8) -> f32 {
            return (cast(f32)col / 256) 
        }

        colour_to_imgui_v4 :: proc (col:u32) -> imgui.Vec4 {
            colours := transmute([4]u8)col
            _vec4 := slice.mapper(colours[:], colour_to_float)
            imguiVec4 := imgui.Vec4 {
                x = _vec4[0],
                y = _vec4[1],
                z = _vec4[2],
                w = _vec4[3],
            }
            return imguiVec4
        }

        MODE_UI: {
            imgui.begin("Mode UI");
            imgui.text("Click Colours")
            for elem, idx in click_status {
                colour := swizzled[elem.pal_idx]
                v4 := colour_to_imgui_v4(colour)
                imgui.color_button(fmt.tprintf("##click_colour_%v",idx), v4)
                
                if cast(int)idx != len(click_status)-1 do imgui.same_line()
            }
            imgui.text("Palette: "); imgui.same_line();
            for elem, idx in swizzled {
                imguiVec4 := colour_to_imgui_v4(elem)
                imgui.color_button(fmt.tprintf("##pal_%v",idx), imguiVec4) 
                if imgui.is_item_hovered() {
                    if .Clicked in click_status[.Left].now_status {
                        click_status[.Left].pal_idx = cast(u8)idx;
                    }
                    if .Clicked in click_status[.Right].now_status {
                        click_status[.Right].pal_idx = cast(u8)idx;
                    }
                }
                if idx != len(swizzled)-1 do imgui.same_line()
            }
            for elem in DrawMode {
                if imgui.button(reflect.enum_string(elem)) {
                    draw_mode = elem
                }
                if draw_mode == elem {
                    imgui.same_line()
                    imgui.text("SELECTED")
                }
            }
            imgui.end();
        }

        EDITED_IMAGE_GOES_HERE: {
            @static image_flags := imgui.Window_Flags.None
            imgui.begin("image in here", nil, image_flags, )
            if imgui.is_item_hovered() {
                image_flags = imgui.Window_Flags.None
            } else {
                image_flags = imgui.Window_Flags.NoMove
            }
            imgui.image(imgui.Texture_ID(uintptr(lpi_tex)), {320, 200})
            window_pos := imgui.get_window_pos()
            vec := imgui.Vec2{}
            imgui.get_mouse_pos(&vec)
            item_rect := imgui.Vec2{};
            imgui.get_item_rect_min(&item_rect)
            MOUSE_PT = [2]i32{cast(i32)(vec.x - item_rect.x), cast(i32)(vec.y - item_rect.y)}
            
            // vec2pos := imgui.Vec2{}
            // // imgui.get_item_rect_min(&vec2pos)
            // // fmt.printf("Item rect pos is %v \n", vec2pos)
            // dl := imgui.get_window_draw_list();
            // margin_offset := [2]f32{7,8}
            // image_dims := [2]f32{320,200}
            // imgui.draw_list_add_image(dl, imgui.Texture_ID(uintptr(tex_id)), transmute(imgui.Vec2)margin_offset, transmute(imgui.Vec2)(image_dims + margin_offset) )
            // imgui.set_cursor_pos({0,0});
            // imgui.invisible_button("Image", {320, 200})
            imgui.end();
        }

        do_click_actions(&ge)
        LPI.write_to_buffer_lpi4(&swizzled, ge.working_lbp, RENDER_BUFF)

        if len(ge.preview_points) > 0 {
            mptr := RENDER_BUFF
            pal := ge.working_lbp.suggested_palette
            for ptd in ge.preview_points {
                idx := LPI.point_to_idx(cast(i32)LPI_dims.x, ptd.pt)
                preview_colour := pal[ptd.pal]
                mptr[idx] = preview_colour
            }
            clear(&ge.preview_points)
        }

        update_texture(&LPI_dims, RENDER_BUFF)

        info_overlay();

        if show_demo_window do imgui.show_demo_window(&show_demo_window);
        
        imgui.render();

        io := imgui.get_io();
        gl.Viewport(0, 0, i32(io.display_size.x), i32(io.display_size.y));
        gl.Scissor(0, 0, i32(io.display_size.x), i32(io.display_size.y));
        gl.Clear(gl.COLOR_BUFFER_BIT);
        imgl.imgui_render(imgui.get_draw_data(), imgui_state.opengl_state);
        sdl.GL_SwapWindow(window);
    }
    log.info("Shutting down...");

}

info_overlay :: proc() {
    imgui.set_next_window_pos(imgui.Vec2{10, 25});
    imgui.set_next_window_bg_alpha(0.2);
    overlay_flags: imgui.Window_Flags = .NoDecoration | 
                                        .AlwaysAutoResize | 
                                        .NoSavedSettings | 
                                        .NoFocusOnAppearing | 
                                        .NoNav | 
                                        .NoMove;
    imgui.begin("Info", nil, overlay_flags);
    imgui.text_unformatted("Press Esc to close the application");
    imgui.text_unformatted("Press Tab to show demo window");
    imgui.end();
}

Imgui_State :: struct {
    sdl_state: imsdl.SDL_State,
    opengl_state: imgl.OpenGL_State,
}

init_imgui_state :: proc(window: ^sdl.Window) -> Imgui_State {
    using res := Imgui_State{};

    imgui.create_context();
    imgui.style_colors_dark();

    imsdl.setup_state(&res.sdl_state);
    
    imgl.setup_state(&res.opengl_state);

    return res;
}

imgui_new_frame :: proc(window: ^sdl.Window, state: ^Imgui_State) {
    imsdl.update_display_size(window);
    imsdl.update_mouse(&state.sdl_state, window);
    imsdl.update_dt(&state.sdl_state);
}
