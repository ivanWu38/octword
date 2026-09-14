#!/usr/bin/env python3
"""gen_previews.py — 從一份 spec 產出 previews.html（iPhone 1x=430×932）、previews_ipad.html（iPad 1x=750×1000）
與 previews_bg_variants.html（背景／英雄圖變體）。app 畫面只用 shots/ 的真截圖（2.3.3）。"""
import pathlib

HERE = pathlib.Path(__file__).parent

# 核可文案（停點 2）。<a> = accent 色字。
SHOTS = [
    dict(name="game",       h1='Eight Words.<br><a>One Edition.</a>',   h2='Solve 8 words at once, every day',
         stamps=[("No. 118", "l", -7), ("8 boards · 13 guesses", "r", 5)]),
    dict(name="rank",       h1='Climb the<br><a>Daily Rank</a>',         h2='Same puzzle worldwide.<br>Who solves it best?',
         stamps=[("Resets every edition", "l", -6), ("You’re #7 today", "r", 5)]),
    dict(name="report",     h1='See How <a>Smart</a><br>You Play',        h2='A skill score for every solve',
         stamps=[("Skill 91 / 100", "l", -6), ("Guess-by-guess", "r", 5)]),
    dict(name="challenges", h1='How Long Can<br><a>You Last?</a>',        h2='10 Timed and Run challenges',
         stamps=[("Beat the clock", "l", -6), ("Guard your lives", "r", 5)]),
    dict(name="categories", h1='16 Themed<br><a>Word Packs</a>',         h2='Animals, Space, Film and more',
         stamps=[("306 puzzles", "l", -6), ("16 packs", "r", 5)]),
]

THEMES = {
    # 報紙紙張（app 淺色底 #F4F0E6 → 背景再暖/深一階才分得開）
    "paper": dict(bg="radial-gradient(circle 420px at 50% -60px, rgba(174,65,36,.16), transparent 70%),"
                     "linear-gradient(180deg,#EDE5D2 0%,#E4DAC3 100%)",
                  ink="#261F1C", ink2="#5E564A", accent="#AE4124", rule="rgba(38,31,28,.35)",
                  stamp_fg="#AE4124", stamp_bg="rgba(244,240,230,.9)", stamp_bd="#AE4124",
                  frame="rgba(38,31,28,.55)", shadow="rgba(38,31,28,.35)"),
    # 墨黑（高對比；app 深色底 #17130E → 背景略暖偏亮一階）
    "ink": dict(bg="radial-gradient(circle 420px at 50% -60px, rgba(210,86,44,.32), transparent 70%),"
                   "linear-gradient(180deg,#2B241C 0%,#1B1610 100%)",
                ink="#F3ECDD", ink2="rgba(243,236,221,.72)", accent="#E8A33A", rule="rgba(243,236,221,.32)",
                stamp_fg="#F3ECDD", stamp_bg="rgba(27,22,16,.85)", stamp_bd="#E8A33A",
                frame="rgba(255,255,255,.18)", shadow="rgba(0,0,0,.6)"),
}

def css(dev, t):
    if dev == "iphone":
        W, H, dw, dtop, r, h1, h2, kick, st, pad = 430, 932, 338, 262, 46, 53, 24, 12, 12.5, 44
    else:
        W, H, dw, dtop, r, h1, h2, kick, st, pad = 750, 1000, 486, 336, 22, 70, 30, 15, 17, 76
    return f"""
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,700;0,800;1,700&family=Inter:wght@500;600;700&display=swap" rel="stylesheet">
<style>
  :root{{--ink:{t['ink']};--ink2:{t['ink2']};--accent:{t['accent']};--rule:{t['rule']};
        --serif:'Playfair Display',Georgia,'Times New Roman',serif;--sans:'Inter',-apple-system,'Helvetica Neue',sans-serif;}}
  *{{margin:0;padding:0;box-sizing:border-box}}
  body{{background:#111;font-family:var(--sans);padding:40px}}
  .gallery{{display:flex;gap:28px;width:max-content}}
  .shot{{width:{W}px;height:{H}px;flex:none;position:relative;overflow:hidden;border-radius:28px;background:{t['bg']}}}
  .rules{{position:absolute;left:0;right:0;top:{pad-16}px;z-index:2;pointer-events:none}}
  .rules i{{display:block;height:1px;background:var(--rule);margin:0 {pad*0.6}px}} .rules i+i{{margin-top:3px;opacity:.6}}
  .kicker{{position:relative;z-index:30;text-align:center;padding-top:{pad}px;font:600 {kick}px/1 var(--sans);letter-spacing:{kick*0.22}px;text-transform:uppercase;color:var(--ink2)}}
  .caption{{position:relative;z-index:30;text-align:center;padding:{pad}px {pad*0.4}px 0}}
  .caption h1{{font:800 {h1}px/1.08 var(--serif);letter-spacing:-.6px;color:var(--ink)}}
  .caption h1 a{{color:var(--accent);font-style:italic;text-decoration:none}}
  .caption h2{{margin-top:{h2*0.55}px;font:600 {h2}px/1.32 var(--sans);letter-spacing:-.2px;color:var(--ink2)}}
  .device{{position:absolute;left:50%;top:{dtop}px;transform:translateX(-50%);width:{dw}px;z-index:10;border-radius:{r}px;overflow:hidden;
           background:#000;border:1.5px solid {t['frame']};box-shadow:0 34px 70px {t['shadow']},0 0 0 1px rgba(0,0,0,.25)}}
  .device.tilt{{transform:translateX(-50%) rotate(-3deg)}} .device.tilt2{{transform:translateX(-50%) rotate(2.5deg)}}
  .device img{{display:block;width:100%;height:auto}}
  .device.card{{width:{dw*1.06:.0f}px;top:{dtop+44}px;border-radius:{r*1.6:.0f}px}}
  .duo .device{{width:{dw*0.74:.0f}px;top:{dtop+24}px}}
  .duo .device.l{{left:31%;transform:translateX(-50%) rotate(-5deg)}} .duo .device.r{{left:69%;transform:translateX(-50%) rotate(5deg);z-index:11}}
  .duo .stamp.l{{top:{dtop-18}px;z-index:26}} .duo .stamp.r{{top:{dtop-10}px;z-index:26}}
  .stamp{{position:absolute;z-index:25;font:700 {st}px/1 var(--serif);letter-spacing:{st*0.1}px;text-transform:uppercase;white-space:nowrap;
          padding:{st*0.7}px {st*1.1}px;color:{t['stamp_fg']};background:{t['stamp_bg']};border:2px solid {t['stamp_bd']};
          box-shadow:0 8px 20px rgba(0,0,0,.18)}}
  .stamp:before{{content:"";position:absolute;inset:3px;border:1px solid {t['stamp_bd']};opacity:.55}}
  .stamp.l{{left:{pad*0.45}px;top:{dtop-14 if dev=="iphone" else dtop+2}px}} .stamp.r{{right:{pad*0.45}px;top:{dtop+6 if dev=="iphone" else dtop+26}px}}
</style>"""

