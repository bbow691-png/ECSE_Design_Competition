shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // Grabs the viewport pixels behind the ColorRect and smoothly samples them with blur
    COLOR = textureLod(screen_texture, SCREEN_UV, blur_amount);
}