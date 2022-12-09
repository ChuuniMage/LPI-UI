package LPI;

import "vendor:sdl2";

RedOf :: #force_inline proc (hexRGB888:u32) -> u8 {return u8(hexRGB888 >> 16) & 255}
GreenOf :: #force_inline proc (hexRGB888:u32) -> u8 {return u8(hexRGB888 >> 8) & 255}
BlueOf :: #force_inline proc (hexRGB888:u32) -> u8 {return u8(hexRGB888 & 255)}

point_to_idx :: proc (w:i32, pt:[2]i32) -> i32 {return pt.x + (w*pt.y)}

blacken_surf :: proc (surf:^sdl2.Surface) {
    mptr := cast([^]u32)surf.pixels
    for x in 0..<surf.w do for y in 0..<surf.h {
        idx := point_to_idx(surf.w, {x,y})
        mptr[idx] = sdl2.MapRGB(surf.format,0,0,0)
    }
}

transparentify_surf :: proc (surf:^sdl2.Surface) {
    mptr := cast([^]u32)surf.pixels
    for x in 0..<surf.w do for y in 0..<surf.h {
        idx := point_to_idx(surf.w, {x,y})
        mptr[idx] = 0x00000000
    }
}

plot_line :: proc (lpi:^LimitedPaletteImage(4), set_idx: u8, last:[2]i32, current:[2]i32) {
    x0 := last.x
    y0 := last.y;
    x1 := current.x;
    y1 := current.y;

    dx := abs(x1-x0);
    sx : i32 = x0<x1 ? 1 : -1;
    dy := -abs(y1-y0);
    sy : i32 = y0<y1 ? 1 : -1;
    err := dx+dy;  /* error value e_xy */
    for {
        set_pixel_4([2]i32{x0, y0}, set_idx, lpi)
        if (x0 == x1 && y0 == y1){
            break;
        }
           
        e2 := 2*err;
        if (e2 >= dy) {
            err += dy;
            x0 += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y0 += sy;
        }
    }
}

PointToDraw :: struct {
    pt:[2]i32,
    pal:u8,
}

draw_line_returned :: proc (dynarr:^[dynamic]PointToDraw, lpi:^LimitedPaletteImage(4), set_idx: u8, origin:[2]i32, vec:[2]i32) {
    if vec == {0,0} do return;
	x_greater := abs(vec.x) > abs(vec.y) 
	greater := x_greater ? vec.x : vec.y
	lesser := x_greater ? vec.y : vec.x

    negative_half_selected := vec.y > 0 ? vec.x + vec.y < 0 : vec.x + vec.y <= 0
    neg_half_factor : i32 = negative_half_selected ? -1 : 1
    
	for i in cast(i32)0..=abs(greater){
		lesser_axis_position:f32 = f32(lesser * i) / f32(greater)
		whole := i32(lesser_axis_position)
		fract := lesser_axis_position - f32(whole)

		lesser_offset  := abs(fract) > 0.5  ? (fract > 0 ? whole + 1 : whole - 1) : whole
        lesser_offset  *= neg_half_factor
        
		greater_offset := i 
        greater_offset *= neg_half_factor

        x_offset := x_greater ? greater_offset : lesser_offset
		y_offset := x_greater ? lesser_offset : greater_offset
        checked_pt_append(dynarr, lpi, {origin.x + x_offset, origin.y + y_offset}, set_idx)
	}
}

draw_line_immediate :: proc (lpi:^LimitedPaletteImage(4), set_idx: u8, origin:[2]i32, vec:[2]i32) {
    if vec == {0,0} do return;
	x_greater := abs(vec.x) > abs(vec.y) 
	greater := x_greater ? vec.x : vec.y
	lesser := x_greater ? vec.y : vec.x

    negative_half_selected := vec.y > 0 ? vec.x + vec.y < 0 : vec.x + vec.y <= 0
    neg_half_factor : i32 = negative_half_selected ? -1 : 1
    
	for i in cast(i32)0..=abs(greater){
		lesser_axis_position:f32 = f32(lesser * i) / f32(greater)
		whole := i32(lesser_axis_position)
		fract := lesser_axis_position - f32(whole)

		lesser_offset  := abs(fract) > 0.5  ? (fract > 0 ? whole + 1 : whole - 1) : whole
        lesser_offset  *= neg_half_factor
        
		greater_offset := i 
        greater_offset *= neg_half_factor

        x_offset := x_greater ? greater_offset : lesser_offset
		y_offset := x_greater ? lesser_offset : greater_offset
        set_pixel_4({origin.x + x_offset, origin.y + y_offset}, set_idx, lpi)
	}
}

import "core:fmt"

checked_pt_append :: proc (dynarr:^[dynamic]PointToDraw, lpi:^LimitedPaletteImage(4),  new_pt:[2]i32, pal:u8) {
    if !validate_point(lpi, new_pt) do return
    append(dynarr, PointToDraw{new_pt, pal})
}

make_square :: proc (pt:[2]i32, sq:int) -> [][2]i32 {
    new_slice := make([dynamic][2]i32, context.temp_allocator);
    for x in 0..<sq do for y in 0..<sq {
        // fmt.printf("Origin %v, x it %v y it %v apending %v \n", pt, x, y, pt + {cast(i32)x, cast(i32)y})
        append(&new_slice, pt + {cast(i32)x, cast(i32)y})
    }
    // fmt.printf("---\n")
    return new_slice[:]
}