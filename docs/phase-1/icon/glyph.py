import math
def arc(cx,cy,r,a0,a1):
    # angles in degrees, 0 = right, clockwise positive (SVG y down)
    x0,y0=cx+r*math.cos(math.radians(a0)),cy+r*math.sin(math.radians(a0))
    x1,y1=cx+r*math.cos(math.radians(a1)),cy+r*math.sin(math.radians(a1))
    large=1 if (a1-a0)%360>180 else 0
    return f"M{x0:.1f} {y0:.1f} A{r} {r} 0 {large} 1 {x1:.1f} {y1:.1f}"
def glyph(cx=478,cy=520,s=1.0,fill="url(#au)",stroke="url(#au)",outer_op=".5",rot=-18):
    g=[f'<g transform="rotate({rot} {cx} {cy})">',
       f'<circle cx="{cx}" cy="{cy}" r="{86*s:.0f}" fill="{fill}"/>',
       f'<g fill="none" stroke="{stroke}" stroke-linecap="round">',
       f'<path d="{arc(cx,cy,210*s,-50,50)}" stroke-width="{62*s:.0f}"/>',
       f'<path d="{arc(cx,cy,340*s,-42,42)}" stroke-width="{56*s:.0f}" opacity="{outer_op}"/>',
       f'<path d="{arc(cx,cy,210*s,145,215)}" stroke-width="{44*s:.0f}" opacity="{outer_op}"/>',
       '</g></g>']
    return "\n  ".join(g)
defs='''<defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2d2721"/><stop offset="1" stop-color="#0e0c0a"/></linearGradient>
    <linearGradient id="au" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f5cd7c"/><stop offset="1" stop-color="#c58d2b"/></linearGradient>
    <linearGradient id="gr" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#b8b8b8"/></linearGradient>
  </defs>'''
files={}
# iOS default: full-bleed square (iOS applies the mask)
files['ios-default.svg']=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">\n  {defs}\n  <rect width="1024" height="1024" fill="url(#bg)"/>\n  {glyph()}\n</svg>\n'
# iOS dark: transparent background, system draws dark backdrop
files['ios-dark.svg']=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">\n  {defs}\n  {glyph()}\n</svg>\n'
# iOS tinted: greyscale glyph, system applies tint
files['ios-tinted.svg']=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">\n  {defs}\n  {glyph(fill="url(#gr)",stroke="url(#gr)")}\n</svg>\n'
# macOS: 824 rounded rect inside 1024 canvas with shadow (macOS icon grid)
mac_glyph=glyph(s=0.8)
files['macos.svg']=f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  {defs}
  <filter id="sh" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-opacity=".3"/></filter>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)" filter="url(#sh)"/>
  <rect x="100.5" y="100.5" width="823" height="823" rx="185" fill="none" stroke="#ffffff" stroke-opacity=".08"/>
  {mac_glyph}
</svg>
'''
# Menu bar template: black on transparent, 18x18 pt (drawn at 36 px canvas scale in viewBox 1024)
files['menubar-template.svg']=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">\n  {glyph(s=1.12,fill="#000",stroke="#000",outer_op="1")}\n</svg>\n'
for k,v in files.items(): open(k,'w').write(v)
print(list(files))
