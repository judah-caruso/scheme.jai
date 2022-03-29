#scope_export

// A structure containing the colors and title of a scheme
Scheme :: struct {
   title : string;
   c0    : Scheme_Color;
   c1    : Scheme_Color;
   c2    : Scheme_Color;
   c3    : Scheme_Color;
   c4    : Scheme_Color;
   c5    : Scheme_Color;
   c6    : Scheme_Color;
   c7    : Scheme_Color;

   #place c0;
   palette: [8]Scheme_Color = ---;
}

// A structure containing color values in the range of [0, 255]
Scheme_Color :: struct {
   b: u8;
   g: u8;
   r: u8;

   #place b;
   #as values: [3]u8 = ---;

   #place b;
   #as rgb: u32 = ---;
}

// Parses an SVG scheme file into a 'Scheme' struct
read_scheme :: (source: string, allocator := context.allocator) -> Scheme, ok: bool, error: string {
   scheme: Scheme;
   scheme.title = DEFAULT_TITLE;

   tag, value, found := find_tag(*source, "title");
   if found {
      push_allocator(allocator);
      scheme.title = copy_string(value);
   }

   tag, value, found = find_tag(*source, "style");
   if !found {
      return scheme, false, "Unable to find 'style' tag"; 
   }

   styles := *value;
   while styles.count > 0 {
      // Find the next id: #XXX { ... }
      skip_past(styles, #char "#");

      color_id := <<styles;
      color_id.count = 2;

      index := 0;
      if color_id == {
         case "c0"; index = 0;
         case "c1"; index = 1;
         case "c2"; index = 2;
         case "c3"; index = 3;
         case "c4"; index = 4;
         case "c5"; index = 5;
         case "c6"; index = 6;
         case "c7"; index = 7;

         case; // Skip IDs we don't care about
            styles.count -= 2;
            styles.data  += 2;
            if styles.count <= 0 break;
            continue;
      }

      fill_start := find_index_from_left(<<styles, "fill");
      if fill_start == -1 {
         return .{}, false, tprint("Expected fill property for #%", color_id);
      }

      styles.count -= fill_start;
      styles.data  += fill_start;

      // Skip to start of color
      skip_past(styles, #char ":");

      // Skip to end of color
      color_value := <<styles;
      color_value.count = skip_past(styles, #char ";");

      color_value = trim(color_value);

      if contains(color_value, "rgb") {
         scheme.palette[index] = from_rgb_string(color_value);
      }
      else if contains(color_value, "hsv") {
         scheme.palette[index] = from_hsv_string(color_value);
      }
      else if color_value[0] == #char "#" {
         scheme.palette[index] = from_hex_string(color_value);
      }
      else {
         return .{}, false, tprint("Invalid fill value for #% (%)", color_id, color_value);
      }
   }

   return scheme, true, "";
}

// Takes a parsed scheme and turns it into a valid SVG scheme file
export_scheme :: (scheme: Scheme, allocator := context.allocator) -> string {
   builder: String_Builder;
   builder.allocator = allocator;
   defer free_buffers(*builder);

   print_to_builder(*builder,
      SCHEME_TEMPLATE,

      scheme.title,
      to_hex(scheme.c0),
      to_hex(scheme.c1),
      to_hex(scheme.c2),
      to_hex(scheme.c3),
      to_hex(scheme.c4),
      to_hex(scheme.c5),
      to_hex(scheme.c6),
      to_hex(scheme.c7)
   );

   return builder_to_string(*builder);
}

// Helpful utilities

// Returning a FormatInt leads to... interesting results when printed to a builder.
// Until it doesn't, this will return a formatted string using the temp allocator.

// Converts a Scheme_Color to its hex (#RRGGBB) representation.
to_hex :: (rgb: type_of(Scheme_Color.rgb)) -> string {
   hex := tprint("#%", formatInt(rgb, base = 16, minimum_digits = 6));
   to_upper_in_place(hex);
   return hex;
}

to_hex :: (color: Scheme_Color) -> string {
   return to_hex(color.rgb);
}

// Converts an RGB string (in the format of 'rgb(RR, GG, BB)') to aScheme_Color 
from_rgb_string :: (rgb_str: string) -> Scheme_Color, ok: bool {
   str := rgb_str;

   prefix := str;
   prefix.count = skip_past(*str, #char "(");
   if trim(prefix) != "rgb" return .{}, false;

   red_str := str;
   red_str.count = skip_past(*str, #char ",");

   green_str := str;
   green_str.count = skip_past(*str, #char ",");

   blue_str := str;
   blue_str.count = skip_past(*str, #char ")");

   red, r_ok := string_to_int(red_str);
   if !r_ok return .{}, false;

   red = clamp(red, 0, 255);

   green, g_ok := string_to_int(green_str);
   if !g_ok return .{}, false;

   green = clamp(green, 0, 255);

   blue, b_ok := string_to_int(blue_str);
   if !b_ok return .{}, false;

   blue = clamp(blue, 0, 255);

   color : Scheme_Color = ---;
   color.r = cast(u8)red;
   color.g = cast(u8)green;
   color.b = cast(u8)blue;

   return color, true;
}

// Converts a hex string (in the format of '#RRGGBB') to aScheme_Color 
from_hex_string :: (hex_str: string) -> Scheme_Color, ok: bool {
   str := hex_str;
   skip_past(*str, #char "#");

   raw_color, ok := string_to_int(str, base = 16);
   if !ok return .{}, false;

   color: Scheme_Color = ---;
   color.r = cast(u8)((raw_color & 0xFF0000) >> 16);
   color.g = cast(u8)((raw_color & 0x00FF00) >> 8);
   color.b = cast(u8)((raw_color & 0x0000FF));

   return color, true;
}

// Converts an HSV string (in the format of 'hsv(HH, SS, VV)') to aScheme_Color 
from_hsv_string :: (hsv_str: string) -> Scheme_Color, ok: bool {
   str := hsv_str;

   prefix := str;
   prefix.count = skip_past(*str, #char "(");
   if trim(prefix) != "hsv" return .{}, false;

   hue_str := str;
   hue_str.count = skip_past(*str, #char ",");

   sat_str := str;
   sat_str.count = skip_past(*str, #char ",");

   val_str := str;
   val_str.count = skip_past(*str, #char ")");

   hue, h_ok := string_to_float(hue_str);
   if !h_ok return .{}, false;

   hue = clamp(hue, 0, 360) / 360;

   sat, s_ok := string_to_float(sat_str);
   if !s_ok return .{}, false;

   sat = clamp(sat, 0, 100) / 100;

   val, v_ok := string_to_float(val_str);
   if !v_ok return .{}, false;

   val = clamp(val, 0, 100) / 100;

   r, g, b := (hue: float, sat: float, val: float) -> float, float, float {
       fract :: inline (x) => x - floor(x);

       px := abs(fract(hue + 1)       * 6 - 3) - 1;
       py := abs(fract(hue + 2 / 3.0) * 6 - 3) - 1;
       pz := abs(fract(hue + 1 / 3.0) * 6 - 3) - 1;

       Clamp(*px, 0, 1);
       Clamp(*py, 0, 1);
       Clamp(*pz, 0, 1);

       px = lerp(1, px, sat);
       py = lerp(1, py, sat);
       pz = lerp(1, pz, sat);
       
       return val * px, val * py, val * pz;
   }(hue, sat, val);

   color: Scheme_Color = ---;
   color.r = cast(u8)(r * 255);
   color.g = cast(u8)(g * 255);
   color.b = cast(u8)(b * 255);

   return color, true;
}

#scope_file

DEFAULT_TITLE :: "Color Scheme by Person";

SCHEME_TEMPLATE :: #string XXX
<svg width="288px" height="140px" xmlns="http://www.w3.org/2000/svg" baseProfile="full" version="1.1">
   <title>%1</title>
   <style>
      #c0 { fill: %2; } <!-- Background -->
      #c1 { fill: %3; } <!-- Foreground, Operators --> 
      #c2 { fill: %4; } <!-- Types --> 
      #c3 { fill: %5; } <!-- Procedures, Keywords --> 
      #c4 { fill: %6; } <!-- Constants, Strings -->
      #c5 { fill: %7; } <!-- Pre-Processor, Special -->
      #c6 { fill: %8; } <!-- Errors -->
      #c7 { fill: %9; } <!-- Comments --> 
   </style>

   <rect width="288" height="140" id="c0"></rect>   
   <text x="10" y="20" style="font-family: monospace" id="c1">      <tspan x="10">Point :: <tspan id="c2">struct</tspan> { x, y: <tspan id="c2">float</tspan>; }</tspan><tspan x="10" dy="2em"><tspan id="c3">main</tspan> :: () {</tspan><tspan x="25" dy="1em" id="c7">// This is a comment</tspan><tspan x="25" dy="1em">point := <tspan id="c2">Point</tspan>.{ <tspan id="c4">10</tspan>, <tspan id="c4">20</tspan> };</tspan><tspan x="25" dy="1em">print(<tspan id="c4">"Point: &#37;<tspan id="c5">\n</tspan>"</tspan>, point);</tspan><tspan x="10" dy="1em">}</tspan><tspan x="10" dy="2em"><tspan id="c5">#import</tspan> <tspan id="c4">"Basic"</tspan>;</tspan>
</text>
</svg>
XXX;

Valid_Tag :: enum {
   None;
   Title;
   Style;
}

find_tag :: (source: *string, name: string) -> type: Valid_Tag, value: string, found: bool {
   find_opening_tag :: inline (source: *string) -> index: int {
      for 0..source.count - 1 {
         if source.data[it] == #char "<" {
            // skip over comments
            if it < source.count - 1 && source.data[it + 1] == #char "!" {
               continue;
            }

            source.data  += it + 1;
            source.count -= it + 1;
            return it;
         }
      }

      return 0;
   }

   while source.count > 0 {
      find_opening_tag(source);

      capture := <<source;
      capture.count = skip_past(source, #char ">");

      // Not the right tag
      if capture != name continue;

      value := <<source;
      value.count = find_opening_tag(source);

      if name == {
         case "title";
            return .Title, value, true;
         case "style";
            return .Style, value, true;
         case;
            return .None, "", false;
      }
   }

   return .None, "", false;
}

skip_past :: inline (str: *string, chr: u8) -> int {
   for 0..str.count - 1 {
      if str.data[it] == chr {
         str.data  += it + 1;
         str.count -= it + 1;
         return it;
      }
   }

   return 0;
}

#import "Basic";
#import "String";
#import "Math";
