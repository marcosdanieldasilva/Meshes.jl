
# ==============================================================================
# 1. HELPER FUNCTIONS
# ==============================================================================

# Helper to strip units if provided
unitsindataunit(x::Number) = ustrip(x)
unitsindataunit(x::Tuple) = unitsindataunit(x[1])

# Formats the string. 
# CURRENT BEHAVIOR: Returns only the number (e.g., "10").
# If you want units (e.g., "10 m"), change to: "$(mul) $(unit(scale))"
scalebarstr(scale::Any, mul) = "$(mul)"
scalebarstr(scale::Tuple{<:Number,<:Function}, mul) = scale[2](mul)

# ==============================================================================
# 2. RECIPE DEFINITION
# ==============================================================================

Makie.@recipe(ScaleBar, scale) do scene
  Makie.Attributes(
    # Position and Layout
    position=Makie.Point2f(0.85, 0.05),
    targetaxfrac=0.25,

    # Default Style Attributes
    # We define defaults here. Any other attribute passed (e.g., linestyle)
    # will be captured by shared_attributes in the plot! function.
    color=:black,
    linewidth=3.0,
    fontsize=16,
    font=:regular,

    # Math logic for nice numbers
    muls=[
      p isa Int ? x * p : round(x * p, sigdigits=4) for
      p in Real[[10.0^p for p in -50:-1]; [1, 10, 100, 1000, 10000]; [10.0^p for p in 5:50]] for x in [1, 2, 5]
    ]
  )
end

# Prevent scalebar from affecting axis limits
Makie.data_limits(::ScaleBar) = Makie.Rect3f(Makie.Point3f(NaN), Makie.Vec3f(NaN))
Makie.boundingbox(::ScaleBar, space::Symbol=:data) = Makie.Rect3f(Makie.Point3f(NaN), Makie.Vec3f(NaN))

# ==============================================================================
# 3. PLOT IMPLEMENTATION
# ==============================================================================

function Makie.plot!(p::ScaleBar)
  scene = Makie.parent_scene(p)

  # Check for non-linear transforms
  tf = Makie.transform_func(scene)[1]
  if tf !== identity
    @warn "ScaleBar: Non-identity transform detected ($tf)."
  end

  viewlimits = Makie.projview_to_2d_limits(p)

  # 1. CALCULATE GEOMETRY (Reactive)
  scaledata = Makie.lift(viewlimits, p.scale, p.targetaxfrac, p.muls, p.position) do rect, scale, targetfrac, muls, pos
    widthx = rect.widths[1]
    safewidth = isfinite(widthx) && widthx > 0 ? widthx : 1.0

    uindata = unitsindataunit(scale)

    # Find best multiplier
    mul = argmin(m -> abs(1 / uindata * m - targetfrac * safewidth), muls)
    lengthdata = (1 / uindata) * mul

    # Relative length (0-1)
    lengthrel = lengthdata / safewidth

    avgpos = convert(Makie.Point2f, pos)
    p1 = avgpos - Makie.Vec2f(lengthrel / 2, 0)
    p2 = avgpos + Makie.Vec2f(lengthrel / 2, 0)

    return (points=[p1, p2], text=scalebarstr(scale, mul), textpos=avgpos)
  end

  # 2. PREPARE ATTRIBUTES (The "Magic" replacement)
  # Instead of @modify macros, we use shared_attributes to grab everything 
  # the user passed (like linestyle, alpha, etc) relevant to Lines/Text.

  # -- Lines Attributes --
  # Extracts color, linewidth, linestyle, alpha, etc. from 'p'
  line_attrs = Makie.shared_attributes(p, Makie.Lines)
  # Force specific overrides for the scalebar
  line_attrs[:space] = :relative
  line_attrs[:xautolimits] = false
  line_attrs[:yautolimits] = false

  # -- Text Attributes --
  # Extracts color, fontsize, font, align, etc. from 'p'
  text_attrs = Makie.shared_attributes(p, Makie.Text)
  # Force specific overrides
  text_attrs[:space] = :relative
  text_attrs[:align] = (:center, :bottom)
  text_attrs[:offset] = (0, 5)
  text_attrs[:xautolimits] = false
  text_attrs[:yautolimits] = false

  # 3. DRAW
  Makie.lines!(p, line_attrs, Makie.lift(x -> x.points, scaledata))
  Makie.text!(p, text_attrs, Makie.lift(x -> x.text, scaledata); text=Makie.lift(x -> x.text, scaledata))

  return p
end
