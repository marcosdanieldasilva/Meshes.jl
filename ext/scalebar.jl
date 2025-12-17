unitsindataunit(x::Number) = ustrip(x)
unitsindataunit(x::Tuple) = unitsindataunit(x[1])

scalebarstr(scale::Quantity, mul) = "$(mul) $(unit(scale))"
scalebarstr(scale::Tuple{<:Number,<:Function}, mul) = scale[2](mul)

@recipe(ScaleBar, scale) do scene
  Attributes(
    position=Point2f(0.85, 0.05),
    targetaxfrac=0.25,
    color=:black,
    linewidth=3.0,
    fontsize=16,
    font=:regular,
    muls=[
      p isa Int ? x * p : round(x * p, sigdigits=4) for
      p in Real[[10.0^p for p in -50:-1]; [1, 10, 100, 1000, 10000]; [10.0^p for p in 5:50]] for x in [1, 2, 5]
    ]
  )
end

# Prevent scalebar from affecting axis limits during autoscaling
Makie.data_limits(::ScaleBar) = Rect3f(Point3f(NaN), Vec3f(NaN))
Makie.boundingbox(::ScaleBar, space::Symbol=:data) = Rect3f(Point3f(NaN), Vec3f(NaN))

function Makie.plot!(p::ScaleBar)
  scene = Makie.parent_scene(p)
  # Warn if the axis is not linear (e.g., Log scale), as the bar would be inaccurate.
  tf = Makie.transform_func(scene)[1]
  if tf !== identity
    @warn "ScaleBar: Non-identity transform detected ($tf). Scalebar length may be visually incorrect on non-linear axes."
  end
  # Gets view limits. projview_to_2d_limits handles camera/zoom changes.
  viewlimits = Makie.projview_to_2d_limits(p)
  scaledata = lift(viewlimits, p.scale, p.targetaxfrac, p.muls, p.position) do rect, scale, targetfrac, muls, pos
    # Handle edge cases where plot is initializing and width might be 0 or Inf
    widthx = rect.widths[1]
    safewidth = isfinite(widthx) && widthx > 0 ? widthx : 1.0
    uindata = unitsindataunit(scale)
    mul = argmin(m -> abs(1 / uindata * m - targetfrac * safewidth), muls)
    lengthdata = (1 / uindata) * mul
    # Relative length (0-1)
    lengthrel = lengthdata / safewidth
    avgpos = convert(Point2f, pos)
    p1 = avgpos - Vec2f(lengthrel / 2, 0)
    p2 = avgpos + Vec2f(lengthrel / 2, 0)
    return (points=[p1, p2], text=scalebarstr(scale, mul), textpos=avgpos)
  end
  # Draw Line
  lines!(
    p,
    lift(x -> x.points, scaledata);
    color=p.color,
    linewidth=p.linewidth,
    space=:relative,
    # Critical: prevents the bar from expanding the axis limits
    xautolimits=false,
    yautolimits=false
  )
  # Draw Text
  text!(
    p,
    lift(x -> x.textpos, scaledata);
    text=lift(x -> x.text, scaledata),
    color=p.color,
    fontsize=p.fontsize,
    font=p.font,
    align=(:center, :bottom),
    space=:relative,
    offset=(0, 5),
    xautolimits=false,
    yautolimits=false
  )
  return p
end