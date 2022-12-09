package main;
// main :: proc () {
//     if sdl2.Init( sdl2.INIT_VIDEO ) < 0 {
//         fmt.printf( "SDL could not initialize! SDL_Error: %s\n", sdl2.GetError() );
//         return;
//     }
//     window := sdl2.CreateWindow("LBPE", 
//         sdl2.WINDOWPOS_UNDEFINED,	sdl2.WINDOWPOS_UNDEFINED, 
//         NATIVE_WIDTH * RES_MULTIPLIER, 
//         NATIVE_HEIGHT * RES_MULTIPLIER, 
//         sdl2.WINDOW_SHOWN );
//     if window == nil {
//         fmt.printf( "Window could not be created! SDL_Error: %s\n", sdl2.GetError());
//         return ;
//     };
    // render_surface := sdl2.GetWindowSurface(window);
    // working_surface := make_working_surface(render_surface)
    // preview_surface := make_working_surface(working_surface);
    // quit := false 

//     pal1 := [4]u32{0xCBF1F5, 0x445975, 0x0E0F21, 0x050314}

//     new_lbp := LimitedPaletteImage(4){}
//     init_lpi(&new_lbp, &pal1, {cast(u32)NATIVE_WIDTH, cast(u32)NATIVE_HEIGHT})

//     for x, idx in &new_lbp.pixels {
//         x = 0b01010101
//     }

    // using ge := GlobalEverything {
    //     working_lbp = &new_lbp,
    //     points_to_draw = make([dynamic]PointToDraw),
    //     brush_size = 1,
    //     click_status = {.Left = {pal_idx = 0}, .Right = {pal_idx = 3}},
    // }

//     for quit == false {
        // defer {
        //     for ptd in ge.points_to_draw {
        //         set_pixel_4(ptd.pt, ptd.pal, ge.working_lbp)
        //     }
        //     clear(&ge.points_to_draw)
        // };

//         frameStart := sdl2.GetTicks(); ge.frame_counter += 1;
//         event:sdl2.Event;

//         defer PREV_PT = MOUSE_PT
//         for cs in &click_status {
//             if .Clicked in cs.prev_status {
//                 cs.held = true;
//             } 
//             cs.prev_status = cs.now_status;
//             cs.now_status = {}
//         }
//         for( sdl2.PollEvent( &event ) != false ){

//             if event.type == .QUIT {quit = true;break;};
//             if event.type == .KEYDOWN {
//                 #partial switch event.key.keysym.sym {
//                     case .NUM1: ge.draw_mode = .Pencil
//                     case .NUM2: ge.draw_mode = .Line
//                     case .NUM3: ge.draw_mode = .Fill
//                 }
//                 if event.key.keysym.sym == .F1 {
//                     pal1 = swizzle(pal1, 3, 0, 1, 2)
//                 }
//                 if event.key.keysym.sym == .F2 {
//                     ge.click_status[.Left].pal_idx += 1
//                     ge.click_status[.Left].pal_idx %= 4

//                     ge.click_status[.Right].pal_idx += 1
//                     ge.click_status[.Right].pal_idx %= 4
//                 }
//                 if event.key.keysym.sym == .F3 {
//                     // for x in 0..=3 {
//                     //     set_pixel_4({cast(i32)x,4}, RIGHT_COLOUR, &new_lbp)
//                     // }
//                     draw_line_immediate(&new_lbp, click_status[.Right].pal_idx, {0,0}, {25,25})
//                     draw_line_immediate(&new_lbp, click_status[.Right].pal_idx, {0,1}, {25,26})
//                 }
//                 if event.key.keysym.sym == .LEFTBRACKET {
//                     brush_size = max(1, brush_size - 1)
//                 }
//                 if event.key.keysym.sym == .RIGHTBRACKET {
//                     brush_size = max(brush_size, brush_size + 1)
//                 }
//             }
//             if event.type == .MOUSEMOTION {
//                 MOUSE_PT = {event.motion.x / RES_MULTIPLIER, event.motion.y / RES_MULTIPLIER}
//             }
//             poll_clickstatus :: proc (cs:^ClickStatus, event:^sdl2.Event) {
//                 #partial switch event.type {
//                     case .MOUSEMOTION:
//                         cs.now_status += {.Moved};
//                     case .MOUSEBUTTONDOWN:
//                         cs.now_status += {.Clicked};
//                     case .MOUSEBUTTONUP:
//                         cs.now_status += {.Released};
//                         cs.held = false;
//                 }
//             }
//             if event.button.button == sdl2.BUTTON_LEFT {
//                 poll_clickstatus(&click_status[.Left], &event)
//             }
//             if event.button.button == sdl2.BUTTON_RIGHT {
//                 poll_clickstatus(&click_status[.Right], &event)
//             }
        
