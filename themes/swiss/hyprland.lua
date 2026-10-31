-- Swiss: 1px hairline borders, squircle corners (rounding_power > 2 bends the
-- corner from a circle toward a superellipse).
local active_border_color = "rgba(caccccff)"
local inactive_border_color = "rgba(4b4e5580)"

hl.config({
  general = {
    border_size = 1,
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },
  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
  decoration = {
    rounding = 14,
    rounding_power = 4.5,
  },
})
