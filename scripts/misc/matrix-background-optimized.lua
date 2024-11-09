--[[
dofile("scripts/misc/matrix-background.lua")()

This script shows how to use shaders and FrameBuffers.
It may be slow on a very big maps and some parts of it are not optimized to the maximum though.
--]]

-- Searching for exact methods to be called many times - the main source of optimization
-- Note: casting parameters to java.lang.Class because Lua LS is not sure if we are pointing to a class or a function to instantiate its interface (which is defined as @overload)
local foo_CacheSetText = C.BitmapFontCache:_findMethod("setText", C.CharSequence --[[@as Class]], java.float, java.float)
local foo_CacheDraw = C.BitmapFontCache:_findMethod("draw", C.Batch --[[@as Class]])
local foo_CacheSetColors = C.BitmapFontCache:_findMethod("setColors", C.Color)

local logger = C.TLog:forTag("misc/matrix-bg-opt.lua")

local S = S

local UIV = {
    _noSyncCheck = true,
    labelGrid = {},
    colParallax = {}, -- col * 2, col * 2 + 1
    colCount = 0,
    rowCount = 0,
    dropTime = 0,
    alphaDecayTime = 0,

    ---@type FrameBuffer
    fbo = nil,

    ---@type ShaderProgram
    shader = nil
}
local matrixCharacters = {
    "ト", "マ", "ウ", "ル", "ス", "デ", "レ", "且", "个", "乍", "于", "云", "五", "午", "历", "口", "己", "１", "２", "３", "５"
}
local mapSpacing = 2

-- Using indexed array instead of a table saves another 0.2-0.4ms per frame
local IDX_X = 1
local IDX_Y = 2
local IDX_CHAR = 3
local IDX_ALPHA = 4
local IDX_STATIC_ALPHA = 5
local IDX_DROP = 6

local random = math.random

-- Shader code stored in strings
local vertexShader = [[
attribute vec4 a_position;
attribute vec4 a_color;
attribute vec2 a_texCoord0;
uniform mat4 u_projTrans;
varying vec4 v_color;
varying vec2 v_texCoords;

void main()
{
    v_color = a_color;
    v_color.a = v_color.a * (255.0/254.0);
    v_texCoords = a_texCoord0;
    gl_Position =  u_projTrans * a_position;
}
]]

local fragmentShader = [[
#version 140

#ifdef GL_ES
#define LOWP lowp
precision mediump float;
#else
#define LOWP
#endif

uniform vec3 iResolution;
uniform sampler2D u_texture;

in LOWP vec4 v_color;
in vec2 v_texCoords;
out vec4 outColor;

#define px (vec2(1.0) / iResolution.xy)

vec4 GetBloom ( in vec2 uv, in vec4 inColor )
{
	float numSamples = 1.0;
    vec4 color = inColor;

	for (float x = -10.0; x <= 10.0; x += 1.0)
	{
		for (float y = -10.0; y <= 10.0; y += 1.0)
		{
			vec4 addColor = texture(u_texture, uv + (vec2(x, y) * px));
            float dist = length(vec2(x,y))+1.0;
            vec4 glowColor = max((addColor * 128.0) / pow(dist, 2.0), vec4(0.0));
            if (max(glowColor.r, max(glowColor.g, glowColor.b)) > 0.0)
            {
                color += glowColor;
                numSamples += 1.0;
            }
		}
	}

	return color / numSamples;
}

void main()
{
    vec4 color = texture2D(u_texture, v_texCoords);
    outColor = mix(color, GetBloom(v_texCoords, color), 0.4);

}
]]

