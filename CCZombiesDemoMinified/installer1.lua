-- ============================================================
-- CC:ZOMBIES DEMO INSTALLER
-- Run this script once to install everything you need.
-- It is safe to re-run — existing files will be updated.
-- ============================================================

local URLS = {
    game    = "https://raw.githubusercontent.com/DrNightheart/CC-Zombies-Downloadable-Assets/refs/heads/main/CCZombiesDemoMinified/CCZombiesDEMO1.lua",
    api     = "https://raw.githubusercontent.com/DrNightheart/CC-Zombies-Downloadable-Assets/refs/heads/main/CCZombiesDemoMinified/CCZ_API.lua",
    pine3d  = "https://raw.githubusercontent.com/Xella37/Pine3D/refs/heads/main/Pine3D-minified.lua",
    blittle = "https://raw.githubusercontent.com/Xella37/Pine3D/refs/heads/main/betterblittle.lua",
    nacht   = "https://raw.githubusercontent.com/DrNightheart/CC-Zombies-Downloadable-Assets/refs/heads/main/CCZombiesDemoMinified/Nacht.ccz",
}

local function printc(col, msg)
    term.setTextColor(col)
    print(msg)
    term.setTextColor(colors.white)
end

local function header()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("================================")
    print("   CC:ZOMBIES DEMO INSTALLER")
    print("================================")
    term.setTextColor(colors.white)
    print("")
end

local function download(url, dest, label)
    term.setTextColor(colors.yellow)
    term.write("  Downloading " .. label .. "... ")
    local ok, err = pcall(function()
        local res = http.get(url)
        if not res then error("no response") end
        local data = res.readAll()
        res.close()
        local f = fs.open(dest, "w")
        if not f then error("cannot write " .. dest) end
        f.write(data)
        f.close()
    end)
    if ok then
        printc(colors.lime, "OK")
    else
        printc(colors.red, "FAILED")
        printc(colors.red, "    " .. tostring(err))
        return false
    end
    return true
end

local function writeSprite(dest, content)
    local f = fs.open(dest, "w")
    if not f then return false end
    f.write(content)
    f.close()
    return true
end

-- ── START ─────────────────────────────────────────────────
header()

local failed = 0

-- 1. Pine3D (skip if already installed)
if fs.exists("Pine3D.lua") then
    printc(colors.cyan, "  Pine3D.lua already installed — skipping.")
else
    if not download(URLS.pine3d,  "Pine3D.lua",       "Pine3D (minified)") then failed = failed + 1 end
end
if not download(URLS.blittle, "betterblittle.lua", "betterblittle") then failed = failed + 1 end

-- 2. Core game files
if not download(URLS.api,    "CCZ_API.lua",        "CCZ_API")          then failed = failed + 1 end
if not download(URLS.game,   "CCZombiesDemo.lua",   "CCZombiesDemo")    then failed = failed + 1 end

-- 3. Maps
if not fs.exists("maps") then fs.makeDir("maps") end
if not download(URLS.nacht,  "maps/Nacht.ccz",     "Nacht Der Untoten") then failed = failed + 1 end

