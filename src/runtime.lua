local obs = obslua
local bit = require("bit")
local VERSION = "1.0.0"
local ROOT = script_path()
local INSTANCES = {}
local DEFS = {}
local emergency_bypass = false
local status_text = "Ready. Add a Liteyear FX filter to your camera, video, group or scene."

-- Property definitions keep UI defaults, saved state and validation together.
local function N(id, label, value, lo, hi, step)
    return {id=id,label=label,value=value,lo=lo,hi=hi,step=step or 0.1,kind="float"}
end
local function I(id, label, value, lo, hi)
    return {id=id,label=label,value=value,lo=lo,hi=hi,kind="int"}
end
local function B(id, label, value) return {id=id,label=label,value=value,kind="bool"} end
local function C(id, label, value) return {id=id,label=label,value=value,kind="color"} end
local function L(id, label, value, options) return {id=id,label=label,value=value,kind="list",options=options} end
local function def(id, label, shaders, props)
    local d = {id=id,label=label,shaders=shaders,props=props}
    DEFS[#DEFS+1] = d
    return d
end

local ca = def("ca", "Chromatic Aberration", {"chromatic-aberration"}, {
    L("mode","Mode",1,{{"Manual",1},{"Lens",2}}),
    N("red","Red offset (px)",3,-100,100), N("red_angle","Red angle",0,-180,180,1),
    N("green","Green offset (px)",0,-100,100), N("green_angle","Green angle",0,-180,180,1),
    N("blue","Blue offset (px)",3,-100,100), N("blue_angle","Blue angle",180,-180,180,1)})
local skip = def("skip", "Frame Skip", {}, {I("frames","Frames to skip",2,0,30)})
local interlace = def("interlace", "Interlace", {"interlace"}, {
    I("thickness","Line thickness (px)",1,1,50), N("dim","Previous field brightness (%)",85,0,100,1),
    N("alpha","Previous field opacity (%)",100,0,100,1)})
local poster = def("poster", "Posterize", {"posterize"}, {
    I("levels","Color levels",6,2,64), L("mode","Palette",1,{{"Original colors",1},{"Two-color gradient",2}}),
    C("color1","Dark color",0xFF110C08), C("color2","Light color",0xFFEAF0D9)})
local dither = def("dither", "Dither", {"dither-blue-noise"}, {
    L("pattern","Pattern",4,{{"Bayer 2 x 2",2},{"Bayer 4 x 4",4},{"Bayer 8 x 8",8},{"Hilbert noise",0}}),
    B("mono","Monochrome",false), B("round","Round to pixels",true),
    N("size","Pixel size",2,1,32,0.5), I("colors","Colors per channel",4,2,32),
    N("contrast","Contrast",1,0.1,3,0.01), N("gamma","Gamma",1,0.1,3,0.01)})
local mask_options = {{"No phosphor mask",0}}
for i=1,24 do mask_options[#mask_options+1] = {"Phosphor mask "..i,i} end
local crt = def("crt", "CRT", {"crt","crt-composite","brightness-threshold","bloom-combine"}, {
    L("mask","Phosphor pattern",1,mask_options), N("mask_amount","Mask intensity (%)",65,0,100,1),
    N("corners","Corner radius (px)",28,0,200,1), N("curve","Screen curvature",0.8,0,4,0.05),
    N("vignette","Vignette (%)",25,0,100,1), N("black","Black level",0,0,100,1),
    N("white","White level",255,101,255,1),
    N("bloom","Phosphor glow",0.2,0,3,0.01), N("radius","Glow size (px)",6,0.5,60,0.5)})
local ntsc = def("ntsc", "NTSC", {"ntsc-encode","ntsc-decode"}, {
    N("tuning","Tuning error",1,-1000,1000,1), N("noise","Signal noise (%)",0,0,100,1),
    N("band_size","Luma band size (px)",10,0.1,100,0.1), N("band_strength","Luma band strength (%)",70,0,400,1),
    I("bands","Luma bands",1,1,8), N("band_trail","Luma band trail (%)",100,0,100,1),
    N("bleed","Chroma bleed (%)",70,0,100,1), N("bleed_size","Chroma bleed size (px)",25,0,100,1),
    I("bleed_steps","Chroma samples",8,1,24), N("bleed_direction","Chroma direction (%)",100,-100,100,1),
    N("bleed_sat","Fringe saturation (%)",100,0,200,1), N("bleed_hue","Fringe hue",0,-180,180,1),
    N("crawl","Dot crawl (%)",50,0,100,1), N("crawl_speed","Dot crawl speed (%)",50,0,100,1),
    N("comb","Comb filter (%)",100,0,100,1),
    N("brightness","Brightness (%)",100,0,200,1), N("saturation","Saturation (%)",100,0,200,1)})
local boot = def("boot", "Cathode Boot", {"cathode-boot"}, {
    N("progress","Collapse progress (%)",0,0,100,0.1),
    L("animation","Animation",0,{{"Manual progress slider",0},{"Loop off / on",1},{"Collapse once when enabled",2},{"Boot once when enabled",3}}),
    N("duration","Animation duration (seconds)",1.5,0.2,10,0.1),
    N("thick_x","Horizontal thickness (px)",1,1,100,1), N("thick_y","Vertical thickness (px)",1,1,100,1),
    N("glow","Glow size (px)",3,0.1,40,0.1), C("glow_color","Glow color",0xFFFFFFFF),
    C("bg_color","Background",0xFF000000)})
local matrix = def("matrix", "Matrix Rain", {"matrix-rain","brightness-threshold","bloom-combine"}, {
    L("font","Characters",1,{{"Matrix glyphs",1},{"ASCII symbols",2},{"ASCII 10 characters",3},{"Emojis",4}}),
    N("scale","Character scale",0.4,0.1,3,0.05), N("speed","Rain speed",1,0,5,0.05),
    N("shift","Horizontal noise shift",0,0,500,1), B("source_colors","Use source colors",false),
    C("text_color","Rain color",0xFF89F76E), C("bg_color","Background",0xFF000000),
    N("floor","Minimum trail brightness",0,0,1,0.01), N("head","Leading character brightness",0.3,0,1,0.01),
    N("trail","Trail length",0.8,0.05,1,0.01),
    N("bloom","Glow intensity",1.2,0,4,0.05), N("radius","Glow size (px)",6,0.5,40,0.5)})
local codec = def("codec", "Retro Codec", {"codec"}, {
    N("pixels","Pixel scale",5,2,20,0.5), I("colors","Colors per channel",32,2,64),
    N("quality","Codec quality",0.85,0,1,0.01), N("keyframe","Keyframe interval (seconds)",3,0.1,10,0.1)})
local vhs = def("vhs", "VHS", {"vhs"}, {
    N("jitter","Maximum frame jitter (px)",10,0,100,1), N("interval","Average jitter interval (seconds)",5,0.2,20,0.1),
    N("jitter_time","Jitter duration (seconds)",0.5,0.05,3,0.05),
    N("wrinkles","Tape wrinkles per minute",6,0,120,1), N("wrinkle_size","Tape wrinkle size (%)",5,0.1,30,0.1),
    N("wrinkle_time","Tape wrinkle duration (seconds)",3,0.2,10,0.1), N("lines","Pop lines (%)",10,0,100,1),
    N("head_thickness","Primary head noise thickness (px)",15,0,150,1), N("head_offset","Primary head offset (px)",30,0,300,1),
    N("head2_thickness","Secondary head noise thickness (px)",15,0,150,1), N("head2_offset","Secondary head offset (px)",30,0,300,1),
    N("head2_position","Secondary head position",5,0,20,0.1)})
local bloom = def("bloom", "Bloom", {"brightness-threshold","bloom-combine"}, {
    N("intensity","Glow intensity",0.5,0,5,0.05), N("threshold","Highlight threshold",0.7,0,1,0.01),
    N("radius","Glow size (px)",6,0.5,100,0.5),
    L("channel","Threshold channel",1,{{"Luminance",1},{"Red",2},{"Green",3},{"Blue",4}})})
local scan = def("scan", "Scanlines", {"scan-lines"}, {
    N("period","Line spacing (px)",6,1,100,0.5), N("intensity","Intensity (%)",30,0,100,1),
    N("speed","Scroll speed (px / second)",10,-200,200,1),
    L("profile","Line shape",1,{{"Sine",1},{"Square",2},{"Smoothstep",3},{"Triangular",4}})})
local digital = def("digital", "Digital Glitch", {}, {
    N("amount","Affected blocks (%)",12,0,100,1), N("displacement","Maximum displacement (px)",90,0,1000,1),
    N("drift","RGB drift (px)",15,0,200,1), I("width","Block width (px)",100,4,500),
    I("height","Block height (px)",24,2,200), N("speed","Changes per second",5,0.1,30,0.1)})
local analog = def("analog", "Analog Glitch", {"analog-glitch"}, {
    N("displacement","Maximum displacement (px)",250,0,2000,1), N("speed1","Primary wave speed",2,0,30,0.1),
    N("scale1","Primary wave scale",800,1,1500,1), N("threshold1","Primary threshold",0.3,0,0.98,0.01),
    N("speed2","Secondary wave speed",5,0,30,0.1), N("scale2","Secondary wave scale",128,1,1500,1),
    N("influence","Secondary wave influence",0.15,0,1,0.01),
    N("interference","Interference",0.3,0,1,0.01), N("lines","Scanline interference",0.15,0,1,0.01),
    N("drift","Color drift (px)",8,0,200,1), N("desat","Desaturation (%)",10,0,100,1),
    B("alpha_noise","Vary interference opacity",false)})

local FONTS = {
    {"matrix-font-56.png",56}, {"ascii-test.png",33},
    {"ascii-font-2-200x30x10chars.png",10}, {"emojis-52.png",52}}

local function log(level, msg) obs.blog(level, "[Liteyear FX] "..msg) end
local function param(e, name)
    if not e then return nil end
    if e.params[name] == nil then e.params[name] = obs.gs_effect_get_param_by_name(e.handle,name) or false end
    return e.params[name] or nil
end
local function f(e,n,v) local p=param(e,n); if p then obs.gs_effect_set_float(p,v) end end
local function int(e,n,v) local p=param(e,n); if p then obs.gs_effect_set_int(p,v) end end
local function bool(e,n,v) local p=param(e,n); if p then obs.gs_effect_set_bool(p,v) end end
local function tex(e,n,t) local p=param(e,n); if p and t then obs.gs_effect_set_texture(p,t) end end
local function v2(e,n,x,y)
    local p=param(e,n); if p then local v=obs.vec2(); v.x=x;v.y=y;obs.gs_effect_set_vec2(p,v) end
end
local function v3(e,n,x,y,z)
    local p=param(e,n); if p then local v=obs.vec3();v.x=x;v.y=y;v.z=z;obs.gs_effect_set_vec3(p,v) end
end
local function v4(e,n,x,y,z,w)
    local p=param(e,n); if p then local v=obs.vec4();v.x=x;v.y=y;v.z=z;v.w=w;obs.gs_effect_set_vec4(p,v) end
end
local function color(e,n,c)
    v4(e,n,(c%256)/255,(math.floor(c/256)%256)/255,(math.floor(c/65536)%256)/255,(math.floor(c/16777216)%256)/255)
end

-- All compile, texture allocation and teardown operations run in the graphics context.
local function compile(name, defines)
    local code=SHADERS[name]
    if not code then log(obs.LOG_ERROR,"Missing shader: "..name); return nil end
    local prefix=defines or ""
    if obs.gs_get_device_type()==obs.GS_DEVICE_OPENGL then prefix="#define OPENGL 1\n"..prefix end
    local handle=obs.gs_effect_create(prefix..code,"liteyear-"..name,nil)
    if not handle then log(obs.LOG_ERROR,"Could not compile "..name..". The affected filter will bypass. See shader errors above.");return nil end
    return {handle=handle,params={}}
end
local function defines_for(d)
    if d.def.id=="crt" then return "#define PHOSPHOR_LAYOUT_"..d.s.mask.."\n" end
    if d.def.id=="dither" then
        local s=d.s; local a=s.pattern>0 and "#define USE_BAYER"..s.pattern.."\n" or "#define USE_BAYER4\n"
        if s.round then a=a.."#define ROUND_UV_TO_PIXEL\n" end
        return a
    end
    return ""
end
local function free_effects(d)
    for _,e in pairs(d.effects) do if e then obs.gs_effect_destroy(e.handle) end end
    d.effects={}
    if d.font then obs.gs_texture_destroy(d.font); d.font=nil end
end
local function free_renders(d)
    for _,r in pairs(d.renders) do obs.gs_texrender_destroy(r) end
    d.renders={};d.have_history=false;d.output=nil;d.valid=false;d.since_capture=1000
end
local function reload(d)
    obs.obs_enter_graphics()
    free_effects(d)
    free_renders(d)
    d.ok=true
    local names={"custom","render_output"}
    for _,name in ipairs(d.def.shaders) do names[#names+1]=name end
    for _,name in ipairs(names) do
        local extra=""
        if (name=="crt" or name=="dither-blue-noise") then extra=defines_for(d) end
        d.effects[name]=compile(name,extra)
        if not d.effects[name] then d.ok=false end
    end
    if d.def.id=="matrix" then
        local font=FONTS[d.s.font]
        d.font=obs.gs_texture_create_from_file(ROOT.."assets/"..font[1])
        d.font_count=font[2]
        if not d.font then d.ok=false;log(obs.LOG_ERROR,"Matrix font not found. Keep the assets folder beside liteyear-retro-fx.lua.") end
    end
    obs.obs_leave_graphics()
    d.signature=defines_for(d)..(d.def.id=="matrix" and tostring(d.s.font) or "")
end
local function update(d,settings)
    local old_animation=d.s.animation
    local old_pixels=d.s.pixels
    for _,p in ipairs(d.def.props) do
        local v
        if p.kind=="bool" then v=obs.obs_data_get_bool(settings,p.id)
        elseif p.kind=="int" or p.kind=="list" or p.kind=="color" then v=obs.obs_data_get_int(settings,p.id)
        else v=obs.obs_data_get_double(settings,p.id) end
        if type(v)=="number" then
            if v~=v or v==math.huge or v==-math.huge then v=p.value end
            if p.lo then v=math.max(p.lo,math.min(p.hi,v)) end
            if p.kind=="list" then
                local found=false;for _,o in ipairs(p.options) do if v==o[2] then found=true end end
                if not found then v=p.value end
            end
        end
        d.s[p.id]=v
    end
    if old_animation~=d.s.animation then d.anim_time=0 end
    local signature=defines_for(d)..(d.def.id=="matrix" and tostring(d.s.font) or "")
    if d.signature~=signature then reload(d) end
    if d.def.id=="codec" and old_pixels and old_pixels~=d.s.pixels then
        obs.obs_enter_graphics();free_renders(d);obs.obs_leave_graphics()
    end
    d.valid=false
end
local function rt(d,name)
    if not d.renders[name] then d.renders[name]=obs.gs_texrender_create(obs.GS_RGBA,obs.GS_ZS_NONE) end
    return d.renders[name]
end
local function texture(d,name)
    local r=d.renders[name];return r and obs.gs_texrender_get_texture(r) or nil
end
local function begin_rt(r,w,h)
    if not r then return false end
    obs.gs_texrender_reset(r)
    if not obs.gs_texrender_begin(r,w,h) then return false end
    obs.gs_blend_state_push()
    obs.gs_reset_blend_state()
    obs.gs_enable_blending(false)
    local clear=obs.vec4();clear.x=0;clear.y=0;clear.z=0;clear.w=0
    obs.gs_clear(obs.GS_CLEAR_COLOR,clear,0,0)
    obs.gs_ortho(0,w,0,h,-100,100)
    return true
end
local function end_rt(r)
    obs.gs_blend_state_pop()
    obs.gs_texrender_end(r)
end
local function pass(d,key,input,target,w,h,setup,technique)
    local e=d.effects[key]
    if not e or not input then return nil end
    local r=rt(d,target)
    if not begin_rt(r,w,h) then return nil end
    tex(e,"image",input);v2(e,"uv_size",w,h)
    if setup then setup(e) end
    while obs.gs_effect_loop(e.handle,technique or "Draw") do obs.gs_draw_sprite(input,0,w,h) end
    end_rt(r)
    return obs.gs_texrender_get_texture(r)
end
local function capture(d)
    local r=rt(d,"input")
    if not r then return nil end
    if not obs.obs_source_process_filter_begin(d.source,obs.GS_RGBA,obs.OBS_NO_DIRECT_RENDERING) then return nil end
    local base=obs.obs_get_base_effect(obs.OBS_EFFECT_DEFAULT)
    if not begin_rt(r,d.width,d.height) then
        obs.obs_source_process_filter_end(d.source,base,d.width,d.height)
        return nil
    end
    obs.obs_source_process_filter_tech_end(d.source,base,d.width,d.height,"DrawAlphaDivide")
    end_rt(r)
    return obs.gs_texrender_get_texture(r)
end
local function draw_output(d)
    local e=d.effects.render_output
    if not e or not d.output then return false end
    if not obs.obs_source_process_filter_begin(d.source,obs.GS_RGBA,obs.OBS_NO_DIRECT_RENDERING) then return false end
    tex(e,"output_image",d.output)
    obs.obs_source_process_filter_end(d.source,e.handle,d.width,d.height)
    return true
end
local function glow(d,image,amount,radius,threshold,levels)
    if amount<=0 then return image end
    -- Threshold and blur at quarter resolution. Five bilinear samples per axis.
    local w=math.max(1,math.floor(d.width/4));local h=math.max(1,math.floor(d.height/4))
    local a=pass(d,"brightness-threshold",image,"glow_threshold",w,h,function(e)
        f(e,"threshold",threshold);v3(e,"levels",levels[1],levels[2],levels[3])
    end)
    if not a then return nil end
    local b=pass(d,"custom",a,"glow_x",w,h,function(e) v2(e,"direction",radius/4,0) end,"DrawBlur")
    if not b then return nil end
    local c=pass(d,"custom",b,"glow_y",w,h,function(e) v2(e,"direction",0,radius/4) end,"DrawBlur")
    if not c then return nil end
    return pass(d,"bloom-combine",image,"glow_final",d.width,d.height,function(e)
        tex(e,"bloom_image",c);f(e,"intensity",amount)
    end)
end

-- Each effect uses the upstream GPU engine, except procedural Digital Glitch and
-- the fixed-cost separable glow helper. No per-pixel work is performed in Lua.
ca.render=function(d,image)
    local s=d.s;local r=math.rad(s.red_angle);local g=math.rad(s.green_angle);local b=math.rad(s.blue_angle)
    return pass(d,"chromatic-aberration",image,"final",d.width,d.height,function(e)
        v3(e,"channel_offsets",s.red,s.green,s.blue)
        v3(e,"channel_offset_cos_angles",math.cos(r),math.cos(g),math.cos(b))
        v3(e,"channel_offset_sin_angles",math.sin(r),math.sin(g),math.sin(b));f(e,"scale",1)
    end,s.mode==2 and "DrawLens" or "Draw")
end
skip.render=function(d,image)
    return pass(d,"custom",image,"final",d.width,d.height)
end
interlace.render=function(d,image)
    d.renders.final,d.renders.history=d.renders.history,d.renders.final
    local prev=d.have_history and texture(d,"history") or image
    local out=pass(d,"interlace",image,"final",d.width,d.height,function(e)
        tex(e,"prior_frame",prev);f(e,"frame",d.frame%2);f(e,"thickness",d.s.thickness)
        local b=d.s.dim/100;v4(e,"brightness_reduction",b,b,b,d.s.alpha/100)
    end)
    d.have_history=out~=nil
    return out
end
poster.render=function(d,image)
    return pass(d,"posterize",image,"final",d.width,d.height,function(e)
        f(e,"levels",d.s.levels);color(e,"color_1",d.s.color1);color(e,"color_2",d.s.color2)
    end,d.s.mode==2 and "DrawColorMap" or "Draw")
end
dither.render=function(d,image)
    local s=d.s
    local mode=s.mono and "DrawMono" or "DrawColor"
    return pass(d,"dither-blue-noise",image,"final",d.width,d.height,function(e)
        v2(e,"offset",0,0);f(e,"dither_size",s.size);f(e,"contrast",s.contrast);f(e,"gamma",s.gamma);f(e,"color_steps",s.colors-1)
    end,mode..(s.pattern==0 and "BN" or "Ordered"))
end
crt.render=function(d,image)
    local s=d.s
    local a=pass(d,"crt",image,"crt_mask",d.width,d.height,function(e)
        f(e,"mask_intensity",s.mask_amount/100);int(e,"phosphor_layout",s.mask)
        f(e,"vignette_intensity",s.vignette/100);f(e,"corner_radius",s.corners)
    end)
    if not a then return nil end
    a=glow(d,a,s.bloom,s.radius,0.5,{0.299,0.587,0.114})
    if not a then return nil end
    return pass(d,"crt-composite",a,"final",d.width,d.height,function(e)
        f(e,"black_level",s.black/255);f(e,"white_level",s.white/255);f(e,"dist",s.curve*0.05)
    end)
end
ntsc.render=function(d,image)
    local s=d.s
    local a=pass(d,"ntsc-encode",image,"ntsc_encoded",d.width,d.height,function(e)
        f(e,"frame",d.frame%65536);f(e,"tuning_offset",s.tuning);f(e,"luma_noise",s.noise/100)
        f(e,"y_offset",math.max(0,d.y_offset-20))
    end)
    if not a then return nil end
    return pass(d,"ntsc-decode",a,"final",d.width,d.height,function(e)
        f(e,"luma_band_size",s.band_size);f(e,"luma_band_strength",s.band_strength/400)
        int(e,"luma_band_count",s.bands*2+1);f(e,"luma_band_asymmetry",s.band_trail/100)
        f(e,"chroma_bleed_size",s.bleed_size);f(e,"chroma_bleed_strength",s.bleed/100);int(e,"chroma_bleed_steps",s.bleed_steps)
        f(e,"chroma_bleed_directionality",s.bleed_direction/100);f(e,"chroma_bleed_saturation",s.bleed_sat/100)
        f(e,"chroma_bleed_hue_shift",math.rad(s.bleed_hue));f(e,"dot_crawl_speed",12*s.crawl_speed/100)
        f(e,"dot_crawl_amount",s.crawl/100);f(e,"comb_filter_strength",s.comb/100)
        f(e,"brightness",s.brightness/100);f(e,"saturation",s.saturation/100);f(e,"elapsed_time",d.time)
    end)
end
boot.render=function(d,image)
    local s=d.s;local progress=s.progress/100
    if s.animation==1 then progress=0.5-0.5*math.cos(math.pi*d.anim_time/s.duration)
    elseif s.animation==2 then progress=math.min(1,d.anim_time/s.duration)
    elseif s.animation==3 then progress=1-math.min(1,d.anim_time/s.duration) end
    return pass(d,"cathode-boot",image,"final",d.width,d.height,function(e)
        f(e,"progress",progress);v2(e,"vert_range",0,0.7);v2(e,"horiz_range",0.5,0.9);v2(e,"fade_range",0.9,1)
        v2(e,"thickness",s.thick_x/d.width,s.thick_y/d.height);f(e,"glow_size",s.glow)
        color(e,"glow_color",s.glow_color);color(e,"bg_color",s.bg_color)
    end)
end
matrix.render=function(d,image)
    local s=d.s
    local a=pass(d,"matrix-rain",image,"matrix_chars",d.width,d.height,function(e)
        tex(e,"font_image",d.font);v2(e,"font_texture_size",obs.gs_texture_get_width(d.font),obs.gs_texture_get_height(d.font))
        f(e,"font_texture_num_chars",d.font_count);f(e,"scale",s.scale);f(e,"noise_shift",s.shift)
        f(e,"local_time",d.rain_time);bool(e,"colorize",s.source_colors);color(e,"text_color",s.text_color);color(e,"background_color",s.bg_color)
        f(e,"min_brightness",0);f(e,"max_brightness",1);f(e,"min_fade_value",s.floor)
        f(e,"active_rain_brightness",s.head);f(e,"fade_distance",s.trail)
    end)
    if not a then return nil end
    return glow(d,a,s.bloom,s.radius,0.4,{0.299,0.587,0.114})
end
codec.render=function(d,image)
    local s=d.s;local w=math.max(4,math.floor(d.width/s.pixels/4)*4);local h=math.max(4,math.floor(d.height/s.pixels/4)*4)
    local small=pass(d,"custom",image,"codec_input",w,h)
    if not small then return nil end
    local prev=d.have_history and texture(d,"codec_history") or small
    local key=not d.have_history or d.key_time>=s.keyframe
    if key then d.key_time=0 end
    local result=pass(d,"codec",small,"codec_result",w,h,function(e)
        tex(e,"prev_frame",prev);f(e,"is_keyframe",key and 1 or 0);f(e,"colors_per_channel",s.colors)
        f(e,"rpza_threshold_prev_frame",0.5*(1-s.quality));f(e,"rpza_threshold_solid",0.2*(1-s.quality));f(e,"rpza_threshold_gradient",1-s.quality)
    end,"DrawRPZA")
    if not result then return nil end
    -- Ping-pong result/history: never sample from the texture currently being written.
    d.renders.codec_result,d.renders.codec_history=d.renders.codec_history,d.renders.codec_result
    d.have_history=true
    return pass(d,"custom",result,"final",d.width,d.height,nil,"DrawPoint")
end
vhs.render=function(d,image)
    local s=d.s
    return pass(d,"vhs",image,"final",d.width,d.height,function(e)
        f(e,"wrinkle_position",d.wrinkle);f(e,"wrinkle_size",s.wrinkle_size/100);f(e,"time",d.time*100)
        f(e,"pop_line_prob",s.lines/100000);f(e,"hs_primary_offset",s.head_offset);f(e,"hs_primary_thickness",s.head_thickness)
        f(e,"hs_secondary_thickness",s.head2_thickness);f(e,"hs_secondary_horiz_offset",s.head2_offset)
        f(e,"hs_secondary_vert_offset",-s.head2_thickness+s.head2_position*s.head_offset)
        f(e,"horizontal_offset",d.jitter_value)
    end)
end
bloom.render=function(d,image)
    local channels={{0.299,0.587,0.114},{1,0,0},{0,1,0},{0,0,1}}
    return glow(d,image,d.s.intensity,d.s.radius,d.s.threshold,channels[d.s.channel])
end
scan.render=function(d,image)
    local names={"DrawSin","DrawSquare","DrawSmoothstep","DrawTriangular"}
    return pass(d,"scan-lines",image,"final",d.width,d.height,function(e)
        f(e,"period",d.s.period);f(e,"offset",d.scan_offset);f(e,"intensity",d.s.intensity/100)
    end,names[d.s.profile])
end
digital.render=function(d,image)
    local s=d.s
    return pass(d,"custom",image,"final",d.width,d.height,function(e)
        f(e,"time",d.time*s.speed);f(e,"amount",s.amount/100);f(e,"displacement",s.displacement)
        f(e,"color_drift",s.drift);f(e,"block_width",s.width);f(e,"block_height",s.height)
    end,"DrawGlitch")
end
analog.render=function(d,image)
    local s=d.s
    return pass(d,"analog-glitch",image,"final",d.width,d.height,function(e)
        f(e,"time",d.time);f(e,"speed_primary",s.speed1);f(e,"speed_secondary",s.speed2)
        f(e,"scale_primary",s.scale1);f(e,"scale_secondary",s.scale2);f(e,"threshold_primary",s.threshold1)
        f(e,"threshold_secondary",0.7);f(e,"secondary_influence",s.influence);f(e,"max_disp",s.displacement)
        f(e,"interference_mag",s.interference);f(e,"line_mag",s.lines);f(e,"interference_alpha",s.alpha_noise and 1 or 0)
        f(e,"desaturation_amount",s.desat/100);f(e,"color_drift",s.drift)
    end)
end

local function tick(d,seconds)
    d.valid=false
    if not d.ok or emergency_bypass or not obs.obs_source_enabled(d.source) then d.was_enabled=false;return end
    if not d.was_enabled then d.anim_time=0;d.was_enabled=true end
    d.time=(d.time+seconds)%3600;d.frame=(d.frame+1)%1048576;d.anim_time=d.anim_time+seconds
    d.key_time=d.key_time+seconds
    local s=d.s;local id=d.def.id
    if id=="scan" then d.scan_offset=(d.scan_offset+seconds*s.speed)%s.period
    elseif id=="matrix" then d.rain_time=(d.rain_time+seconds*s.speed)%3600
    elseif id=="ntsc" then
        if s.tuning<=20 then d.y_offset=math.floor(d.y_offset/1.8)
        else d.y_offset=(d.y_offset+(s.tuning-20)*d.height/400*seconds*60)%math.max(1,d.height*1.1) end
    elseif id=="vhs" then
        if d.wrinkle>-0.2 then d.wrinkle=d.wrinkle-seconds/s.wrinkle_time
        elseif math.random()<1-math.exp(-s.wrinkles/60*seconds) then d.wrinkle=1.2 end
        d.jitter_phase=d.jitter_phase+seconds
        if d.jitter_active then
            local phase=math.min(1,d.jitter_phase/s.jitter_time)
            d.jitter_value=math.sin(math.pi*phase)*d.jitter_amount
            if phase>=1 then d.jitter_active=false;d.jitter_value=0 end
        elseif math.random()<1-math.exp(-seconds/s.interval) then
            d.jitter_active=true;d.jitter_phase=0;d.jitter_amount=math.random()*s.jitter
        end
    end
end
local function render(d)
    if emergency_bypass or not d.ok then obs.obs_source_skip_video_filter(d.source);return end
    local target=obs.obs_filter_get_target(d.source)
    if not target then obs.obs_source_skip_video_filter(d.source);return end
    local w=obs.obs_source_get_base_width(target);local h=obs.obs_source_get_base_height(target)
    if w<1 or h<1 then obs.obs_source_skip_video_filter(d.source);return end
    if w~=d.width or h~=d.height then free_renders(d);d.width=w;d.height=h end
    if d.valid and d.output then draw_output(d);return end
    if d.def.id=="skip" and d.output and d.since_capture<d.s.frames then
        d.since_capture=d.since_capture+1;d.valid=true;draw_output(d);return
    end
    local image=capture(d)
    if not image then obs.obs_source_skip_video_filter(d.source);return end
    local output=d.def.render(d,image)
    if not output then
        -- A failed allocation or pass is logged once, then the source bypasses.
        d.ok=false;d.output=nil
        log(obs.LOG_ERROR,d.def.label.." stopped rendering; bypassing to preserve the picture. Use Reload effects in Tools > Scripts.")
        obs.obs_source_skip_video_filter(d.source);return
    end
    d.output=output;d.valid=true;d.since_capture=0
    if not draw_output(d) then obs.obs_source_skip_video_filter(d.source) end
end

local function create(definition,settings,source)
    local d={def=definition,source=source,s={},effects={},renders={},signature=nil,ok=false,
        width=0,height=0,time=0,rain_time=0,frame=0,anim_time=0,key_time=0,y_offset=0,
        scan_offset=0,wrinkle=-1,jitter_phase=0,jitter_value=0,jitter_amount=0,jitter_active=false,
        since_capture=1000,have_history=false,valid=false,was_enabled=false}
    update(d,settings)
    INSTANCES[d]=true
    return d
end
local function destroy(d)
    INSTANCES[d]=nil
    obs.obs_enter_graphics();free_effects(d);free_renders(d);obs.obs_leave_graphics()
end
local function defaults(definition,settings)
    for _,p in ipairs(definition.props) do
        if p.kind=="bool" then obs.obs_data_set_default_bool(settings,p.id,p.value)
        elseif p.kind=="float" then obs.obs_data_set_default_double(settings,p.id,p.value)
        else obs.obs_data_set_default_int(settings,p.id,p.value) end
    end
end
local function properties(definition)
    local props=obs.obs_properties_create()
    for _,p in ipairs(definition.props) do
        if p.kind=="float" then obs.obs_properties_add_float_slider(props,p.id,p.label,p.lo,p.hi,p.step)
        elseif p.kind=="int" then obs.obs_properties_add_int_slider(props,p.id,p.label,p.lo,p.hi,1)
        elseif p.kind=="bool" then obs.obs_properties_add_bool(props,p.id,p.label)
        elseif p.kind=="color" then obs.obs_properties_add_color_alpha(props,p.id,p.label)
        elseif p.kind=="list" then
            local list=obs.obs_properties_add_list(props,p.id,p.label,obs.OBS_COMBO_TYPE_LIST,obs.OBS_COMBO_FORMAT_INT)
            for _,option in ipairs(p.options) do obs.obs_property_list_add_int(list,option[1],option[2]) end
        end
    end
    return props
end

function script_description()
    return "<b>Liteyear Retro FX</b> "..VERSION.."<br><br>15 GPU video effects. After adding this script, right-click your camera or scene → Filters → + → Liteyear FX.<br><br>Keep the assets folder beside this file. No terminal, server or extra plugin.<br><br>Mac user tested; automated OBS rendering tests on Linux. See the included test report for details.<br><br>Adapted from FiniteSingularity's OBS Retro Effects (GPL-2.0)."
end
local function reload_all()
    for d in pairs(INSTANCES) do reload(d) end
    status_text="Effects reloaded. Failed effects bypass and write details to the OBS log."
end
function script_properties()
    local props=obs.obs_properties_create()
    obs.obs_properties_add_bool(props,"bypass","Bypass every Liteyear FX filter (restore original picture)")
    obs.obs_properties_add_button(props,"reload","Reload effects",function() reload_all();return true end)
    obs.obs_properties_add_button(props,"check","Check all 15 effects",function()
        local good=0;local failed={}
        for _,definition in ipairs(DEFS) do
            local settings=obs.obs_data_create();defaults(definition,settings)
            local d=create(definition,settings,nil)
            if d.ok then good=good+1 else failed[#failed+1]=definition.label end
            destroy(d);obs.obs_data_release(settings)
        end
        status_text=good.." / 15 shader checks passed. "..(#failed>0 and ("Failed: "..table.concat(failed,", ")) or "Ready for a visual test.")
        log(#failed==0 and obs.LOG_INFO or obs.LOG_ERROR,status_text)
        return true
    end)
    if obs.obs_properties_add_text then obs.obs_properties_add_text(props,"status",status_text,obs.OBS_TEXT_INFO) end
    return props
end
function script_update(settings)
    emergency_bypass=obs.obs_data_get_bool(settings,"bypass")
end
function script_defaults(settings) obs.obs_data_set_default_bool(settings,"bypass",false) end
function script_load(settings)
    script_update(settings)
    for _,definition in ipairs(DEFS) do
        local current=definition
        obs.obs_register_source({
            id="liteyear_retro_"..current.id.."_v1",type=obs.OBS_SOURCE_TYPE_FILTER,
            output_flags=bit.bor(obs.OBS_SOURCE_VIDEO,obs.OBS_SOURCE_SRGB),
            get_name=function() return "Liteyear FX - "..current.label end,
            create=function(s,source) return create(current,s,source) end,
            destroy=destroy,update=update,
            get_defaults=function(s) defaults(current,s) end,
            get_properties=function() return properties(current) end,
            get_width=function(d) return d.width end,get_height=function(d) return d.height end,
            video_tick=tick,video_render=render,
            show=function(d) d.anim_time=0;d.valid=false end,
            hide=function(d) d.was_enabled=false end})
    end
    log(obs.LOG_INFO,"Loaded "..VERSION.." with 15 filters.")
end

-- Local QA harness reads definitions without altering production behavior.
if _G.LITEYEAR_TEST_EXPORT then
    _G.LITEYEAR_TEST_EXPORT({defs=DEFS,create=create,destroy=destroy,update=update,tick=tick,render=render,
        properties=properties,defaults=defaults,instances=INSTANCES,reload=reload})
end