local function start()
    if S.CFG.headless then return nil end

    -- Compile bloom shader
    local shader = C.ShaderProgram.new(vertexShader, fragmentShader)
    if shader:isCompiled() then
        UIV.shader = shader
    else
        logger:w("Failed to compile shader: %s", shader:getLog())
    end

    local fancyTiles = {}
    local map = S.map:getMap()
    for x = -mapSpacing, map:getWidth() + mapSpacing - 1 do
        for y = -mapSpacing, map:getHeight() + mapSpacing - 1 do
            local tile = map:getTile(x, y)
            if tile == nil or C.ScriptTile:_isInstance(tile) then
                fancyTiles[#fancyTiles + 1] = { x, y }
            end
        end
    end

    UIV.colCount = (map:getWidth() + mapSpacing * 2) * 6
    UIV.rowCount = (map:getHeight() + mapSpacing * 2) * 6
    UIV.labelGrid = {}
    for rowIdx = 1, UIV.rowCount do
        local row = {}
        UIV.labelGrid[rowIdx] = row
        for colIdx = 1, UIV.colCount do
            row[colIdx] = {
                0, 0, nil, 0, 0, false
            }
        end
    end

    UIV.colParallax = {}
    for _ = 1, UIV.colCount do
        table.insert(UIV.colParallax, { random(), random() })
    end
    for _, tilePos in ipairs(fancyTiles) do
        for i = 0, 5 do
            for j = 0, 5 do
                if random() < 0.8 then
                    local colIdx = (tilePos[1] + mapSpacing) * 6 + j + 1
                    local rowIdx = (tilePos[2] + mapSpacing) * 6 + i + 1
                    local tileX = tilePos[1] * 128
                    local tileY = tilePos[2] * 128

                    local cell = UIV.labelGrid[rowIdx][colIdx]
                    cell[IDX_STATIC_ALPHA] = 1
                    cell[IDX_X] = tileX + j * 21 + 6
                    cell[IDX_Y] = tileY + i * 21 + 17
                end
            end
        end
    end

    -- Smooth out on the edges
    local smoothDepth = 20
    for rowIdx = 1, UIV.rowCount do
        -- left
        local depth = random(1, smoothDepth)
        for colIdx = 1, depth do
            local cell = UIV.labelGrid[rowIdx][colIdx]
            cell[IDX_STATIC_ALPHA] = cell[IDX_STATIC_ALPHA] * (colIdx * (1 / depth))
        end
        -- right
        depth = random(1, smoothDepth)
        for colIdx = 1, depth do
            local cell = UIV.labelGrid[rowIdx][UIV.colCount - colIdx + 1]
            cell[IDX_STATIC_ALPHA] = cell[IDX_STATIC_ALPHA] * (colIdx * (1 / depth))
        end
    end
    for colIdx = 1, UIV.colCount do
        -- bottom
        local depth = random(1, smoothDepth)
        for rowIdx = 1, depth do
            local cell = UIV.labelGrid[rowIdx][colIdx]
            cell[IDX_STATIC_ALPHA] = cell[IDX_STATIC_ALPHA] * (rowIdx * (1 / depth))
        end
        -- top
        depth = random(1, smoothDepth)
        for rowIdx = 1, depth do
            local cell = UIV.labelGrid[UIV.rowCount - rowIdx + 1][colIdx]
            cell[IDX_STATIC_ALPHA] = cell[IDX_STATIC_ALPHA] * (rowIdx * (1 / depth))
        end
    end

    local atTotal = C.MovingAverageLong.new(120)
    local atUpdate = C.MovingAverageLong.new(120)
    local atDecay = C.MovingAverageLong.new(120)
    local atPrepare = C.MovingAverageLong.new(120)
    local atCacheDraw = C.MovingAverageLong.new(120)
    local atFboDraw = C.MovingAverageLong.new(120)

    local layerRenderer = C.RenderSystem.LayerRenderer(function(batch, realDeltaTime, _, _)
        local _st = C.Game:getRealTickCount()

        -- Update things
        local rowCount = UIV.rowCount
        local colCount = UIV.colCount
        local labelGrid = UIV.labelGrid
        local colParallax = UIV.colParallax

        UIV.dropTime = UIV.dropTime + realDeltaTime
        if UIV.dropTime > 0.067 then
            UIV.dropTime = UIV.dropTime - 0.067
            -- Tick
            for rowIdx = 1, rowCount do
                local row = labelGrid[rowIdx]
                for colIdx = 1, colCount do
                    local cell = row[colIdx] -- < GETTABLE 11
                    if rowIdx == rowCount and random() < 0.02 then
                        -- First row - add new drops
                        if cell[IDX_ALPHA] < 0.4 then
                            cell[IDX_DROP] = true
                            cell[IDX_ALPHA] = random() * 0.5 + 0.5
                            if cell[IDX_STATIC_ALPHA] ~= 0 then
                                cell[IDX_CHAR] = matrixCharacters[random(1, #matrixCharacters)]
                            end
                        end
                    else
                        if cell[IDX_DROP] then
                            cell[IDX_DROP] = false

                            local cellBelow
                            for belowRowIdx = rowIdx - 1, 1, -1 do
                                local rowBelow = labelGrid[belowRowIdx]
                                if rowBelow ~= nil then
                                    local cb = rowBelow[colIdx]
                                    if cb ~= nil then
                                        cellBelow = cb
                                        break
                                    end
                                end
                            end
                            if cellBelow ~= nil then
                                cellBelow[IDX_DROP] = true
                                cellBelow[IDX_ALPHA] = cell[IDX_ALPHA]
                                if cellBelow[IDX_STATIC_ALPHA] ~= 0 then
                                    cellBelow[IDX_CHAR] = matrixCharacters[random(1, #matrixCharacters)]
                                end
                            end
                        end
                    end
                end
            end
        end

        atUpdate:push(C.Game:getRealTickCount() - _st)
        local _st1 = C.Game:getRealTickCount()

        UIV.alphaDecayTime = UIV.alphaDecayTime + realDeltaTime
        if UIV.alphaDecayTime > 0.033 then
            UIV.alphaDecayTime = UIV.alphaDecayTime - 0.033
            -- Tick
            for rowIdx = 1, rowCount do
                local row = labelGrid[rowIdx]
                for colIdx = 1, colCount do
                    local cell = row[colIdx] -- < GETTABLE 7
                    if not cell[IDX_DROP] then -- < GETTABLE 6
                        cell[IDX_ALPHA] = cell[IDX_ALPHA] * 0.975 -- < GETTABLE 9
                        if cell[IDX_ALPHA] < 0 then cell[IDX_ALPHA] = 0 end -- < GETTABLE 8

                        if cell[IDX_STATIC_ALPHA] ~= 0 and random() < 0.003 then -- < GETTABLE 10
                            cell[IDX_CHAR] = matrixCharacters[random(1, #matrixCharacters)]
                        end
                    end
                end
            end
        end

        atDecay:push(C.Game:getRealTickCount() - _st1)
        _st1 = C.Game:getRealTickCount()

        -- This will clear everything from the screen as we are not currently rendering to the FBO - I just want slightly darker bg
        C.Gdx.gl:glClearColor(0.07, 0.07, 0.07, 1)
        C.Gdx.gl:glClear(C.IntUtil:Or(C.GL20.GL_COLOR_BUFFER_BIT, C.GL20.GL_DEPTH_BUFFER_BIT))

        -- Draw things into FBO if shader is set. If shader failed to compile, there's no need in FBO and we can just draw everything without a bloom
        if UIV.shader ~= nil then
            local screenWidth = C.Game.i.renderingManager:getCurrentRenderTargetWidth()
            local screenHeight = C.Game.i.renderingManager:getCurrentRenderTargetHeight()

            if UIV.fbo == nil or UIV.fbo:getWidth() ~= screenWidth or UIV.fbo:getHeight() ~= screenHeight then
                if UIV.fbo ~= nil then
                    UIV.fbo:dispose() -- dispose the previous FBO if exists (otherwise memory leak will occur)
                    UIV.fbo = nil
                end

                -- Create a new FBO with the size of the screen. This may fail but I'm to lazy to try and make it fail - you may want to catch errors here and disable the shader in case of failure
                UIV.fbo = C.FrameBuffer.new_F_2i_b(C.Pixmap.Format.RGBA8888, screenWidth, screenHeight, false)
            end

            -- Start rendering to the FBO. We use RenderingManager here in case the game already renders to some other FBO
            -- This allows to "nest" FrameBuffers
            C.Game.i.renderingManager:startFBO(UIV.fbo, "matrix-background")

            -- Setting FBO background color to fully transparent green (for proper bloom blending)
            C.Gdx.gl:glClearColor(C.MaterialColor.GREEN.P500.r, C.MaterialColor.GREEN.P500.g, C.MaterialColor.GREEN.P500.b, 0)
            C.Gdx.gl:glClear(C.IntUtil:Or(C.GL20.GL_COLOR_BUFFER_BIT, C.GL20.GL_DEPTH_BUFFER_BIT))
        end

        local font = C.Game.i.assetManager:getFont(24)
        local cache = font:newFontCache()
        local color = C.MaterialColor.LIGHT_GREEN.P500:cpy()
        local camera = S._render:getCamera()
        local screenWidth = C.Game.i.renderingManager:getCurrentRenderTargetWidth()
        local screenHeight = C.Game.i.renderingManager:getCurrentRenderTargetHeight()

        local lookingAt = C.Vector3.new_3f(screenWidth * 0.5, screenHeight * 0.5, 0)
        camera:unproject(lookingAt)
        local mapCenterX = map:getWidth() * C.Config.TILE_SIZE * 0.5
        local mapCenterY = map:getWidth() * C.Config.TILE_SIZE * 0.5
        local paraX = (lookingAt.x - mapCenterX) / (map:getWidth() * C.Config.TILE_SIZE) * 256
        local paraY = (lookingAt.y - mapCenterY) / (map:getHeight() * C.Config.TILE_SIZE) * 256

        atPrepare:push(C.Game:getRealTickCount() - _st1)
        _st1 = C.Game:getRealTickCount()

        for rowIdx = 1, rowCount do
            local row = labelGrid[rowIdx]
            if row ~= nil then
                for colIdx = 1, colCount do
                    local cell = row[colIdx] -- < GETTABLE 3
                    if cell ~= nil then
                        if cell[IDX_ALPHA] > 0 and cell[IDX_CHAR] ~= nil then -- < GETTABLE 2
                            local para = colParallax[colIdx] -- < GETTABLE 5
                            color.a = cell[IDX_ALPHA] * cell[IDX_STATIC_ALPHA] -- < GETTABLE 4
                            -- This is the source of poor performance - 46k+ iterations on 32x32 map
                            -- Bonus points if you figure out how to optimize this (remember you have access to shaders now)
                            foo_CacheSetText(cache, cell[IDX_CHAR], cell[IDX_X] + paraX * para[1], cell[IDX_Y] + paraY * para[2]) -- < GETTABLE 1
                            foo_CacheSetColors(cache, color)
                            foo_CacheDraw(cache, batch)
                        end
                    end
                end
            end
        end

        atCacheDraw:push(C.Game:getRealTickCount() - _st1)
        _st1 = C.Game:getRealTickCount()

        if UIV.shader ~= nil then
            -- Make sure to flush the batch of graphics into the FBO before we end rendering into it
            batch:flush()

            -- Detach from FBO - passing a name of the FBO is required to make sure FBOs were properly nested
            C.Game.i.renderingManager:endFBO("matrix-background")

            -- At this point we are rendering to the main buffer and have a FBO with our matrix effect
            local screenWidth = C.Game.i.renderingManager:getCurrentRenderTargetWidth()
            local screenHeight = C.Game.i.renderingManager:getCurrentRenderTargetHeight()

            local prj = batch:getProjectionMatrix()
            prj:setToOrtho2D(0, 0, screenWidth, screenHeight)
            batch:setProjectionMatrix(prj)
            batch:setBlendFunction(C.GL20.GL_SRC_ALPHA, C.GL20.GL_ONE_MINUS_SRC_ALPHA)
            batch:setColor(C.Color.WHITE)

            -- Here we are about to draw the FBO with a custom shader
            batch:setShader(UIV.shader)
            UIV.shader:setUniformf("iResolution", screenWidth, screenHeight, 0) -- Passing data to the shader - remember to bind it first (see the line above)

            -- That's how we get the Texture from our FBO, to draw it in any way we like
            local fboTexture = UIV.fbo:getColorBufferTexture() --[[@as Texture]]
            --fboTexture:setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear) -- May be useful if FBO's size is not 1:1 to the screen
            batch:draw(fboTexture, 0, 0, screenWidth, screenHeight, 0, 0, UIV.fbo:getWidth(), UIV.fbo:getHeight(), false, true)

            -- Switch back to the default shader
            -- Disabling diagnostic - @Null annotation is missing in this method but it is actually OK to pass null here, according to the docs
            ---@diagnostic disable-next-line: param-type-mismatch
            batch:setShader(nil)
        end

        atFboDraw:push(C.Game:getRealTickCount() - _st1)

        atTotal:push(C.Game:getRealTickCount() - _st)

        font:draw(batch, "Update: " .. tostring(C.StringFormatter:compactNumberWithPrecision(atUpdate:getAverage() / 1000.0, 1)) .. "ms", 280, 30 + 30 * 5)
        font:draw(batch, "Alpha decay: " .. tostring(C.StringFormatter:compactNumberWithPrecision(atDecay:getAverage() / 1000.0, 1)) .. "ms", 280, 30 + 30 * 4)
        font:draw(batch, "Prepare: " .. tostring(C.StringFormatter:compactNumberWithPrecision(atPrepare:getAverage() / 1000.0, 1)) .. "ms", 280, 30 + 30 * 3)
        font:draw(batch, "Draw to cache: " .. tostring(C.StringFormatter:compactNumberWithPrecision(atCacheDraw:getAverage() / 1000.0, 1)) .. "ms", 280, 30 + 30 * 2)
        font:draw(batch, "Render FBO: " .. tostring(C.StringFormatter:compactNumberWithPrecision(atFboDraw:getAverage() / 1000.0, 1)) .. "ms", 280, 30 + 30)
        font:draw(batch, "Total: " .. tostring(C.StringFormatter:compactNumberWithPrecision(atTotal:getAverage() / 1000.0, 1)) .. "ms", 280, 30)
    end)

    S._render:addLayer(C.RenderSystem.Layer.new(C.GameRenderingOrder.MAP_DRAW_TILES - 10, false, layerRenderer))
end

S.events:getListeners(C.SystemsPostSetup):add(C.Listener(start))
S.events:getListeners(C.SystemsStateRestore):addStateAffecting(C.Listener(start))
S.events:getListeners(C.SystemsDispose):addStateAffecting(C.Listener(function(_)
    -- Don't forget to dispose of FrameBuffer on exit
    if UIV.fbo ~= nil then
        UIV.fbo:dispose()
        UIV.fbo = nil
    end
end))

return start