//         };

//         do_click_actions :: proc (using ge:^GlobalEverything) {

//             for cs, idx in ge.click_status {
//                 switch draw_mode {
//                     case .Pencil: 
//                         if !(.Clicked in cs.now_status || cs.held) {
//                             for pt in make_square(MOUSE_PT, brush_size) do checked_pt_append(&ge.preview_points, ge.working_lbp, pt, ge.click_status[.Left].pal_idx);
//                             break;
//                         }
//                         sloice := make_square(PREV_PT, brush_size);
//                         vec := MOUSE_PT - PREV_PT  
//                         if (vec != [2]i32{0,0}) {
//                             for pt in sloice do draw_line_returned(&points_to_draw, working_lbp, cs.pal_idx, pt, vec)
//                             break;
//                         } 
//                         for pt in sloice do checked_pt_append(&points_to_draw, working_lbp, pt, cs.pal_idx)
//                     case .Line: 
//                         if ge.stored_point == nil {
//                             if .Clicked in cs.now_status {
//                                 ge.stored_point = MOUSE_PT
//                                 ge.which_click_drawing = WhichClick(idx);
//                                 break;
//                             }
//                             for pt in make_square(MOUSE_PT, brush_size) do checked_pt_append(&ge.preview_points, ge.working_lbp, pt, ge.click_status[.Left].pal_idx);
//                             break;
//                         }
//                         if .Clicked in cs.now_status {
//                             if MOUSE_PT - ge.stored_point.([2]i32) == {0,0} do break;
//                             sloice := make_square(ge.stored_point.([2]i32), brush_size);  
//                             vec := MOUSE_PT - ge.stored_point.([2]i32)
//                             for pt in sloice {
//                                 draw_line_immediate(working_lbp, cs.pal_idx, pt, vec)
//                             }
//                             ge.stored_point, ge.which_click_drawing = nil, nil;
//                             break;
//                         }
//                         vec := MOUSE_PT - ge.stored_point.([2]i32)
//                         _enum := ge.which_click_drawing.(WhichClick)
//                         for pt in make_square(ge.stored_point.([2]i32), brush_size) {
//                             draw_line_returned(&ge.preview_points, working_lbp, ge.click_status[_enum].pal_idx, pt, vec)
//                         }
//                     case .Fill: 
//                         FillMode :: enum {
//                             Unconditional,
//                             Isolated,
//                         }
//                         mode := FillMode.Isolated
//                         if .Clicked not_in cs.now_status do break;
//                         switch mode {
//                             case .Unconditional:
//                                 colour_to_replace := get_pixel_4(MOUSE_PT, ge.working_lbp)
//                                 _replace_colour_lpi4(ge.working_lbp, colour_to_replace, cs.pal_idx)
//                             case .Isolated:
//                                 colour_to_replace := get_pixel_4(MOUSE_PT, ge.working_lbp)
//                                 flood_fill(MOUSE_PT, ge.working_lbp, colour_to_replace, cs.pal_idx)
//                         }

                        
//                 };
//             }
//         }

//         do_click_actions(&ge)

//         write_to_buffer_lpi4(&pal1, ge.working_lbp, cast([^]u32)working_surface.pixels)

//         if len(ge.preview_points) > 0 {
//             mptr := cast([^]u32)working_surface.pixels
//             pal := ge.working_lbp.suggested_palette
//             for ptd in ge.preview_points {
//                 idx := point_to_idx(working_surface, ptd.pt)
//                 preview_colour := pal[ptd.pal]
//                 mptr[idx] = sdl2.MapRGB(working_surface.format,RedOf(preview_colour),GreenOf(preview_colour),BlueOf(preview_colour));
//             }
//             clear(&ge.preview_points)
//         } 
//         sdl2.BlitScaled(working_surface, nil, render_surface, nil);
    
//         sdl2.UpdateWindowSurface(window);
//         // frameTime := sdl2.GetTicks() - frameStart;
//         // if FRAME_DURATION > frameTime do sdl2.Delay(FRAME_DURATION - frameTime);
//     }
// };

