class_name PointGlow
extends RefCounted
## Rendering for things the eye receives as points of light.
##
## Every naked-eye object in EarthShip's sky is, geometrically, a point. Jupiter
## at opposition is 47 arcseconds across -- a fiftieth of a degree -- and a star
## is billions of times smaller than that. Neither resolves. What you actually
## see is a glare: light scattered in the atmosphere, in the eye's lens, and
## across the retina. That glare is why Venus looks "big" and a fourth-magnitude
## star looks tiny, even though as objects they are equally unresolvable.
##
## So points are drawn as a soft additive blob whose SIZE AND ALPHA COME FROM
## BRIGHTNESS, never from the object's real diameter. Two consequences:
##
##   1. A point's size on screen is in PIXELS, not in world units, and so it
##      must not change when the camera zooms. A star drawn as a world-space
##      sphere would balloon when EclipseViewer narrows the field from 38
##      degrees to 4, which is exactly wrong: zooming a telescope on a star
##      gains you no disc, only a brighter point. `scale_for` recomputes the
##      world size that holds a fixed pixel size at the current field of view.
##   2. Stars and planets MUST share this code. When they had separate scales, a
##      third-magnitude star rendered the same size as Jupiter and the sky was
##      meaningless. One magnitude scale, one glow, one look.
##
## Additive blending, not alpha: overlapping light adds, the way it does on a
## real long exposure and in a real eye. That is what lets the exposure tail
## build up where the planet lingered.

const BrillianceScript := preload("res://scripts/SolarBrilliance.gd")

## Texture resolution for the glare profile. 96 is plenty -- it is always drawn
## small and heavily filtered.
const TEX_SIZE := 96

## Radial falloff standing in for atmospheric and ocular scatter: a tight core
## with a wide, faint skirt. The skirt is the part that makes a bright object
## read as bigger, since its outer reaches stay above the visible threshold
## while a faint object's do not.
static func make_texture(size: int = TEX_SIZE) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBAF)
	var c: float = float(size) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) - c + 0.5,
				float(y) - c + 0.5).length() / c
			var core: float = pow(clampf(1.0 - d, 0.0, 1.0), 7.0)
			var skirt: float = pow(clampf(1.0 - d, 0.0, 1.0), 2.0) * 0.30
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0,
				clampf(core + skirt, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

static func make_quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	return q

## A billboarded, additively blended quad. Sprite3D would be the obvious choice
## but it cannot blend additively in Godot 4, and additive is the whole point.
static func make_quad_instance(quad: QuadMesh, tex: Texture2D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Without this the billboard ignores the node's scale, and scale is how the
	# glow radius is driven.
	mat.billboard_keep_scale = true
	mat.albedo_texture = tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.disable_receive_shadows = true
	mi.material_override = mat
	return mi

## Screen pixels per radian for a camera of `fov_deg` filling `view_h` pixels.
## Godot's Camera3D.fov is the VERTICAL angle, so height is the right extent.
static func px_per_rad(view_h: float, fov_deg: float) -> float:
	return view_h / maxf(deg_to_rad(fov_deg), 0.0001)

## World-space scale for a quad that must cover `px` pixels ACROSS while
## sitting on a shell of radius `shell_r`.
static func scale_for(px: float, view_h: float, fov_deg: float,
		shell_r: float) -> float:
	var ppr: float = px_per_rad(view_h, fov_deg)
	return maxf(px / maxf(ppr, 0.001) * shell_r, 0.0001)

## Diameter in pixels of the glare a source of apparent magnitude `mag` throws.
##
## Deliberately steep. Real flux across the naked-eye range spans a factor of
## ten billion, which no screen can show, so the compression has to be
## perceptual -- but if it is too gentle everything becomes the same dot and the
## sky carries no information. This keeps a fifth-magnitude star near a single
## pixel while Venus at -4 is a broad flare, which is what the sky looks like.
static func diameter_px(mag: float) -> float:
	var b: float = BrillianceScript.brightness01(mag)
	# 1.6 px at the naked-eye limit, ~34 px for Venus at her brightest.
	var d: float = 1.6 + 32.0 * pow(b, 2.3)
	return d * overbright_gain(mag)

## Extra glare for sources brighter than the point where `brightness01` saturates.
##
## That function tops out at Venus at her best, which is correct for everything
## that reads as a point -- she is the brightest of them. But the Sun is 22
## magnitudes beyond her, a factor of about six hundred million in flux, and the
## Moon is 8 magnitudes beyond. Clamped to the same ceiling, the Sun rendered
## barely larger than Venus: a small yellow dot in a blue sky, when the defining
## fact about the Sun is that you cannot look near it.
##
## Beyond the ceiling the growth is linear in magnitude, i.e. logarithmic in flux,
## which is the right shape for glare: each factor of ten in flux pushes the
## visible edge of the skirt out by roughly a constant amount rather than by a
## constant ratio.
static func overbright_gain(mag: float) -> float:
	var over: float = maxf(BrillianceScript.MAG_FULL_BRIGHT - mag, 0.0)
	return 1.0 + 0.42 * over

## Alpha for a source of apparent magnitude `mag`. Faint stars stay genuinely
## faint; anything from first magnitude up is fully opaque at the core and its
## apparent size does the rest of the talking.
static func alpha_for(mag: float) -> float:
	var b: float = BrillianceScript.brightness01(mag)
	return clampf(0.22 + 1.5 * b, 0.0, 1.0)
