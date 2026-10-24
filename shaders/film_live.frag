#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_temperature;
uniform float u_saturation;
uniform float u_contrast;
uniform float u_brightness;
uniform float u_shadow_lift;
uniform float u_tint_strength;
uniform float u_red_gamma;
uniform float u_green_gamma;
uniform float u_blue_gamma;
uniform vec3 u_highlight_tint;
uniform vec3 u_shadow_tint;
uniform float u_grain;
uniform float u_grain_size;
uniform float u_vignette;
uniform float u_halation;
uniform vec3 u_color_matrix_row_0;
uniform vec3 u_color_matrix_row_1;
uniform vec3 u_color_matrix_row_2;

uniform sampler2D u_input;

out vec4 frag_color;

float hash_noise(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float contrast_curve(float x, float contrast) {
  x = clamp(x, 0.0, 1.4);
  if (contrast >= 0.0) {
    float curve = x < 0.5 ? 2.0 * x * x : 1.0 - 2.0 * (1.0 - x) * (1.0 - x);
    return mix(x, curve, clamp(contrast, 0.0, 1.0));
  }
  return 0.5 + (x - 0.5) * (1.0 + clamp(contrast, -1.0, 0.0));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec3 color = texture(u_input, uv).rgb;

  float luma0 = dot(color, vec3(0.299, 0.587, 0.114));
  float temp = u_temperature * (24.0 / 255.0) * (1.0 - luma0 * luma0);
  color.r += temp;
  color.g += temp * 0.18;
  color.b -= temp;

  color = clamp(color, 0.0, 1.0);
  color = vec3(
    pow(color.r, u_red_gamma),
    pow(color.g, u_green_gamma),
    pow(color.b, u_blue_gamma)
  );
  color = clamp(vec3(
    dot(color, u_color_matrix_row_0),
    dot(color, u_color_matrix_row_1),
    dot(color, u_color_matrix_row_2)
  ), 0.0, 1.0);

  float luma = dot(color, vec3(0.299, 0.587, 0.114));
  color = mix(vec3(luma), color, u_saturation);
  color = vec3(
    contrast_curve(color.r, u_contrast),
    contrast_curve(color.g, u_contrast),
    contrast_curve(color.b, u_contrast)
  );
  color += u_brightness * (u_brightness > 0.0 ? (1.0 - color) : vec3(1.0));

  luma = dot(clamp(color, 0.0, 1.0), vec3(0.299, 0.587, 0.114));
  float hi = smoothstep(0.55, 0.92, luma) * u_tint_strength;
  float sh = (1.0 - smoothstep(0.08, 0.45, luma)) * u_tint_strength;
  color = mix(color, u_highlight_tint, hi);
  color = mix(color, u_shadow_tint, sh);
  color += u_shadow_lift * (1.0 - color) * (1.0 - color);

  // One-tap halation: warm the highlights without extra texture fetches.
  float bloom = smoothstep(0.72, 1.0, luma) * u_halation * 0.22;
  color += vec3(bloom, bloom * 0.35, bloom * 0.05);

  vec2 grain_uv = FlutterFragCoord().xy / max(u_grain_size * 2.4, 1.0);
  float n = hash_noise(floor(grain_uv)) - 0.5;
  color += n * u_grain * 0.18;

  vec2 centered = uv - vec2(0.5);
  float vig = smoothstep(0.35, 0.92, length(centered) * 1.35);
  color *= 1.0 - vig * u_vignette * 0.55;

  frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}