-- 4. Gun sprites (embedded)
print("")
printc(colors.yellow, "  Installing gun sprites...")
if not fs.exists("guns") then fs.makeDir("guns") end
local spriteOk = 0
local spriteFail = 0
if writeSprite("guns/ak47_AliceE.nfp", [==[







                                  8
                                  7      8  8
                                  7cc   7  7
                                  cccccc7  7
                                  cc7ccc7cc7
                                  000c7cccccc
                                  60000cccccc7000
                                 6666008ccc777700
                                 6666668  7777700
                                 6666668887777706
                                6666666   77777
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/ak47_ArissNightheart.nfp", [==[







                                  8
                                  7      8  8
                                  7cc   7  7
                                  cccccc7  7
                                  cc7ccc7cc7
                                  000c7cccccc
                                  f0000cccccc7000
                                 fff0008ccc777700
                                 ffffff8  7777700
                                 ffffff8887777700
                                fffffff   77777
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/ak47_Bayard.nfp", [==[







                                  8
                                  7      8  8
                                  7cc   7  7
                                  cccccc7  7
                                  cc7ccc7cc7
                                  000c7cccccc
                                  30000cccccc7000
                                 3330008ccc777700
                                 3333338  7777700
                                 3333338887777703
                                3333333   77777
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/ak47_DrNightheart.nfp", [==[


                                                0




                                  8
                                  7      8  8
                                  7cc   7  7
                                  cccccc7  7
                                  cc7ccc7cc7
                                  fffc7cccccc
                                  fffffcccccc7fff
                                 00ffff8ccc777fff
                                 0000008  7777fff
                                 00000008877777f0
                                0000000   77777
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/ballista_sniper_AliceE.nfp", [==[







                                  7
                                  fff    7
                                 cccfff  7
                                0c8c8ccffffff
                               00c8c8ccccccff
                               0000c8cc8ccccc
                               000000cc8c7cccc
                               0666666 cc777ccc
                              666666666 c8ccccccc
                              666666666 c8ccccccc
                             6666666666  8ccccccc
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/ballista_sniper_ArissNightheart.nfp", [==[







                                  7
                                  fff    7
                                 cccfff  7
                                0c8c8ccffffff
                               00c8c8ccccccff
                               0008c8cc8ccccc
                               000000cc8c7cccc
                               fffffff cc777ccc
                              ffffffff  c8ccccccc
                              ffffffff  c8ccccccc
                             ffffffff    8ccccccc
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/ballista_sniper_Bayard.nfp", [==[







                                  7
                                  fff    7
                                 cccfff  7
                                0c8c8ccffffff
                               00c8c8ccccccff
                               0000c8cc8ccccc
                               000000cc8c7cccc
                               333333  cc777ccc
                              33333333  c8ccccccc
                              33333333  c8ccccccc
                             33333333    8ccccccc
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/ballista_sniper_DrNightheart.nfp", [==[







                                  7
                                  fff    7
                                 cccfff  7
                               ffc8c8ccffffff
                               fff8c8ccccccff
                               ffffc8cc8ccccc
                               0fffffcc8c7cccc
                               0000000 cc777ccc
                              000000000 c8ccccccc
                              000000000fc8ccccccc
                             0000000000f 8ccccccc
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/m1911_AliceE.nfp", [==[










                                         7
                                      888788 7
                                      88888887
                                        8888878
                                         788888
                                        0000000
                                        0000000
                                         006666
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/m1911_ArissNightheart.nfp", [==[










                                         7
                                      888788 7
                                      88888887
                                        8888878
                                         788888
                                        0000000
                                        0000000
                                         00ffff
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/m1911_Bayard.nfp", [==[










                                         7
                                      888788 7
                                      88888887
                                        8888878
                                         788888
                                        0000000
                                        0000000
                                         003333
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/m1911_DrNightheart.nfp", [==[










                                         7
                                      888788 7
                                      88888887
                                        8888878
                                         788888
                                        fffffff
                                        fffffff
                                         ff0000
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/raygun_AliceE.nfp", [==[






                                1      777
                                1    777  77
                                eef  7     7
                                eeeee7fffffff
                                ee777ef777eef
                                 e74f4fee7eef
                                  7efde777ef
                                   eedeee7ee
                                    eeee77e0
                                     ee000000
                                     00000000
                                     00000066
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/raygun_ArissNightheart.nfp", [==[






                                1      777
                                1    777  77
                                eef  7     7
                                eeeee7fffffff
                                ee777ef777eef
                                 e74f4fee7eef
                                  7efde777ef
                                   eedeee7ee
                                    eeee77e0
                                     ee000000
                                     00000000
                                     000000ff
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/raygun_Bayard.nfp", [==[






                                1      777
                                1    777  77
                                eef  7     7
                                eeeee7fffffff
                                ee777ef777eef
                                 e74f4fee7eef
                                  7efde777ef
                                   eedeee7ee
                                    eeee77e0
                                     ee000000
                                     00000000
                                     00000033
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/raygun_DrNightheart.nfp", [==[






                                1      777
                                1    777  77
                                eef  7     7
                                eeeee7fffffff
                                ee777ef777eef
                                 e74f4fee7eef
                                  7efde777ef
                                   eedeee7ee
                                    eeee77ef
                                     eeffffff
                                     ffffffff
                                     ffffff00
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/standard_lmg_AliceE.nfp", [==[






                                  7 7
                              7  888888
                            8888 888888
                            8f888878878
                            888888888888 4
                          0000088f8f88888444
                         00000008777777788 44
                         0000000077777777700000
                        666600008877f777770000666
                       66666666687777f77777700666
                       666666666  7777f7777776666
                       6666666664447777ff77777666
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/standard_lmg_ArissNightheart.nfp", [==[






                                  7 7
                              7  888888
                            8888 888888
                            8f888878878
                            888888888888 4
                          0000888f8f88888444
                         00000088777777788 44
                         0000000077777777700000
                        fff000008877f7777700000ff
                       fffffffff87777f77777700fff
                       fffffffff  7777f777777ffff
                       fffffffff4447777ff777777ff
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/standard_lmg_Bayard.nfp", [==[






                                  7 7
                              7  888888
                            8888 888888
                            8f888878878
                            888888888888 4
                          0000888f8f88888444
                         00000088777777788 44
                         0000000077777777700000
                        333300008877f777770000333
                       33333333387777f77777700333
                       333333333  7777f7777773333
                       3333333334447777ff77777733
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/standard_lmg_DrNightheart.nfp", [==[






                                  7 7
                              7  888888
                            8888 888888
                            8f888878878
                            888888888888 4
                          ffff888f8f88888444
                         ffffff88777777788 44
                         ffffffff777777777fffff
                        000fffff8877f77777ffff000
                       00000000087777f777777ff000
                       000000000  7777f7777770000
                       0000000004447777ff77777700
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/uzi_md_AliceE.nfp", [==[






                                   8778
                                   8  8
                                  888 887 8
                                  88f88   8
                                 0088f888888
                                0000088f8888
                                0000008f8888
                               6660000ff8888
                              6666666 888888
                              6666666 887788
                              6666666 887788
                             6666666  888888
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/uzi_md_ArissNightheart.nfp", [==[






                                   8778
                                   8  8
                                  888 887 8
                                  88f88   8
                                 0088f888888
                                0000088f8888
                                0000008f8888
                               fff000 ff8888
                              fffffff 888888
                              fffffff 887788
                              fffffff 887788
                             fffffff  888888
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/uzi_md_Bayard.nfp", [==[






                                   8778
                                   8  8
                                  888 887 8
                                  88f88   8
                                 0088f888888
                                0000088f8888
                                0000008f8888
                               333000 ff8888
                              3333333 888888
                              3333333 887788
                              3333333 887788
                             3333333  888888
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end
if writeSprite("guns/uzi_md_DrNightheart.nfp", [==[






                                   8778
                                   8  8
                                  888 887 8
                                  88f88   8
                                 ff88f888888
                                fffff88f8888
                                ffffff8f8888
                               00fffffff8888
                               000000 888888
                              0000000 887788
                              0000000 887788
                            00000000  888888
]==]) then spriteOk = spriteOk + 1 else spriteFail = spriteFail + 1 end

if spriteFail == 0 then
    printc(colors.lime, "  " .. spriteOk .. " sprites installed.")
else
    printc(colors.red,  "  " .. spriteFail .. " sprites failed, " .. spriteOk .. " OK.")
    failed = failed + spriteFail
end

-- ── SUMMARY ───────────────────────────────────────────────
print("")
print("================================")
if failed == 0 then
    printc(colors.lime, "  Installation complete!")
    print("")
    printc(colors.white, "  To play, type:")
    printc(colors.yellow, "    CCZombiesDemo")
else
    printc(colors.red, "  Installation finished with " .. failed .. " error(s).")
    printc(colors.red, "  Check your internet connection and try again.")
end
print("================================")