def shot(dev, s, mode="light", duo=False):
    img = f"shots/{dev}_{s['name']}_{mode}.png"
    stamps = "".join(f'<span class="stamp {side}" data-decor style="transform:rotate({rot}deg)">{txt}</span>'
                     for txt, side, rot in s["stamps"])
    if duo:
        dev_html = (f'<div class="device l"><img src="shots/{dev}_{s["name"]}_light.png" alt=""></div>'
                    f'<div class="device r"><img src="shots/{dev}_{s["name"]}_dark.png" alt=""></div>')
    elif dev == "ipad" and s["name"] in ("rank", "report"):
        # iPad 上這兩頁是置中 form sheet：用 crop.py 裁出整張 sheet 卡放大（真截圖矩形裁切）
        tilt = "tilt" if s["name"] == "report" else "tilt2"
        dev_html = f'<div class="device card {tilt}"><img src="shots/ipad_crop_{s["name"]}sheet.png" alt=""></div>'
    else:
        tilt = "tilt" if s["name"] in ("game", "report", "categories") else "tilt2"
        dev_html = f'<div class="device {tilt}"><img src="{img}" alt=""></div>'
    return f"""  <div class="shot{' duo' if duo else ''}">
    <div class="caption"><h1>{s['h1']}</h1><h2>{s['h2']}</h2></div>
    {dev_html}{stamps}
  </div>
"""

def page(dev, theme, title, shots_html):
    return (f'<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><title>{title}</title>{css(dev, THEMES[theme])}</head>\n'
            f'<body><div class="gallery">\n{shots_html}</div></body></html>\n')

def main(theme="paper", hero_duo=False, hero_mode="light"):
    for dev in ("iphone", "ipad"):
        html = "".join(shot(dev, s, mode=hero_mode if i == 0 else "light", duo=(hero_duo and i == 0)) for i, s in enumerate(SHOTS))
        out = HERE / ("previews.html" if dev == "iphone" else "previews_ipad.html")
        out.write_text(page(dev, theme, f"Octors — App Store Previews ({dev}, {theme})", html))
        print("wrote", out.name)
    # 變體頁：每個變體是獨立的小頁（自己的主題 CSS），用 iframe 排在一起
    vdir = HERE / "variants"; vdir.mkdir(exist_ok=True)
    frames = []
    for th in ("paper", "ink"):
        mode = "light" if th == "paper" else "dark"
        for label, sh in (("hero · single", shot("iphone", SHOTS[0], mode=mode)),
                          ("hero · light+dark duo", shot("iphone", SHOTS[0], duo=True)),
                          ("#4 challenges", shot("iphone", SHOTS[3], mode="light"))):
            fn = f"v_{th}_{label.split()[0].strip('#')}_{'duo' if 'duo' in label else 'single'}.html"
            (vdir / fn).write_text(page("iphone", th, f"variant {th} {label}", sh).replace('src="shots/', 'src="../shots/'))
            frames.append(f'<figure><figcaption>{th.upper()} — {label}</figcaption>'
                          f'<iframe src="variants/{fn}" width="510" height="1012" scrolling="no" style="border:0"></iframe></figure>')
    (HERE / "previews_bg_variants.html").write_text(
        '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Octors — bg/hero variants</title>'
        '<style>body{background:#111;color:#ddd;font:600 14px -apple-system,sans-serif;padding:20px}'
        'figure{display:inline-block;margin:0 10px 20px 0;vertical-align:top}figcaption{margin-bottom:8px;letter-spacing:1px}'
        'iframe{transform-origin:top left}</style></head><body>'
        '<p>上排 PAPER（報紙紙張）・下排 INK（墨黑高對比）；每排：英雄圖單機／英雄圖 light+dark 雙機／第 4 張</p>'
        '<div style="width:max-content">' + "".join(frames) + '</div></body></html>')
    print("wrote previews_bg_variants.html (+variants/)")

if __name__ == "__main__":
    import sys
    args = dict(a.split("=") for a in sys.argv[1:])
    main(theme=args.get("theme", "paper"), hero_duo=args.get("duo", "1") == "1", hero_mode=args.get("hero", "light"))
